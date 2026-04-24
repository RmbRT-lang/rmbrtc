INCLUDE "symbolconstant.rl"
INCLUDE "function.rl"
INCLUDE "../mempool.rl"

::rlc ENUM Visibility
{
	public,
	protected,
	private
}

::rlc ENUM SpecialCtor {
	Default,
	Bare,
	Null
}

::rlc::parser
{
	UNION NVMember {
	*	Nil;
	?	Class:   parser::Class   -Handle;
	?	Rawtype: parser::Rawtype -Handle;
	?	Typedef: parser::Typedef -Handle;
	?	Mask:    parser::Mask    -Handle;
	?	Union:   parser::Union   -Handle;
	?	Enum:    parser::Enum    -Handle;
	}


	EnumConstant {
		Index: U2;
		Identifier: FileDeclIdentifier;
	}

	UNION VMember {
	*	Nil;
	?	Field:                parser::Field          -Handle;
	?	StaticField:          parser::GlobalVariable -Handle;
	?	MemberFunction:       parser::MemberFunction -Handle;
	?	StaticMemberFunction: parser::Function       -Handle;
	?	EnumConstant:         parser::EnumConstant;
	?	UnionField:           parser::UnionField     -Handle;
	}

	(// (/ Unused for some reason? /)
	ENUM Member {
		Class,
		Rawtype,
		Typedef,
		Mask,
		Union,
		Field,
		StaticField,
		MemberFunction,
		StaticMemberFunction,
		EnumConstant,
		UnionField
	}/)

	UNION TypeU {
		Preparse: TypeID;
		PostParse: :?;
	}

	UnionField {
		Type: TypeU;
	}


	VMemberEntry {
		UNION Memory {
			Nil;

		}

		Visibility: rlc::Visibility;
		M: Memory;

		{BARE};
		{...};
	}
}

(/ Member scopes:

	We have the IdLut, which takes a FileDeclIdentifier, for outer lookup.
	For inner lookup, we also use a FileDeclIdentifier, and we inherit all static members of outer classes.

	However, inner lookup does not inherit from namespaces, because of the different naming scheme. So to perform a complete inner lookup, we have to perform the inner lookup of the member scope, and if that fails, an inner lookup of the namespace scope using the Identifier.

	We could make this branchless by always looking up both names. However, this would also double the cache usage. Anyway, an innerLookup from a member requires both identifiers and both scopes.
/)

::rlc::parser Members {
	VEntry {
		Type: ENUM VMember;
		Visibility: rlc::Visibility;
		Entry: VMember;

		{}: Type := :Nil, Visibility(BARE), Entry(NOINIT);

		{vis: rlc::Visibility, m: TAGGED VMember} --:
			Type(m.(0)),
			Visibility(vis),
			Entry(m.(1));
	}
	NVEntry {
		Type: ENUM NVMember;
		Visibility: rlc::Visibility;
		Entry: NVMember;

		{}: Type := :Nil, Visibility(BARE), Entry(NOINIT);
		{vis: rlc::Visibility, m: TAGGED NVMember} --:
			Type(m.(0)),
			Visibility(vis),
			Entry(m.(1));
	}

	LUTEntry {
		NonValue: NVEntry;
		Value: VEntry;

		set_value(
			global_name: Identifier,
			at: U4,
			p: parser::Parser &,
			e: VEntry) VOID --
		{
			type ::= e.Type;
			IF(Value.Type != :Nil)
				term::error(p.at_pos(at).at(), "Re-definition of ", ident::get(global_name), " as ", std::str::enum(type), " (already exists as ", std::str::enum(Value.Type), ")");
			Value := e;
		}
		set_nonvalue(
			global_name: Identifier,
			at: U4,
			p: parser::Parser &,
			e: NVEntry) VOID --
		{
			type ::= e.Type;
			IF(NonValue.Type != :Nil)
				term::error(p.at_pos(at).at(), "Re-definition of ", ident::get(global_name), " as ", std::str::enum(type), " (already exists as ", std::str::enum(NonValue.Type), ")");
			NonValue := e;
		}
	}

	// First, we allocate the LUT in a tempalloc, with conservative capacity. Then, it gets shrunk into a second tempalloc as tight fit, and then migrated into the mempool with the file's number of decl identifiers as the final capacity. They start out with 0 boundary, and then grow. We copy it twice but this allows for much less register pressure and no branching or bounds checks during lookups later on, which can improve throughput on lookups.
	IdLut: LUTEntry-Handle[#];
	Entries: {U2, LUTEntry-Handle} [#]; // for patching.

	InnerLutV: VEntry[];
	InnerLutNV: NVEntry[];

	Templates: :TemplateCtx;
	Fields: U2;

	ensure(id: rlc::FileDeclIdentifier) LUTEntry-Handle {
		IF(id.V < ##IdLut)
			IF(entry ::= IdLut[id.V])
				= entry;

		e ::= mempool::[LUTEntry]alloc_unhashed_t();
		entry ::= e.(1);
		e.(0)->{};

		IF(##IdLut <= id.V)
		{
			FOR(IdLut[][FROM ##IdLut UNTIL id.V])
				IT.{};

			##IdLut := id.V + 1;
		}
		IdLut[][id.V] := entry;

		Entries[(##Entries)++] := (id.V, e.(1));
		= entry;
	}

	// Call this only after finalise_members() has been called. We are going through great efforts to make this as simple as possible, for efficiency during name resolution.
	# lookup(id: rlc::FileDeclIdentifier) LUTEntry-Handle -- := IdLut[][id.V];

	# lookup_inner_t(id: rlc::FileDeclIdentifier) NVEntry * -- {
		entry ::= &InnerLutNV[id.V];
		= entry->Type ?? entry : NULL;
	}
	# lookup_inner_s(id: rlc::FileDeclIdentifier) NVEntry * -- {
		entry ::= &InnerLutNV[id.V];
		= entry->Type ?? entry : NULL;
	}
	# lookup_inner_v(id: rlc::FileDeclIdentifier) VEntry * -- {
		entry ::= &InnerLutV[id.V];
		= entry->Type ?? entry : NULL;
	}

	post_process(outerLutV: VEntry#[], outerLutNV: NVEntry#[], cap: U2) VOID
	{
		// TODO PERFORMANCE: have one big pool of ##FileDeclIds * ##MemberScopes per file.
		InnerLutV := mempool::[VEntry]alloc_unhashed_array(cap).(0);
		InnerLutNV := mempool::[NVEntry]alloc_unhashed_array(cap).(0);

		// Inherit access to all types.
		IF(outerLutNV)
		{
			FOR(cap) InnerLutNV[IOTA] := outerLutNV[IOTA];
			FOR(Entries!)
			{
				entry ::= &IT.(1)->NonValue;
				IF(entry->Type)
					InnerLutNV[IT.(0)] := *entry;
				ELSE
					InnerLutNV[IT.(0)] := outerLutNV[IT.(0)];
			}
		}
		ELSE
		{
			FOR(cap) InnerLutNV[IOTA].{};
			FOR(Entries!)
			{
				entry ::= &IT.(1)->NonValue;
				InnerLutNV[IT.(0)] := *entry;
			}
		}

		// Only inherit access to static value members, as inner scopes do not have access to the THIS object of the outer class.
		FOR(cap) InnerLutV[IOTA].{};
		IF(outerLutV)
		{
			// TODO PERFORMANCE: make this branchless.
			FOR(cap)
			{
				IF(1 << <U1>(outerLutV[IOTA].Type) & VMember::FLAGS(:StaticField, :StaticMemberFunction))
					InnerLutV[IOTA] := outerLutV[IOTA];
			}
		}
		FOR(Entries!)
		{
			entry ::= &IT.(1)->Value;
			InnerLutV[IT.(0)] := *entry;
		}

		// Post-process children as well.
		FOR(Entries!)
		{
			x ::= &IT.(1)->NonValue;
			type ::= x->Type;
			mem ::= x->Entry;

			members: Members * (NOINIT);

			STATIC member_offset: U4[TABLE ENUM NVMember](
				:Nil(0),
				:Class(<UM>(&<parser::Class *>(NULL)->Members)),
				:Rawtype(<UM>(&<parser::Rawtype *>(NULL)->Members)),
				:Typedef(0),
				:Mask(<UM>(&<parser::Mask *>(NULL)->Members)),
				:Union(<UM>(&<parser::Union *>(NULL)->Members)),
				:Enum(<UM>(&<parser::Enum *>(NULL)->Members))
			);

			IF(1 << <U1>(type) & ~NVMember::FLAGS(:Nil, :Typedef))
			{
				members := >( <UM>(mem.Class.get()) + member_offset[type] );
				members->post_process(InnerLutV, InnerLutNV, cap);
			}
		}
	}
}

::rlc::parser {
	NamedCtor { // :Name{Args} Rest
		Name: SymbolConstant;
		Template: TokenSpan;
		Args: ArgsID;
		Rest: TokenSpan;
		Body: BodyID;
		{BARE};
	}
	SpecialCtor { // e.g. {#&ArgName} Rest
		Rest: TokenSpan;
		Body: SpecialCtorBodyID;
	}
	ENUM SpecialCtors {
		// These have to come first, see (codeparser.REF A), and be in the same order as in AuxKeyword.
		Bare,
		Null,

		Default,
		Copy,
		Move,
		Structure
	}

	Destructor {
		At: src::Position;
		Inline: BOOL;
		Body: BodyID;
	}

	CustomCtor {
		Template: TokenSpan;
		Args: ArgsID;
		Rest: RestID;
		Body: BodyID;
	}

	Constructors {
		HasSpecialCtors: U1;
		SpecialCtors: SpecialCtor[TABLE parser::SpecialCtors];
		HasCustomCtor: BOOL;
		CustomCtor: parser::CustomCtor;

		HasSpecialNamedCtor: U1;
		SpecialNamedCtors: parser::CustomCtor[TABLE parser::SpecialName];
		// initially: sparse FileLocalID. Later: dense DeclID array.
		NamedCtors: parser::CustomCtor-Handle[#];
		NamedCtorEntries: {FileDeclIdentifier, parser::CustomCtor-Handle}[#];

		Destructor: parser::Destructor-std::Opt;

		ensure_named_ctor(id: rlc::FileDeclIdentifier) {BOOL, parser::CustomCtor *} {
			p_entry ::= &NamedCtors[][id.V];
			IF(id.V < ##NamedCtors)
				IF(*p_entry)
					= (TRUE, p_entry->get());

			e ::= mempool::[parser::CustomCtor]alloc_unhashed_t();
			entry ::= e.(1);
			*p_entry := e.(1);

			IF(##NamedCtors <= id.V)
			{
				FOR(NamedCtors[][FROM ##NamedCtors UNTIL id.V])
					IT.{};

				##NamedCtors := id.V + 1;
			}

			NamedCtorEntries[(##NamedCtorEntries)++] := (id.V, entry);
			= (FALSE, e.(0));
		}

		lookup_named_ctor(id: rlc::FileDeclIdentifier) parser::CustomCtor-Handle --
			:= NamedCtors[][id.V];

		register_named_ctor(
			sym: DefinitionSymbolConstant #&,
			args: ArgsID,
			rest: TokenSpan,
			template: TokenSpan,
			at: U4,
			p: Parser &) VOID
		{
			ctor: parser::CustomCtor * (NOINIT);
			SWITCH(sym.Name)
			{
			:Identifier:
			{
				name ::= sym.Name.(1).Identifier;
				entry ::= ensure_named_ctor(name);
				IF(entry.(0))
					p.fail_pos(at, "Re-definition of named constructor");
				ctor := entry.(1);
			}
			:Special:
			{
				special ::= sym.Name.(1).Special;
				IF(HasSpecialNamedCtor & 1 << <U1>(special))
					p.fail_pos(at, "Re-definition of named constructor");
				HasSpecialNamedCtor |= 1 << <U1>(special);
				ctor := &SpecialNamedCtors[special];
			}
			}

			ctor->Template := template;
			ctor->Args := args;
			ctor->Rest := rest;
		}

		register_special_ctor(
			special: parser::SpecialCtors,
			rest: TokenSpan,
			body: SpecialCtorBodyID,
			at: U4,
			p: Parser &) VOID
		{
			IF(HasSpecialCtors & (1 << <U1>(special)))
				p.fail_pos(at, "Redefinition of ", std::str::enum(special), " constructor");
			HasSpecialCtors |= 1 << <U1>(special);

			SpecialCtors[special].Rest := rest;
			SpecialCtors[special].Body := body;
		}

		register_custom_ctor(
			args: parser::ArgsID,
			rest: TokenSpan,
			body: parser::BodyID,
			template: TokenSpan,
			at: U4,
			p: Parser &) VOID
		{
			IF(HasCustomCtor) p.fail_pos(at, "Re-definition of custom constructor");

			HasCustomCtor := TRUE;
			CustomCtor.Template := template;
			CustomCtor.Args := args;
			CustomCtor.Rest := rest;
			CustomCtor.Body := body;
		}
	}

	// Must have less than 64 entries.
	ENUM BinaryOperator {
	?	add,
	?	subtract,
	?	multiply,
	?	divide,
	?	modulo,
	?	bitOr,
	?	bitAnd,
	?	bitXor,
	?	bitNot,
	?	shiftLeft,
	?	shiftRight,
	?	rotateLeft,
	?	rotateRight,
		logAnd,
		logOr,
	?	equal,
	?	notEqual,
	?	greater,
	?	greaterEqual,
	?	less,
	?	lessEqual,
	?	compare,
		bindReference, // .*
		ptrBindReference, // ->*
		fieldAccess, // .
		ptrFieldAccess, // ->

		// Do we want these in the binary operators? Or do we want a special assignment operator category?
		assign,
	?	addAsign,
	?	subAssign,
	?	mulAssign,
	?	divAssign,
	?	modAssign,
	?	xorAssign,
	?	logAndAssign,
	?	bitAndAssign,
	?	logOrAssign,
	?	bitOrAssign,
	?	rotateLeftAssign,
	?	shiftLeftAssign,
	?	rotateRightAssign,
	?	shiftRightAssign
	}

	binOpsFromBinaryTok: BinaryOperator[TABLE tok::BinaryOperator](
		:forwardSlash(:divide),
		:percent(:modulo),
		:doublePipe(:logOr),
		:pipe(:bitOr),
		:circumflex(:bitXor),
		:exclamationMarkEqual(:notEqual),
		:dotAsterisk(:bindReference),
		:dot(:fieldAccess),
		:tripleGreater(:rotateRight),
		:doubleGreater(:shiftRight),
		:minusGreaterAsterisk(:ptrBindReference),
		:minusGreater(:ptrFieldAccess),
		:doubleEqual(:equal),
		:greaterEqual(:greaterEqual),
		:greater(:greater),
		:tripleLess(:rotateLeft),
		:doubleLess(:shiftLeft),
		:lessEqual(:lessEqual),
		:lessGreater(:compare),
		:less(:less)
	);

	binOpsFromPrefixTok: BinaryOperator[TABLE tok::PrefixOrBinaryOperator](
		:asterisk(:multiply),
		:plus(:add),
		:minus(:subtract),
		:doubleAmp(:logAnd),
		:amp(:bitAnd)
	);

	binOpsFromAssignmentTok: BinaryOperator[TABLE tok::AssignmentOperator](
		:plusEqual(:addAsign),
		:minusEqual(:subAssign),
		:asteriskEqual(:mulAssign),
		:forwardSlashEqual(:divAssign),
		:percentEqual(:modAssign),
		:circumflexEqual(:xorAssign),
		:doubleAmpEqual(:logAndAssign),
		:ampEqual(:bitAndAssign),
		:doublePipeEqual(:logOrAssign),
		:pipeEqual(:bitOrAssign),
		:tripleLessEqual(:rotateLeftAssign),
		:doubleLessEqual(:shiftLeftAssign),
		:tripleGreaterEqual(:rotateRightAssign),
		:doubleGreaterEqual(:shiftRightAssign)
	);

	ENUM PostfixOperator
	{
	?	boolCheck,
	?	valueOf,
	?	postIncrement,
	?	postDecrement
	}
	postfixOpsFromPostfixTok: PostfixOperator[TABLE tok::PostfixOperator](
		:questionMark(:boolCheck)
	);
	postfixOpsFromPrefixTok: PostfixOperator[TABLE tok::PrefixOrPostfixOperator](
		:exclamationMark(:valueOf),
		:doublePlus(:postIncrement),
		:doubleMinus(:postDecrement)
	);

	ENUM PrefixOperator
	{
	?	negate,
		negateAssign,
	?	logNot,
		logNotAssign,
	?	bitNot,
		bitNotAssign,

		pointerOf, // \var -- currently identical to &var, but later on, distinct.
		referenceOf, // &var -- currently identical to \var, but later on, distinct. Planned to be mandatory for explicitly passing around mutable references.
		realAddrOf, // &&&var -- only useful with virtual classes. Might change it to \\\.

	?	countOf,

	?	preIncrement,
	?	preDecrement,

	?	dereference,
		copy,
		move
	}

	prefixOpsFromPostfixTok: PrefixOperator[TABLE tok::PrefixOrPostfixOperator](
		:exclamationMark(:logNot),
		:doublePlus(:preIncrement),
		:doubleMinus(:preDecrement)
	);

	prefixOpsFromBinaryTok: PrefixOperator[TABLE tok::PrefixOrBinaryOperator](
		:asterisk(:dereference),
		:plus(:copy),
		:minus(:negate),
		:doubleAmp(:move),
		:amp(:pointerOf) // TODO: later on, change this to :referenceOf!
	);

	prefixOpsFromPrefixTok: PrefixOperator[TABLE tok::PrefixOperator](
		:minusColon(:negateAssign),
		:backslash(:pointerOf),
		:exclamationMarkColon(:logNotAssign),
		:tildeColon(:bitNotAssign),
		:tilde(:bitNot),
		:tripleAmp(:realAddrOf),
		:doubleHash(:countOf)
	);

	ENUM TernaryOperator {
		conditional,
		select
	}

	ENUM ParsedMemberAttr {
	*	none,
	?	isolated,
	?	maybeIsolated,
	?	static
	}

	PreparsedPrefixOperator {
		Attr: ParsedMemberAttr;
		Template: TokenSpan;
		Type: SignatureRest;
		BodyType: parser::BodyType;
		Body: BodyID;

		{...};
	}
	PreparsedPostfixOperator {
		Attr: ParsedMemberAttr;
		Template: TokenSpan;
		Type: SignatureRest;
		BodyType: parser::BodyType;
		Body: BodyID;

		{...};
	}

	PreparsedBinaryOperator
	{
		Attr: ParsedMemberAttr;
		Template: TokenSpan;
		Args: Arguments;
		Type: SignatureRest;
		
		BodyType: parser::BodyType; Body: BodyID;

		{...};
	}

	[Enum; Entry] OperatorsT {
		Present: U8; // BinaryOperator::FLAGS
		Ops: Entry[]; // Operators start out sparse, but get packed in a post-pass.


		# ## THIS U2 := POPCNT Present;
		# has_operator(op: Enum) BOOL --
			:= Present & (<U8>(1) << <U1>(op));
		# get_operator_index(op: Enum) U2 --
			:= POPCNT (Present & (<U8>(1) << <U1>(op) -1));
		#? THIS[op: Enum] Entry #? & -- := Ops[get_operator_index(op)];

		register(op: Enum, e: Entry #&, at: U4, p: Parser &) VOID
		{
			IF(has_operator(op))
				p.fail_pos(at, "Re-definition of operator");

			Present |= <U8>(1) << <U1>(op);
			Ops[<U1>(op)].{ e };
		}
	}

	TYPE BinaryOperators := [BinaryOperator; PreparsedBinaryOperator]OperatorsT;
	TYPE PrefixOperators := [PrefixOperator; PreparsedPrefixOperator]OperatorsT;
	TYPE PostfixOperators := [PostfixOperator; PreparsedPostfixOperator]OperatorsT;

	ConversionOperator {
		Type: TypeU;
		Inline: BOOL;
		BodyType: parser::BodyType;
		Body: BodyID;

		{BARE};
	}

	CallOperator
	{
		Attr: ParsedMemberAttr;
		Template: TokenSpan;
		Args: Arguments;
		Rest: SignatureRest;
		BodyType: parser::BodyType;
		Body: BodyID;

		{BARE};
	}

	ENUM SpecialOperator {
		conversion,
		call,
		subscript
	}

	Operators
	{
		Binary: BinaryOperators;
		Prefix: PrefixOperators;
		Postfix: PostfixOperators;
		HasSpecial: U1; // SpecialOperator::FLAGS
		Conversion: ConversionOperator;
		Call: CallOperator;
		Subscript: PreparsedBinaryOperator;

		{}: Conversion(BARE), Call(BARE), Subscript(BARE);
	}
}