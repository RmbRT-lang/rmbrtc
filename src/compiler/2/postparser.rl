INCLUDE "types.rl"
INCLUDE "type-processor.rl"

::rlc::compiler CodePostParser
{
	// The global rootscope. This is the only real output of the preparser.
	RootScope: scoper::Namespace \;

	Code: type::InterleavedByteCodes-std::Vec;
	Contexts: type::RequestContext[###type::InterleavedByteCodes];
	Spans: type::ByteCodeSpan[###type::InterleavedByteCodes];
	CurrentRequest: U1;
	CurrentRequestStart: U4;
	CurrentRequestLength: U2;

	FileTokens: tok::FileTokenView[#];


	{
		rootScope: scoper::Namespace \,
		fileTokens: tok::FileTokenView[#]
	}:
		RootScope := rootScope,
		FileTokens := fileTokens,
		Code := :reserve(2048),
		Contexts (NOINIT),
		Spans (NOINIT);




	Entries {
		Data: VOID *[];
		Count: U4;

		append_if(if: BOOL, data: VOID *) VOID --
			{ Data[Count] := data; Count += if; }

		[T]get() T * [#] -- := <T **>(&Data[0])[FOR Count];
	}

	post_parse_ns(ns: scoper::Namespace \) VOID
	{

		ListAlloc: std::temp::Alloc - std::Alloc (BARE);
		ListAlloc.Impl.{ :custom(1*MI, 1*MI) };

		Values: Entries[TABLE scoper::ValueGlobal];
		NonValues: Entries[TABLE scoper::NonValueGlobal];

		// We over-allocate the entries. But we skip all namespaces and enums.
		entries ::= ListAlloc.[VOID *]alloc_array(
			##ns->Entries * ((###scoper::NonValueGlobal-3) + (###scoper::ValueGlobal-1))
		)[];

		STATIC dummy: VOID *[1] (NOINIT);

		nv_exclude ::= scoper::NonValueGlobal::FLAGS(:Nil, :Namespace, :Enum);

		consumed ::= 0;
		FOR(NonValues)
		{
			IF(1 << <U1>(IOTA) & nv_exclude)
				CONTINUE;

			IT.Data := (&entries[consumed])[];
			consumed += ##ns->Entries;
		}
		FOR(Values)
		{
			IF(IOTA == :Nil) CONTINUE;

			IT.Data := (&entries[consumed])[];
			consumed += ##ns->Entries;
		}
		NonValues[:Nil].Data := dummy[];
		NonValues[:Namespace].Data := dummy[];
		NonValues[:Enum].Data := dummy[];
		Values[:Nil].Data := dummy[];

		value_entry ::= 0;

		entry ::= 0;
		FOR(ns->Entries!)
		{
			lut_ptr ::= ns->Lut[IT.(0)].get();
			value_ptr ::= mempool::get_memory(lut_ptr->Value.Mem);
			nonvalue_ptr ::= mempool::get_memory(lut_ptr->NonValue.Mem);

			is_value ::= lut_ptr->Value.Type;
			is_nonvalue ::= lut_ptr->NonValue.Type;

			value_entry ::= entry;
			nonvalue_entry ::= entry+is_value;


			Values[is_value].append_if(is_value, value_ptr);
			NonValues[is_nonvalue].append_if(1<< <U1>(is_nonvalue) & ~nv_exclude, nonvalue_ptr);

			entry += <BOOL>(is_value) + <BOOL>(is_nonvalue);
		}

		// Process all values.
		FOR(Values[:Function].[parser::Function]get())
		{
			public_job_sig(IT->Return, ns, NULL); // &IT.Templates);
		}
		FOR(Values[:ExportFunction].[parser::ExportFunction]get())
		{
			{
				p ::= parser(IT->Fn.Args);
				post_parse_function_args(p, ns, NULL);
				p.expect_done();
			}

			public_job_sig(IT->Fn.Return, ns, NULL);
		}
		FOR(Values[:ExternFunction].[parser::ExternFunction]get())
		{
			p ::= parser(IT->Args);
			post_parse_function_args(p, ns, NULL);
			p.expect_done();

			p := parser(IT->Rest.Preparse.Type);
			post_parse_type(p);
			p.expect_done();
		}
		FOR(Values[:Variable].[parser::GlobalVariable]get())
		{
			public_job(IT->Type, ns, NULL);
		}
		FOR(Values[:ExportVariable].[parser::ExportVariable]get())
		{
			public_job(IT->Var.Type, ns, NULL);
		}
		FOR(Values[:ExternVariable].[parser::ExternVariable]get())
		{
			public_job(IT->Type, ns, NULL);
		}

		// Process all nonvalues.
		FOR(NonValues[:Class].[parser::Class]get())
			post_parse_class_types(IT);

		FOR(NonValues[:Rawtype].[parser::Rawtype]get())
		{
			post_parse_members_types(&IT->Members);
		}

		FOR(NonValues[:Typedef].[parser::Typedef]get())
		{
			public_job(IT->Type, ns, NULL); // &IT->Templates);
		}

		FOR(NonValues[:Mask].[parser::Mask]get())
		{
			post_parse_members_types(&IT->Members);
		}

		FOR(NonValues[:Union].[parser::Union]get())
		{
			post_parse_union_types(IT);
		}
	}


	// parse all return types or other public-facing types in a member scope.
	post_parse_members_types(ms: parser::Members \) VOID
	{
		FOR(ms->Entries!)
		{
			idx ::= IT.(0);
			entry ::= IT.(1).get();

			IF(t ::= entry->NonValue.Type) SWITCH!(t)
			{
			:Nil: { ; }
			:Class:
				post_parse_class_types(
					<parser::Class-Handle>(entry->NonValue.Entry.Normal.Memory).get());
			:Rawtype:
				post_parse_rawtype_types(
					<parser::Rawtype-Handle>(entry->NonValue.Entry.Normal.Memory).get());
			:Typedef:
				post_parse_typedef(
					<parser::Typedef-Handle>(entry->NonValue.Entry.Normal.Memory).get());
			:Mask:
				post_parse_mask_types(
					<parser::Mask-Handle>(entry->NonValue.Entry.Normal.Memory).get());
			:Union:
				post_parse_union_types(
					<parser::Union-Handle>(entry->NonValue.Entry.Normal.Memory).get());
			:Enum: { ; }
			}

			IF(t ::= entry->Value.Type) SWITCH!(t)
			{
			:Nil: { ; }
			:Field:
				post_parse_member_variable_type(
					<parser::MemberVariable-Handle>(entry->NonValue.Entry.Normal.Memory).get());
			:StaticField:
				post_parse_global_variable_type(
					<parser::GlobalVariable-Handle>(entry->NonValue.Entry.Normal.Memory).get());
			:MemberFunction:
				post_parse_function_types(
					&<parser::MemberFunction-Handle>(entry->NonValue.Entry.Normal.Memory)->Fn);
			:StaticMemberFunction:
				post_parse_function_types(
					<parser::Function-Handle>(entry->NonValue.Entry.Normal.Memory).get());
			:EnumConstant: { ; }
			:UnionField:
				DIE;
				// post_parse_type(<parser::UnionField \>(mem));
			}
		}
	}


	post_parse_function_args(
		p: parser::Parser &,
		ns: scoper::Namespace \,
		templateCtx: :TemplateCtx *) VOID
	{
		p.expect_s(:Punctuation(:parentheseOpen));
		IF!(p.consume_s(:Punctuation(:parentheseClose)))
		{
			DO()
			{
				// arg: Type ?
				IF(p.match_ps(:Identifier, :Punctuation(:colon)))
				{
					name ::= p.stype().Identifier;
					p.next2();
					post_parse_type(p);
				} ELSE {
					// Type
					post_parse_type(p);
				}
			} WHILE(p.consume_s(:Punctuation(:comma)))
			p.expect_s(:Punctuation(:parentheseClose));
		}
	}

	public_job_sig(
		sig: parser::SignatureRest &,
		scope: scoper::Namespace \,
		templateCtx: :TemplateCtx *) VOID --
	{
		p ::= parser(sig.Preparse.Type);
		post_parse_type(p);
		sig.Postparse.Inline :=
			p.consume_s(:PrefixOrPostfixOp(:doubleMinus)) ||
			p.consume_s(:AuxKeyword(:inline));

		p.expect_done();
	}

	public_job(
		type: parser::TypeU &,
		scope: scoper::Namespace \,
		templateCtx: :TemplateCtx *) VOID --
	{
		p ::= parser(type.Preparse);
		post_parse_type(p);
		// type.PostParse := ???;
		p.expect_done();
	}


	// Workflow: one thread (or multiple threads?) traverses the root scope, and one more thread receives requests to deduplicate types. We want to create entries for the instantiator, so that each type first gets deduplicated and then checked whether it already got instantiated.
	// We pass requests in batches to reduce the synchronisation overhead.

	submit_batch() VOID { ; }
	end_request() :?
	{
		Spans[CurrentRequest++] := (CurrentRequestStart, CurrentRequestLength + CurrentRequestLength);
		CurrentRequestStart += CurrentRequestLength;
		CurrentRequestLength := 0;

		IF(!CurrentRequest) submit_batch();

		= :?;
	}

	emit_bytecode(op: TAGGED types::ByteCode) VOID --
	{
		IF(##Code == CurrentRequestLength)
		{
			Code.prepare_pushback();
			Code.set_size_ok(CurrentRequestLength+1);
		}
		Code[:ok(CurrentRequestLength++)][CurrentRequest] := op;
	}

	post_parse_type(p: parser::Parser &) VOID
	{
		SWITCH(p.type())
		{
		:AuxKeyword:
			SWITCH(p.stype().AuxKeyword)
			{
			:this:
			{ p.next(); emit_bytecode(:MakeThisType(p.consume_s(:PrefixOrPostfixOp(:exclamationMark)))); }
			:void: emit_bytecode(:MakeVoid);
			:null: emit_bytecode(:MakeNullType);
			}
		:Declaration:
			SWITCH(p.stype().Declaration)
			{
			:enum:
			{ p.next(); emit_bytecode(:GetUnionTag); type_parse_symbol(p); }
			}
		:BuiltinType:
		{
			emit_bytecode(:MakeBuiltinType(p.stype().BuiltinType));
			p.next();
		}
		:Identifier: { type_parse_symbol(p); }
		:Punctuation:
			SWITCH(p.stype().Punctuation)
			{
			:doubleColon: type_parse_root_symbol(p);
			:colon: {
				p.next();
				IF(id ::= p.consume_p(:Identifier))
					IF(p.consume_s(:BinaryOp(:dot)))
					{
						emit_bytecode(:MakeTemplateSymbolType(id->Identifier));
						post_parse_type(p);
					} ELSE
						emit_bytecode(:MakeSymbolType(id->Identifier));
				ELSE p.fail("TODO: special symbols");
			}
			:bracketOpen: type_parse_symbol(p);
			:braceOpen:
			{
				p.next();
				post_parse_type(p);
				IF(p.consume_s(:Punctuation(:braceClose)))
				{
					;
				} ELSE
				{
					elems ::= 1;
					FOR(; p.consume_s(:Punctuation(:comma)); elems++)
						post_parse_type(p);
					p.expect_s(:Punctuation(:braceClose));
					emit_bytecode(:MakeTuple(elems));
				}
			}
			:parentheseOpen:
			{
				p.next();
				p.expect_s(:Punctuation(:parentheseOpen));
				args ::= 0;
				IF(p.match_ss(:AuxKeyword(:void), :Punctuation(:parentheseClose)))
					p.next2();
				ELSE IF!(p.consume_s(:Punctuation(:parentheseClose)))
				{
					DO ()
						post_parse_type(p);
						FOR(p.consume_s(:Punctuation(:comma)); args++)
					p.expect_s(:Punctuation(:parentheseClose));
				}

				post_parse_type(p);

				p.expect_s(:Punctuation(:parentheseClose));

				emit_bytecode(:MakeFnSig(args));
			}
			}
		}

		// pointers, arrays, indirections, etc.
		DO(progress ::= p.progress())
		{
			SWITCH?(p.type())
			{
			:Punctuation:
				SWITCH?(p.stype().Punctuation)
				{
				:bracketOpen: DIE; // array, etc.
				}
			:PrefixOrBinaryOp:
				SWITCH?(p.stype().PrefixOrBinaryOp)
				{
				:asterisk: { emit_bytecode(:MakePointer); }
				// T-std::Vector  -> std::[T]Vector
				// V-std::[K]Map  -> std::[K;V]Map
				:minus:
				{
					type_parse_symbol(p);
					emit_bytecode(:AddTemplateArg);
				}
				}
			}
		} FOR(progress != p.progress(); progress := p.progress())


	}

	// ::symbol
	// [T]symbol
	// symbol::child
	// NOTE: Before calling, set out->Context.

	// std::[INT *]Vector
	// INT *
	// std::[?]Vector
	type_parse_symbol(
		p: parser::Parser &) VOID
	{
		SWITCH(p.type())
		{
		:Identifier: type_parse_relative_symbol(p);
		:Punctuation:
			SWITCH(p.stype().Punctuation)
			{
			:doubleColon: type_parse_root_symbol(p);
			:bracketOpen: type_parse_relative_symbol(p);
			}
		}
	}

	// (RootScope)::rootSymbol    -> :RootScope, :LookupChild(rootSymbol)
	// parent::child              -> parent,     :LookupChild(child)
	// parent::[T]child           -> parent,     :LookupChild(child), :InstantiateTemplate(T)
	// parent::[std::String]child
	(/ :Relative(parent), :Relative(std), :Child(String), :PushAsTpl,   :Child(child), :Tpl(1)
	       parent         parent           parent         parent         parent::child
	                      std              std::String    [std::String]  std::String

	       parent::[std::string]child
	/)
	// LookupChild resolves child in parent,


	// only call this after we already saw the :: token.
	type_parse_root_symbol(
		p: parser::Parser &) VOID
	{
		p.expect_s(:Punctuation(:doubleColon));

		IF(p.match_s(0, :Punctuation(:bracketOpen)))
			type_parse_templates(p);

		name ::= p.expect_p(:Identifier).Identifier;

		scope_at ::= p.progress();
		IF(p.consume_s(:Punctuation(:doubleColon)))
		{
			// we want the child as a scope.
			emit_bytecode(:LookRootScope(name));
			type_parse_symbol_child(p);
		} ELSE
		{
			// we want the child as a type.
			emit_bytecode(:LookRootType(name));
		}
	}

	// after we already saw the [ token or the identifier.
	type_parse_relative_symbol(
		p: parser::Parser &) VOID
	{
		IF(p.match_s(0, :Punctuation(:bracketOpen)))
			type_parse_templates(p);

		name ::= p.expect_p(:Identifier).Identifier;

		scope_at ::= p.progress();
		IF(p.consume_s(:Punctuation(:doubleColon)))
		{
			// we want the child as a scope.
			emit_bytecode(:LookRelativeScope(name));
			type_parse_symbol_child(p);
		} ELSE
		{
			// we want the child as a type.
			emit_bytecode(:LookRelativeType(name));
		}
	}

	// {parent_scope::}child_symbol
	// {parent_scope::}[T]child_symbol
	type_parse_symbol_child(
		p: parser::Parser &) VOID
	{
		IF(p.match_s(0, :Punctuation(:bracketOpen)))
			type_parse_templates(p);

		name_at ::= p.progress();
		name ::= p.expect_p(:Identifier).Identifier;

		scope_at ::= p.progress();
		WHILE(p.consume_s(:Punctuation(:doubleColon)))
		{
			// we want the child as a scope.
			emit_bytecode(:LookChildScope(name));

			// parse next child.
			IF(p.match_s(0, :Punctuation(:bracketOpen)))
			{
				type_parse_templates(p);
			}
			name_at := p.progress();
			name := p.expect_p(:Identifier).Identifier;
		}

		// we want the child as a type.
		emit_bytecode(:LookChildType(name));
	}

	// TODO: do we even want to keep types and expressions separate anymore?
	parse_expression(p: parser::Parser &) VOID
	{
		DIE;
	}

	type_parse_templates(p: parser::Parser &) VOID
	{
		p.expect_s(:Punctuation(:bracketOpen));

		IF(p.consume_s(:Punctuation(:bracketClose)))
			RETURN;

		pack_count ::= 0;
		DO()
		{
			pack_size ::= 0;
			DO()
			{
				IF(p.consume_s(:Punctuation(:hash)))
				{
					parse_expression(p);
				} ELSE
				{
					post_parse_type(p);
				}
				emit_bytecode(:PushAsTemplate);
				++pack_size;
			} WHILE(p.consume_s(:Punctuation(:comma)))
			emit_bytecode(:PushTemplatePack(pack_size));
			++pack_count;
		} WHILE(p.consume_s(:Punctuation(:semicolon)))

		emit_bytecode(:AddTemplatePacks(pack_count));
		p.expect_s(:Punctuation(:bracketClose));
	}

	post_parse_member_variable_type(parser::MemberVariable *) VOID { DIE; }

	SpanParser -> parser::Parser {
		End: U4;

		{
			tokens: tok::FileTokenView #&,
			file: src::File,
			start: U4,
			end: U4
		}-> (tokens, file):
			End := end
		{
			->(parser::Parser).advance_by(start);
		}

		expect_done() VOID -- {
			IF(->(parser::Parser).Token != End)
				->(parser::Parser).fail("expect_done()");
		}
	}

	parser(span: parser::TokenSpan #&) SpanParser
		:= (FileTokens[span.File], span.File, span.Start, span.End);

	post_parse_typedef(v: parser::Typedef *) VOID
	{
		p ::= parser(v->Type.Preparse);

		post_parse_type(p);
		p.expect_done();
		v->Type.PostParse := end_request();
	}

	post_parse_class_types(v: parser::Class *) VOID
	{
		// TODO: inheritance.
		post_parse_members_types(&v->Members);
	}

	post_parse_rawtype_types(v: parser::Rawtype *) VOID
	{
		post_parse_members_types(&v->Members);
	}

	post_parse_mask_types(v: parser::Mask *) VOID
	{
		post_parse_members_types(&v->Members);
	}

	post_parse_union_types(v: parser::Union *) VOID
	{
		post_parse_members_types(&v->Members);
	}


	post_parse_function_types(v: parser::Function *) VOID
	{
		{
			p ::= parser(v->Return.Preparse.Type);

			post_parse_type(p);
			v->Return.Postparse.Inline := p.consume_s(:PrefixOrPostfixOp(:doubleMinus));
			p.expect_done();
			v->Return.Postparse.Type := end_request();
		}

		{

			p ::= parser(v->Args);
			IF(v->Args)
			{
				DO()
					post_parse_arg(p);
					WHILE(p.consume_s(:Punctuation(:comma)))

				p.expect_done();
			}
		}
	}

	post_parse_arg(p: parser::Parser &) VOID { DIE; }

	post_parse_export_function_types(v: parser::ExportFunction *) VOID
	{
		post_parse_function_types(&v->Fn);
	}

	post_parse_extern_function_types(v: parser::ExternFunction *) VOID
	{
		DIE;
		(/
		{
			p ::= parser(v->Fn.Return.Preparse.Type);

			post_parse_type(p, &v->Type.Postparse.Type);
			p.expect_done();
		}

		{
			p ::= parser(v->Args.Preparse);

			IF!(p.done())
			{
				DO()
					post_parse_arg(p);
					WHILE(p.consume(:Punctuation(:comma)))

				p.expect_done();
			}
		}/)
	}

	post_parse_global_variable_type(v: parser::GlobalVariable *) VOID
	{
		p ::= parser(v->Type.Preparse);
		post_parse_type(p);
		p.expect_done();
	}

	post_parse_export_variable_type(v: parser::ExportVariable *) VOID
	{
		post_parse_global_variable_type(&v->Var);
	}

	post_parse_extern_variable_type(v: parser::ExternVariable *) VOID
	{
		DIE;
		(/
		p ::= parser(v->Rest);
		post_parse_type(p, v->Type);
		p.expect_done();/)
	}
}