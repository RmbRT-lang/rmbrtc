::rlc::compiler::ct
{
	// compile time number.
	UNION CTValue {
		Deferred;
	?	Bool: BOOL;
	?	UInt: U8;
	?	SInt: S8;
	?	BuiltinType: tok::BuiltinType; // for casts
	?	Constant: parser::GlobalVariable *;
	}

	ENUM CTOp {
		Deferred,
	?	Cast,
	?	Operator
	}

	ExpParserState {
		Precedence: U1;
		Lhs: TAGGED CTValue;
	}

	// This parses and evaluates a comptime expression
	parse_eval_expression(
		p: parser::Parser &,
		stack: ExpParserState-std::Vec &,
		file: src::File,
		ns: parser::NamespaceID,
		ms: parser::MemberScopeID) TAGGED CTValue
	{
		nesting: U2;
		lhs: TAGGED CTValue (NOINIT);

		// Parse first value.

		// 1.: skip all opening parentheses.
		WHILE(p.consume_s(:Punctuation(:parentheseOpen))) ++nesting;

		// 2.: expect atom.
		TRY SWITCH(p.type())
		{
		:Number: {
			lhs := p.payload().Number;
			p.next();
		}
		:Identifier: {
			ident_at ::= p.progress();

			global_name ::= p.stype().Identifier;
			local_name ::= p.payload().Identifier;
			p.next();

			// We realistically only accept global variables here.
			constant: parser::GlobalVariable *;

			// ident::
			IF(p.consume_s(:Punctuation(:doubleColon)))
			{
				found ::= FALSE;
				was_member_scope: BOOL;
				member_scope: MemberScopeID;
				namespace: NamespaceID;

				// If we are currently within a class context, look up the name in the class first, before checking namespaces.
				IF(ms)
				{
					decl_id ::= ident::get_file_decl_from_local(file, local_name);
					IF(e ::= ms.get_ok()->lookup_inner_t(decl_id))
					{
						IF(s ::= e->MemberScope)
						{
							member_scope := s;
						} ELSE {
							ASSERT(e->Type == :Typedef);
							IF:!(e ::= resolve_typedef_as_scope(e->Entry.Typedef.get()))
								p.fail_before(ident::get(global_name), " is referring to a type without a scope");
							member_scope := e;
						}
						was_member_scope := TRUE;
						found := TRUE;
					}
				}

				// We did not find it, look it up in the namespace.
				IF(!found)
				{
					ns_ptr ::= ns.get();
					IF:!(entry ::= ns_ptr->lookup_inner_s(ident::get_global_decl(global_name)))
						p.fail_pos(ident_at, ident::get(global_name), " does not refer to a scope");
					found := TRUE;
					IF(entry->Type == :Namespace)
					{
						was_member_scope := FALSE;
						namespace := entry->Mem.Namespace;
					} ELSE IF(entry->Type == :Typedef)
					{
						IF:!(e ::= resolve_typedef_as_scope(e->Entry.Typedef.get()))
							p.fail_before(ident::get(global_name), " is referring to a type without a scope");
						member_scope := e;
						was_member_scope := TRUE;
					} ELSE
					{
						offset ::= parser::Members::member_offset[entry->Type];
						member_scope := *<parser::MemberScopeID *>(
							<UM>(mempool::get_memory(entry->Mem.Nil)) + offset);
						was_member_scope := TRUE;
					}
				}

				DIE "cont. traversing symbol until we reach a constant.";
			} ELSE {
				// ident, no ::, treat as value.


				// If we are currently within a class context, look up the name in the class first, before checking namespaces.
				IF(ms)
				{
					decl_id ::= ident::get_file_decl_from_local(file, local_name);
					IF(e ::= ms.get_ok()->lookup_inner_v(decl_id))
					{
						IF(e->Type != :StaticField)
							= :Deferred;

						constant := e->Entry.StaticField.get();
					}
				}

				// We did not find it, look it up in the namespace.
				IF(!found)
				{
					ns_ptr ::= ns.get();
					IF:!(entry ::= ns_ptr->lookup_inner_v(ident::get_global_decl(global_name)))
						p.fail_pos(ident_at, ident::get(global_name), " does not refer to a scope");

					STATIC var_offset: U4#[TABLE ENUM scoper::VGlobal](
						:Nil(~0),
						:Function(~0),
						:ExportFunction(~0),
						:ExternFunction(~0),
						:Variable(<UM>(<parser::GlobalVariable *>(NULL))),
						:ExportVariable(<UM>(&<parser::ExportVariable *>(NULL)->Var)),
						:ExternVariable(~0));

					offset ::= var_offset[entry->Type];
					constant := <parser::GlobalVariable *>(
							<UM>(mempool::get_memory(entry->Mem.Nil)) + offset);

					IF(offset == <U4>(~0))
						= :Deferred;
				}
			}

			FOR(;;){
				SWITCH(p.type())
				{
					// ident::ident2
				:Identifier:
				{
					IF(was_member_scope)
					{
						 // lookup name in member scope
					} ELSE
					{
						// lookup name in namespace.
					}
				}
				:Punctuation:
					SWITCH(p.stype())
					{
						// ident::[  -- templates (ident::[T]ident2)
					:bracketOpen: {
						DIE "templates";
					}
					}
				}
			}
		} // /:Identifier
		} CATCH(err: CHAR #\) p.fail("expected expression atom:\n", err);
	}

	ParsedType {
		as_member_scope() MemberScopeID := NULL;
	}

	get_parsed_type(id: parser::TypeID) ParsedType := ();

	resolve_typedef_as_scope(td: parser::Typedef *) MemberScopeID
	{
		type_id ::= td->Type.Preparse;

		type ::= get_parsed_type(type_id);

		= type.as_member_scope();
	}

	parse_eval_binary_expression(p: parser::Parser &) TAGGED CTValue {
	}
}