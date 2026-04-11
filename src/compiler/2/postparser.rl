::rlc::compiler CodePostParser
{
	// The global rootscope. This is the only real output of the preparser.
	RootScope: scoper::Namespace \;

	// Gets reset after every file.
	PRIVATE MemberScopes: parser::Members \ -std::Vec; // we might also want to be registering other things here, such as a list of all functions, or all return types or something. And we might want to have a union type that we can patch in the post-pass, so that we do not need to move data around.

	// Up to 1K requests per batch, and multiple parallel batches?
	RequestedTypes: U2[1024]-std::Vec; // gets written by the type dedupler. We only read.
	Writeback: parser::TypeU *[1024]-std::Vec; // entirely local.



	// Workflow: one thread (or multiple threads?) traverses the root scope, and one more thread receives requests to deduplicate types. We want to create entries for the instantiator, so that each type first gets deduplicated and then checked whether it already got instantiated.
	// We pass requests in batches to reduce the synchronisation overhead.




	post_parse_type(v: parser::Parser &, out: PostParsedType \) VOID
	{
		SWITCH(p.type())
		{
		:AuxKeyword:
			SWITCH(p.stype().AuxKeyword)
			{
			:this:
			{ p.next(); Type += :This (p.consume_s(:Punctuation(:exclamationMark))); }
			:void: Type += :Void;
			:null: Type += :Null;
			}
		:Declaration:
			SWITCH(p.stype().Declaration)
			{
			:enum: { type_parse_symbol(p); Type += :Enum; }
			}
		:BuiltinType:
		{
			Type += :BuiltinType(p.stype().BuiltinType);
		}
		:Identifier: { type_parse_symbol(p); }
		:Punctuation:
			SWITCH(p.stype().Punctuation)
			{
			:doubleColon: { type_parse_symbol(p); }
			:colon: {
				p.next();
				IF(id ::= p.consume_p(:Identifier))
					IF(p.consume_s(:Punctuation(:dot)))
					{
						post_parse_type(p);
						Type += :TemplateSymbolType(id->Identifier);
					} ELSE
						Type += :SymbolType(id->Identifier);
				ELSE p.fail("TODO: special symbols");
			}
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
					FOR(; p.consume_s(:comma); elems++)
						post_parse_type(p);
					p.expect_s(:Punctuation(:braceClose));
					Type += :TupleType(elems);
				}
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

				Type += :FnSigType(args);
			}
		}
	}



	post_parse_namespace_types(ns: scoper::Namespace \) VOID
	{
		FOR(ns->Entries!)
		{
			idx ::= IT.(0);
			entry ::= IT.(1).get();

			mem ::= entry->NVMem;
			IF(t ::= entry->NVType) SWITCH!(t)
			{
			:Nil: { ; }
			:Namespace:
				post_parse_namespace_types(<scoper::Namespace-Handle>(mem).get());
			:Class:
				post_parse_class_types(<parser::Class-Handle>(mem).get());
			:Rawtype:
				post_parse_rawtype_types(<parser::Rawtype-Handle>(mem).get());
			:Typedef:
				post_parse_typedef(<parser::Typedef-Handle>(mem).get());
			:Mask:
				post_parse_mask_types(<parser::Mask-Handle>(mem).get());
			:Union:
				post_parse_union_types(<parser::Union-Handle>(mem).get());
			:Enum: { ; }
			}

			mem := entry->VMem;
			IF(t ::= entry->VType) SWITCH!(t)
			{
			:Nil: { ; }
			:Function:
				post_parse_function_types(<parser::Function-Handle>(mem).get());
			:ExportFunction:
				post_parse_export_function_types(<parser::ExportFunction-Handle>(mem).get());
			:ExternFuncation:
				post_parse_extern_function_types(<parser::ExternFunction-Handle>(mem).get());
			:Variable:
				post_parse_global_variable_type(<parser::GlobalVariable-Handle>(mem).get());
			:ExportVariable:
				post_parse_export_variable_type(<parser::ExportVariable-Handle>(mem).get());
			:ExternVariable:
				post_parse_extern_variable_type(<parser::ExternVariable-Handle>(mem).get());
			}
		}
	}

	parser(span: TokenSpan #&) parser::Parser {
		DIE;
	}

	post_parse_typedef(v: parser::Typedef *) VOID
	{
		p ::= parser(v->Type.Preparse);

		post_parse_type(p, &v->Type.Postparse);
		p.expect_done();
	}

	post_parse_class_types(v: parser::Class *) VOID
	{
		post_parse_members_types(v->Members);
	}

	post_parse_rawtype_types(v: parser::Rawtype *) VOID
	{
		post_parse_members_types(v->Members);
	}

	post_parse_mask_types(v: parser::Mask *) VOID
	{
		post_parse_members_types(v->Members);
	}

	post_parse_union_types(v: parser::Union *) VOID
	{
		post_parse_members_types(v->Members);
	}


	post_parse_function_types(v: parser::Function *) VOID
	{
		{
			p ::= parser(v->Return.Preparse.Type);

			post_parse_type(p, &v->Type.Postparse.Type);
			v->Type.Postparse.Inline := p.consume(:Punctuation(:colon));
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
		}
	}

	post_parse_export_function_types(v: parser::ExportFunction *) VOID
	{
		post_parse_function_types(&v->Fn);
	}

	post_parse_extern_function_types(v: parser::ExternFunction *) VOID
	{
		{
			p ::= parser(v->Return.Preparse.Type);

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
		}
	}

	post_parse_global_variable_type(v: parser::GlobalVariable *) VOID
	{
		p ::= parser(v->Type.Preparse);
		post_parse_type(p, &v->Type.Postparse);
		p.expect_done();
	}

	post_parse_export_variable_type(v: parser::ExportVariable *) VOID
	{
		post_parse_global_variable_type(&v->Var);
	}

	post_parse_extern_variable_type(v: parser::Extern *) VOID
	{
		p ::= parser(v->Rest);
		post_parse_type(p, v->Type.PostParse);
		p.expect_done();
	}
}