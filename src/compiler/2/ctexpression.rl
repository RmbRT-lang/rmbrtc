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

	// NOTE: This should not be needed, as we can directly execute the action.
	ENUM _CTOp {
		Deferred,
	?	Cast,
	?	Operator
	}

	ExpParserState {
		Precedence: U1;
		Lhs: TAGGED CTValue;
	}

	(/ Evaluating a compile time expression:

		Example: ###[4]F, with [#N] TYPE F := INT[16*N];
			So, we have ###[#N]F, which is a fixed formula. We can generate the code for 16*N as a callable "function" (or interpreter code snippet), and execute that on #N. This way, we do not need to actually instantiate [4]F. Of course, this is a dumb example, but for more complex cases, we can simply generate code that does what we want. At first, that code is interpreter bytecode, but later, would be native code. Thus, evaluating a compile-time expression could just be a call into pre-generated code.

			But only template-dependent expressions need this. Constant expressions should not go through a code generation step. /)

	ParseEvalState {
		P: parser::Parser;
		LastState: ExpParserState;

		Ns: parser::NamespaceID;
		Ms: parser::MemberScopeID;
		File: src::File;

		Stack: ExpParserState-std::Vec;
	}

	// Context for Templates during a lookup: Have a context list of all the template bindings that exist right now, and then on the templateable things, store the index in the context list where they are bound. That way, we do not need a complicated lookup to patch the bindings, as they will directly exist on the templateable.
	// However, there is a problem with this: when we are inside a class and then refer a modified version of the class, like [T]Ptr referring to [T#]Ptr, then we would need to be able to handle that somehow. Also, the modification would not work with multiple variants of a class being passed and then used, because the bindings would be overwritten. So, instead, we will do this:
	// When we enter a template binding context, and we encounter a new templateable, we assign an ID to it (counting from 1 upwards), which is stored directly on the templateable as a scratchpad value. And then, when we bind arguments to the templateable, we take (ID, ArgsID) as the instance description. We then have a pack of template arguments bound to this ID, and the ArgsID table of argument packs remains fairly small. Maybe we even want to deduplicate template arguments and especially entire argument packs, so that redundant instances can be eliminated symbolically. The number of simultaneously active instantiatiations and number of template bindings should be fairly small, so we might not even need something like a hash map or anything like that. A linear search, maybe paired with hashes, should be sufficient.

	TemplateBinding {
		TemplateableID: U2;
		ArgsPackID: U2;
	}

	Templateable {
		STATIC CurrentGen: U4;
		STATIC LastID: U2; // The active set should rarely exceed a handful.

		Generation: U4; // Any collision in under minutes of compile times is basically physically impossible.
		ID: U2; // More than 64k concurrently used things should be impossible, too.
	}

	TemplateBindingContext {
		// IDs for templateables are stored on the templateables themselves. Maybe we also store a backpointer list for cleaning them up afterwards? Or we use a generational value kind of thing, then we do not have a cleanup pass at all.
		Args: TAGGED CTValue - std::Vec;

		// This allows us to quickly check for equality
		ArgSet {
			Hash: U4;
			Start: U2;
			Count: U2;
		}
		// Realistically, there should not be many active arg sets at any moment, so no hash-ordering or hash table or anything like that is required.
		ArgSets: ArgSet-std::Vec;
	}




	// Only for chained / outer lookups.
	UNION IdentScopeRef {
		Members: MemberScopeID;
		Namespace: NamespaceID;
	}

	IdentContext {
		Ms: MemberScopeID;
		Ns: NamespaceID;

		inner_value_lookup() TAGGED CTValue;
		inner_type_lookup() TAGGED CTType;
		inner_scope_lookup() TAGGED IdentScopeRef;
	}

	parse_eval_atom(ctx: ParseEvalState &) TAGGED CTValue {
		TRY SWITCH(p.type())
		{
		:Number: {
			lhs := p.payload().Number;
			p.next();
		}
		:Bool: { DIE; }
		:Identifier: parse_eval_identifier(ctx);
		} CATCH(err: CHAR #\) p.fail("expected expression atom:\n", err);
	}

	inner_value_lookup() TAGGED CTValue
	{
	}

	outer_scope_lookup(state: IdentLookupState) IdentLookupState
	{
	}

	outer_value_lookup() TAGGED CTValue
	{
	}

	parse_eval_identifier(ctx: ParseEvalState &, root: BOOL) TAGGED CTValue
	{
		ASSERT(p.type() == :Identifier);

		ident_at ::= p.progress();

		global_name ::= p.stype().Identifier;
		local_name ::= p.payload().Identifier;
		ctx.P.next();

		// We realistically only accept global variables here.
		constant: parser::GlobalVariable *;

		// First step needs special logic: inner lookup, or global root lookup.

		// Every time we lookup a name that has :: afterwards, we must look it up as a scope. Otherwise, we must look it up as a value.

		IF(!p.consume_s(:Punctuation(:doubleColon)))
			RETURN inner_value_lookup();

		// Descend through scope-chain. Look these up as types/scopes.
		// (ident::)*ident::
		WHILE(p.consume_s(:Punctuation(:doubleColon)))
		{
			found ::= FALSE;
			was_member_scope: BOOL;
			member_scope: MemberScopeID;
			member_scope_p: parser::Members *;
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
					member_scope_p := member_scope.get();
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

			FOR(;;){
				SWITCH(p.type())
				{
					// ident::ident2
				:Identifier:
				{
					IF(was_member_scope)
					{
						// lookup name in member scope
						inner_global_name ::= p.stype().Identifier;
						f ::= member_scope_p->File;
						decl_id ::= ident::get_file_decl_from_global(f, inner_global_name);

						IF:!(entry_h ::= member_scope_p->lookup(decl_id))
							p.fail_before(ident::get(global_name), "::", ident::get(inner_global_name), " does not exist");

						entry ::= entry_h.get();

						p.next();

						IF(p.match(:Punctuation(:doubleColon)))
						{

						} ELSE {

						}
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

			DIE "cont. traversing symbol until we reach a constant.";
		}

		// ident, no trailing ::, treat as value.

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
	} // /:Identifier

	// This parses and evaluates a comptime expression
	parse_eval_expression(ctx: ParseEvalState &) TAGGED CTValue
	{
		nesting: U2;
		lhs: TAGGED CTValue (NOINIT);

		// Parse first value.

		// 1.: skip all opening parentheses.
		WHILE(p.consume_s(:Punctuation(:parentheseOpen))) ++nesting;

		// 2.: expect atom.
		lhs ::= parse_eval_lhs(ctx);
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