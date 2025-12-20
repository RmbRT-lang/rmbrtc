::rlc::types
{
	UNION ScopeAndTypeMemberHandle
	{
		Class:   Class   -Handle;
		Union:   Union   -Handle;
		Typedef: Typedef -Handle;
		Rawtype: Rawtype -Handle;
	}

	UNION NonFieldValueMemberHandle {
		Function:       Function      -Handle;
		StaticFunction: StaticFunction-Handle;
	}

	ScopeAndTypeMember {
		Name: Identifier;
		Handle: TAGGED ScopeAndTypeMemberHandle;
	}

	NonFieldValueMember {
		Name: Identifier;
		Handle: TAGGED NonFieldValueMemberHandle;
	}

	Class {
		Name: Identifier;

		Field {
			Type: TypeHandle;

			UNION FieldLocation {
			*	Unresolved;
			?	Fixed: U4;
				Eliminated; // for 0-size types etc.?
			}

			Offset: TAGGED FieldLocation;
		}
		Inheritance {
			Visibility: rlc::Visibility;
			Base: TAGGED ir::Operand;
		}

		Bases: Inheritance -[THIS]DynArray;

		FieldNames: Identifier -[THIS]DynArray;
		FieldData: Field -[THIS]AssocDynArray;

		ScopeAndTypeMembers: ScopeAndTypeMember -[THIS]DynArray;
		NonFieldValueMembers: NonFieldValueMembers -[THIS]DynArray;
		Size: TAGGED ir::Operand;

		# bases() Base#[#] -- := Bases(&THIS);
		# field_names() Identifier#[#] -- := FieldNames(&THIS);
		# nonfield_value_members() NonFieldValueMember#[#] -- := NonFieldValueMembers(&THIS);
		# scope_and_type_members() ScopeAndTypeMember#[#] -- := ScopeAndTypeMembers(&THIS);

		# lookup_field(id: Identifier) Field-std::Opt
		{
			FOR(fields())
				IF(IT.Name == id)
					= IT;
			= NULL;
		}
	}
}

::rlc::types parse_class(p: Parser &) VOID {
	_trace ::= p.trace("class");
	_defer_locals ::= std::temp::Locals::save();

	code: Code;

	class: Class (NOINIT);
	class.Name := p.expect(:identifier).Identifier;

	virtual ::= p.consume(:virtual);


	inheritance: Class::Inheritance-std::[std::temp::Locals]TVec;
	fields: Class::Field-std::[std::temp::Locals]Vec;
	other_members: NonFieldMember -std::[std::temp::Locals]Vec;

	IF(p.consume(:minusGreater))
	{
		inheritance.reserve(16);
		DO()
		{
			visibility: rlc::Visibility := :public;
			IF(p.consume(:private)) visibility := :private;
			ELSE IF(p.consume(:protected)) visibility := :protected;

			base ::= p.parse_type_symbol(&code);
			inheritance += (visibility, base);
		} WHILE(p.consume(:comma))

		IF(p.consume(:semicolon))
		{
			Class::assemble(class, &&inheritance, &&fields, &&other_members);
			RETURN;
		}
	}


	p.expect(:braceOpen);

	fields.reserve(64);
	other_members.reserve(64);

	default_visibility: rlc::Visibility := :public;
	WHILE(parse_class_member(p, &visibility, &code, &fields, &other_members))
		{;}

	Class::assemble(class, &&inheritance, &&fields, &&other_members);

	p.expect(:braceClose);
}

::rlc::types parse_class_member(
	p: Parser &,
	visibility: rlc::Visibility \,
	code: Code \,
	fields: Class::Field-std::[Locals]TVec \,
	other_members: Class::NonFieldMember-std::[Locals]TVec \) BOOL
{
	hash_mod ::= p.consume(:hash);

	peek ::= p.peek_2();

	IF(peek.Pair.(0) == :identifier)
	{
		SWITCH(peek.Pair.(1))
		{
		:colon: parse_variable();
		:parenthese_open: parse_function();
		}
	} ELSE IF(peek.Pair.(0) == :this)
	{
	} ELSE IF(peek.Pair.(0)
}