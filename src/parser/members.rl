INCLUDE "symbolconstant.rl"

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
	?	Function,
	?	StaticFunction,
	?	EnumConstant, // Could merge this into StaticField, or not.
	?	UnionField // Maybe merge into Field, or not.
	}

	ENUM Member {
		Class,
		Rawtype,
		Typedef,
		Mask,
		Union,
		Field,
		StaticField,
		Function,
		StaticFunction,
		EnumConstant,
		UnionField
	}

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
		Default: BOOL;
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
	NamedCtor {
		Name: SymbolConstant;
		Rest: TokenSpan;
		{BARE};
	}
	SpecialCtor {
		ArgName: Identifier;
		Span: TokenSpan;
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

	Constructors {
		SpecialCtors: SpecialCtor[TABLE parser::SpecialCtors];

		// WTF.
		// We want to have a similar 2-phase storage system here. First over-allocate scratchpad, then commit to mempool.
		(/ Requirements:
			- Lookup needs to be fast, but also compact in memory footprint.
				- We could use a separate pool per file that translates global identifiers into symbol names that are used in the file as overloads, or we could make them part of the declID namespace.
		/)
		Names: U1[]-std::Vec;

		Destructor: parser::Destructor-std::Opt;

		register_named_ctor(
			sym: SymbolConstant #&,
			span: TokenSpan,
			template: TokenSpan,
			at: U4,
			p: Parser &) VOID { term::warning(p.here().at(), "unimplemented"); term::warning(HERE); }

		register_special_ctor(
			special: parser::SpecialCtors,
			name: Identifier,
			at: U4,
			p: Parser &) VOID { term::warning(p.here().at(), "unimplemented"); term::warning(HERE); }
	}

	// Must have less than 64 entries.
	ENUM BinaryOperator {
		add,
		subtract,
		multiply,
		divide,
		modulo,
		bitOr,
		bitAnd,
		bitXor,
		bitNot,
		shiftLeft,
		shiftRight,
		rotateLeft,
		rotateRight,
		logAnd,
		logOr,
		equal,
		notEqual,
		greater,
		greaterEqual,
		less,
		lessEqual,
		compare,
		bindReference, // .*
		ptrBindReference, // ->*
		fieldAccess, // .
		ptrFieldAccess // ->
	}

	binopsFromBinaryTok: BinaryOperator[TABLE tok::BinaryOperator](
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

	BinaryOperators {
		Present: U8;
		Ops: :?[];


		# ## THIS U2 := POPCNT Present;
		# has_operator(op: BinaryOperator) BOOL --
			:= Present & (<U8>(1) << <U1>(op));
		# get_operator_index(op: BinaryOperator) U2 --
			:= POPCNT (Present & (<U8>(1) << <U1>(op) -1));
		#? THIS[op: BinaryOperator] :? & -- := Ops[get_operator_index(op)];
	}

	MemberVariable {
		Location: src::Position;
		Name: rlc::Identifier;
		Type: TokenSpan;
		Isolated: BOOL;
	}
}