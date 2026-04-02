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
	ENUM NVMember {
	*	Nil,
	?	Class,
	?	Rawtype,
	?	Typedef,
	?	Mask,
	?	Union,
	?	Enum
	}

	ENUM VMember {
	*	Nil,
	?	Field,
	?	StaticField,
	?	MemberFunction,
	?	StaticMemberFunction,
	?	EnumConstant, // Could merge this into StaticField, or not.
	?	UnionField
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

	NormalMemberEntry {
		Visibility: rlc::Visibility;
		Memory: MemID;


		{BARE};
		{...};
	}

	EnumConstant {
		Index: U2;
		Identifier: FileDeclIdentifier;
	}

	UnionField {
		Type: TokenSpan-Handle;
	}
	UNION MemberEntry {
	!	Normal: NormalMemberEntry;
		EnumConstant: parser::EnumConstant;
		UnionField: parser::UnionField;
	}
}


::rlc::parser Members {
	LUTEntry {
		NVType:   NVMember;
		NVEntry:  MemberEntry;

		VType:   VMember;
		VEntry:  MemberEntry;

		set_value(
			type: VMember,
			global_name: Identifier,
			at: U4,
			p: parser::Parser &,
			e: MemberEntry) VOID --
		{
			IF(VType != :Nil)
				term::error(p.at_pos(at).at(), "Re-definition of ", ident::get(global_name), " as ", std::str::enum(type), " (already exists as ", std::str::enum(VType), ")");
			VType := type;
			VEntry.{e};
		}
		set_nonvalue(
			type: NVMember,
			global_name: Identifier,
			at: U4,
			p: parser::Parser &,
			e: MemberEntry) VOID --
		{
			IF(NVType != :Nil)
				term::error(p.at_pos(at).at(), "Re-definition of ", ident::get(global_name), " as ", std::str::enum(type), " (already exists as ", std::str::enum(NVType), ")");
			NVType := type;
			NVEntry.{e};
		}
	}

	// First, we allocate the LUT in a tempalloc, with conservative capacity. Then, it gets shrunk into a second tempalloc as tight fit, and then migrated into the mempool with the file's number of decl identifiers as the final capacity. They start out with 0 boundary, and then grow. We copy it twice but this allows for much less register pressure and no branching or bounds checks during lookups later on, which can improve throughput on lookups.
	IdLut: LUTEntry-Handle[#];
	Entries: {U2, LUTEntry-Handle} [#]; // for patching.

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
}

::rlc::parser {
	NamedCtor { // :Name{Args} Rest
		Name: SymbolConstant;
		Template: TokenSpan;
		Args: TokenSpan;
		Rest: TokenSpan;
		{BARE};
	}
	SpecialCtor { // e.g. {#&ArgName} Rest
		ArgName: Identifier;
		Rest: TokenSpan;
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
		Body: TokenSpan;
	}

	CustomCtor {
		Template: TokenSpan;
		Args: TokenSpan;
		Rest: TokenSpan;
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
			args: TokenSpan,
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
			name: Identifier,
			rest: TokenSpan,
			at: U4,
			p: Parser &) VOID
		{
			IF(HasSpecialCtors & (1 << <U1>(special)))
				p.fail_pos(at, "Redefinition of ", std::str::enum(special), " constructor");
			HasSpecialCtors |= 1 << <U1>(special);

			SpecialCtors[special].ArgName := name;
			SpecialCtors[special].Rest := rest;
		}

		register_custom_ctor(
			args: TokenSpan,
			rest: TokenSpan,
			template: TokenSpan,
			at: U4,
			p: Parser &) VOID
		{
			IF(HasCustomCtor) p.fail_pos(at, "Re-definition of custom constructor");

			HasCustomCtor := TRUE;
			CustomCtor.Template := template;
			CustomCtor.Args := args;
			CustomCtor.Rest := rest;
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
		Body: TokenSpan;

		{...};
	}
	PreparsedPostfixOperator {
		Attr: ParsedMemberAttr;
		Template: TokenSpan;
		Type: SignatureRest;
		BodyType: parser::BodyType;
		Body: TokenSpan;

		{...};
	}

	UNION TypeU {
		Preparse: TokenSpan;
		PostParse: :?;
	}

	PreparsedBinaryOperator
	{
		Attr: ParsedMemberAttr;
		Template: TokenSpan;
		OperandName: FileLocalIdentifier;
		OperandType: TypeU;
		Type: SignatureRest;
		
		BodyType: parser::BodyType; Body: TokenSpan;

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
		Body: TokenSpan;

		{BARE};
	}

	CallOperator
	{
		Attr: ParsedMemberAttr;
		Template: TokenSpan;
		Args: TokenSpan;
		Rest: SignatureRest;
		BodyType: parser::BodyType;
		Body: TokenSpan;

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

	MemberVariable {
		Location: src::Position;
		Name: rlc::Identifier;
		Type: TokenSpan;
		Isolated: BOOL;
	}
}