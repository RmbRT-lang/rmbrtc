INCLUDE "types.rl"
INCLUDE "type-processor.rl"

::rlc::compiler CodePostParser
{
	// The global rootscope. This is the only real output of the preparser.
	RootScope: scoper::Namespace \;

	Code: type::InterleavedByteCodes-std::Vec;
	Contexts: type::RequestContext[###type::InterleavedByteCodes];
	Spans: type::ByteCodeSpan[###type::InterleavedByteCodes];
	CurrentRequest: U4;
	CurrentRequestStart: U4;
	CurrentRequestLength: U2;

	FileTokens: tok::FileTokenView[#];
	ListAlloc: std::temp::Alloc - std::Alloc;


	{
		rootScope: scoper::Namespace \,
		fileTokens: tok::FileTokenView[#]
	}:
		RootScope := rootScope,
		FileTokens := fileTokens,
		Code := :reserve(2048),
		Contexts (NOINIT),
		Spans (NOINIT),
		ListAlloc(BARE)
	{
		ListAlloc.Impl.{ :custom(1*MI, 1*MI) };
	}




	Entries {
		Data: VOID *[];
		Count: U4;

		append_if(if: BOOL, data: VOID *) VOID --
			{ Data[Count] := data; Count += if; }

		[T]get() T * [#] -- := <T **>(&Data[0])[FOR Count];
	}


	post_parse_ns(ns: scoper::Namespace \) VOID
	{


		Values: Entries[TABLE ENUM scoper::VGlobal];
		NonValues: Entries[TABLE ENUM scoper::NVGlobal];

		save ::= ListAlloc.Impl.save();
		// We over-allocate the entries. But we skip all namespaces and enums.
		entries ::= ListAlloc.[VOID *]alloc_array(
			##ns->Entries * ((###ENUM scoper::NVGlobal-2) + (###ENUM scoper::VGlobal-1))
		)[];

		STATIC dummy: VOID *[1] (NOINIT);

		nv_exclude ::= scoper::NVGlobal::FLAGS(:Nil, :Enum);

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
		//NonValues[:Namespace].Data := dummy[];
		NonValues[:Enum].Data := dummy[];
		Values[:Nil].Data := dummy[];

		value_entry ::= 0;

		entry ::= 0;
		FOR(ns->Entries!)
		{
			lut_ptr ::= ns->Lut[IT.(0)].get();
			value_ptr ::= mempool::get_memory(lut_ptr->Value.Mem.Nil);
			nonvalue_ptr ::= mempool::get_memory(lut_ptr->NonValue.Mem.Nil);

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
			next ::= (&IT)[##RANGE == IOTA+1 ?? 0 : 1];
			post_parse_function_types(IT, next, ns, NULL);
		}
		FOR(Values[:ExportFunction].[parser::ExportFunction]get())
		{
			next ::= (&IT)[##RANGE == IOTA+1 ?? 0 : 1];
			post_parse_function_types(&IT->Fn, &next->Fn, ns, NULL);
		}
		FOR(Values[:ExternFunction].[parser::ExternFunction]get())
		{
			p ::= parser(IT->Args);
			post_parse_function_args(p, ns, NULL, NULL);
			p.expect_done();

			p := parser(IT->Rest.Preparse.Type);
			post_parse_type(p);
			p.expect_done();
		}
		FOR(Values[:Variable].[parser::GlobalVariable]get())
		{
			next ::= (&IT)[##RANGE == IOTA+1 ?? 0 : 1];
			prefetch_tokens(next->Type.Preparse);
			job(IT->Type, ns, NULL, NULL);
		}
		FOR(Values[:ExportVariable].[parser::ExportVariable]get())
		{
			next ::= (&IT)[##RANGE == IOTA+1 ?? 0 : 1];
			prefetch_tokens(next->Var.Type.Preparse);
			job(IT->Var.Type, ns, NULL, NULL);
		}
		FOR(Values[:ExternVariable].[parser::ExternVariable]get())
		{
			next ::= (&IT)[##RANGE == IOTA+1 ?? 0 : 1];
			prefetch_tokens(next->Type.Preparse);
			job(IT->Type, ns, NULL, NULL);
		}

		// Process all nonvalues.
		FOR(NonValues[:Class].[parser::Class]get())
			post_parse_class_types(IT, ns, NULL);

		FOR(NonValues[:Rawtype].[parser::Rawtype]get())
			post_parse_rawtype_types(IT, ns, NULL);

		FOR(NonValues[:Typedef].[parser::Typedef]get())
		{
			post_parse_typedef(IT, ns, NULL, NULL);
		}

		FOR(NonValues[:Mask].[parser::Mask]get())
		{
			post_parse_members_types(ns, &IT->Members);
		}

		FOR(NonValues[:Union].[parser::Union]get())
		{
			post_parse_union_types(IT, ns);
		}

		FOR(NonValues[:Namespace].[scoper::Namespace]get())
		{
			post_parse_ns(IT);
		}

		ListAlloc.Impl.restore(save);
	}


	// parse all return types or other public-facing types in a member scope.
	post_parse_members_types(
		ns: scoper::Namespace \,
		ms: parser::Members \) VOID
	{
		FOR(ms->Entries!)
		{
			idx ::= IT.(0);
			entry ::= IT.(1).get();

			tpl ::= &ms->Templates;

			IF(t ::= entry->NonValue.Type) SWITCH!(t)
			{
			:Nil: { ; }
			:Class:
				post_parse_class_types(entry->NonValue.Entry.Class.get(), ns, ms);
			:Rawtype:
				post_parse_rawtype_types(entry->NonValue.Entry.Rawtype.get(), ns, ms);
			:Typedef:
				post_parse_typedef(entry->NonValue.Entry.Typedef.get(), ns, ms, tpl);
			:Mask:
				post_parse_mask_types(entry->NonValue.Entry.Mask.get(), ns);
			:Union:
				post_parse_union_types(entry->NonValue.Entry.Union.get(), ns);
			:Enum: { ; }
			}

			IF(t ::= entry->Value.Type) SWITCH!(t)
			{
			:Nil: { ; }
			:Field:
				post_parse_member_variable_type(
					entry->Value.Entry.Field.get(), ns, ms);
			:StaticField:
				post_parse_variable_type(
					entry->Value.Entry.StaticField.get(), ns, ms, tpl);
			:MemberFunction:
				post_parse_function_types(
					&entry->Value.Entry.MemberFunction->Fn, NULL, ns, ms);
			:StaticMemberFunction:
				post_parse_function_types(
					entry->Value.Entry.StaticMemberFunction.get(), NULL, ns, ms);
			:EnumConstant: { ; }
			:UnionField:
				post_parse_union_field(entry->Value.Entry.UnionField.get(), ns, ms);
			}
		}
	}


	post_parse_function_args(
		p: parser::Parser &,
		ns: scoper::Namespace \,
		ms: parser::Members *,
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
				}

				// TODO WARNING CAUTION BUG CRITICAL: handle alignment properly.
				IF(p.consume_s(:Punctuation(:at)))
				{
					p.expect_s(:Punctuation(:parentheseOpen));
					p.skip_until_nesting_ends();
					p.expect_s(:Punctuation(:parentheseClose));
				}

				post_parse_type(p);
			} WHILE(p.consume_s(:Punctuation(:comma)))
			p.expect_s(:Punctuation(:parentheseClose));
		}
	}

	job_sig(
		sig: parser::SignatureRest &,
		scope: scoper::Namespace \,
		members: parser::Members *,
		templateCtx: :TemplateCtx *) VOID --
	{
		p ::= parser(sig.Preparse.Type);
		sig.Postparse.Type := post_parse_type(p);
		sig.Postparse.Inline :=
			p.consume_s(:PrefixOrPostfixOp(:doubleMinus)) ||
			p.consume_s(:AuxKeyword(:inline));
		p.expect_done();
	}

	job(
		type: parser::TypeU &,
		scope: scoper::Namespace \,
		members: parser::Members *,
		templateCtx: :TemplateCtx *) VOID --
	{
		p ::= parser(type.Preparse);
		type.PostParse := post_parse_type(p);
		p.expect_done();
	}


	// Workflow: one thread (or multiple threads?) traverses the root scope, and one more thread receives requests to deduplicate types. We want to create entries for the instantiator, so that each type first gets deduplicated and then checked whether it already got instantiated.
	// We pass requests in batches to reduce the synchronisation overhead.

	submit_batch() VOID { }
	end_request() :? --
	{
		Spans[CurrentRequest % ###type::InterleavedByteCodes] := (CurrentRequestStart, CurrentRequestLength + CurrentRequestLength);
		CurrentRequestStart += CurrentRequestLength;
		CurrentRequestLength := 0;

		IF!(++CurrentRequest % ###type::InterleavedByteCodes) submit_batch();

		= :?;
	}

	emit_bytecode(op: TAGGED types::ByteCode) VOID --
	{
		IF(##Code == CurrentRequestLength)
		{
			Code.prepare_pushback();
			Code.set_size_ok(CurrentRequestLength+1);
		}
		Code[:ok(CurrentRequestLength++)][CurrentRequest % ###type::InterleavedByteCodes]
			:= op;
	}

	post_parse_type(p: parser::Parser &) :?
	{
		TRY SWITCH(p.type())
		{
		:AuxKeyword:
			SWITCH(p.stype().AuxKeyword)
			{
			:this:
			{ p.next(); emit_bytecode(:MakeThisType(p.consume_s(:PrefixOrPostfixOp(:exclamationMark)))); }
			:void: { p.next(); emit_bytecode(:MakeVoid); }
			:null: { p.next(); emit_bytecode(:MakeNullType); }
			}
		:Declaration:
			SWITCH(p.stype().Declaration)
			{
			:enum:
			{ p.next(); emit_bytecode(:GetUnionTag); type_parse_symbol(p); }
			:tagged:
			{ p.next(); emit_bytecode(:MakeTaggedUnion); type_parse_symbol(p); }
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
				IF[parse_symbol](id ::= p.consume_p(:Identifier))
					IF(p.consume_s(:BinaryOp(:dot)))
					{
						emit_bytecode(:MakeTemplateSymbolType(id->Identifier));
						post_parse_type(p);
					} ELSE
						emit_bytecode(:MakeSymbolType(id->Identifier));
				ELSE
				{
					STATIC special_table: TAGGED tok::Type[TABLE types::SpecialSymbol](
						:questionMark(:PostfixOp(:questionMark)),
						:exclamationMark(:PrefixOrPostfixOp(:exclamationMark)),
						:less(:BinaryOp(:less)),
						:greater(:BinaryOp(:greater)),
						:lessGreater(:BinaryOp(:lessGreater))
					);

					FOR(special_table)
						IF(p.consume_s(IT))
						{
							emit_bytecode(:MakeSpecialSymbolType(IOTA));
							BREAK [parse_symbol];
						}
					p.fail("expected special symbol ('?', '!', '<', '>', or '<>')");
				}
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
		:PostfixOp:
			SWITCH(p.stype().PostfixOp)
			{
			:questionMark: {
				p.next();
				emit_bytecode(:MakeAutoType);
			}
			}
		} CATCH(err: CHAR#*) { p.fail("expected type:\n", std::str::c(err[])); }

		// pointers, arrays, indirections, etc.
		TRY DO[follow_up](progress ::= p.progress())
		{
			SWITCH(p.type())
			{
			:Punctuation:
				SWITCH(p.stype().Punctuation)
				{
				:parentheseClose, :braceClose, :bracketClose,
				:parentheseOpen, :braceOpen,
				:comma, :semicolon, :colonEqual:
					BREAK [follow_up];
				:bracketOpen:
				{
					p.next();
					IF(p.consume_s(:Punctuation(:bracketClose))) // []
						emit_bytecode(:MakeSlice);
					ELSE IF(p.consume_ss(:Punctuation(:hash), :Punctuation(:bracketClose))) // [#]
						emit_bytecode(:MakeSizedSlice);
					ELSE // [dimension]
					{
						p.skip_until_nesting_ends();
						p.expect_s(:Punctuation(:bracketClose));
						//p.fail("TODO: expression parsing for array bounds");
					}
				}
				:hash: {
					p.next();

					mod: types::PackedModifier;
					mod.set0_constness(
						p.consume_s(:PostfixOp(:questionMark))
						?? types::Constness::Const
						:  types::Constness::MaybeConst);

					emit_bytecode(:AddModifier(mod));
				}
				:tripleDot:
				{
					p.next();
					emit_bytecode(:ExpandVariadicType);
				}
				}
			:PrefixOrBinaryOp:
				SWITCH(p.stype().PrefixOrBinaryOp)
				{
				:asterisk: { p.next(); emit_bytecode(:MakePointer); }
				// T-std::Vector  -> std::[T]Vector
				// V-std::[K]Map  -> std::[K;V]Map
				:minus:
				{
					p.next();
					type_parse_symbol(p);
					emit_bytecode(:AddTemplateArg);
				}
				:amp: {
					p.next();
					m: types::PackedModifier;
					m.set0_region(:UnknownReference);
					emit_bytecode(:AddModifier(m));
				}
				:doubleAmp: {
					p.next();
					m: types::PackedModifier;
					m.set0_region(:ExpiringReference);
					emit_bytecode(:AddModifier(m));
				}
				:plus: {
					p.next(); // T::Type+ is a hack for C++ codegen.
				}
				}
			:PrefixOp:
				SWITCH(p.stype().PrefixOp)
				{
				:backslash: { p.next(); emit_bytecode(:MakeNonNullPointer); }
				}
			:BinaryOp:
				SWITCH(p.stype().BinaryOp)
				{
				:dot: {
					p.next();
					m: types::PackedModifier;
					m.set0_sharedness(:ThreadShared);
					emit_bytecode(:AddModifier(m));
				}
				:circumflex:
				{
					p.next();
					emit_bytecode(:MakeProcessHandle);
				}
				}
			:PrefixOrPostfixOp:
				SWITCH(p.stype().PrefixOrPostfixOp)
				{
				:doubleMinus: BREAK [follow_up];
				}
			}
		} FOR(progress != p.progress(); progress := p.progress())
		CATCH(err: CHAR#*) { p.fail("expected type:\n", std::str::c(err[])); }

		= end_request();
	}

	// ::symbol
	// [T]symbol
	// symbol::child
	// symbol!
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

		IF(p.consume_s(:PrefixOrPostfixOp(:exclamationMark)))
			emit_bytecode(:MakeNoDecayType);
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
		p.skip_until_nesting_ends_or(:comma, :semicolon);
		emit_bytecode(:ExpressionDummy);
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

	post_parse_member_variable_type(
		v: parser::Field *,
		ns: scoper::Namespace \,
		ms: parser::Members \) VOID
	{
		job(v->Type, ns, ms, &ms->Templates);
	}

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

	post_parse_typedef(
		v: parser::Typedef *,
		ns: scoper::Namespace \,
		ms: parser::Members *,
		:TemplateCtx *) VOID
	{
		p ::= parser(v->Type.Preparse);

		v->Type.PostParse := post_parse_type(p);
		p.expect_done();
	}

	post_parse_class_types(
		v: parser::Class *,
		ns: scoper::Namespace \,
		ms: parser::Members *) VOID
	{
		// TODO: inheritance (scoped in ms, not v->Members!)
		post_parse_members_types(ns, &v->Members);
	}

	post_parse_rawtype_types(
		v: parser::Rawtype *,
		ns: scoper::Namespace \,
		ms: parser::Members *) VOID
	{
		// TODO: parse type size and alignment (scoped in ms, not v->Members!)
		post_parse_members_types(ns, &v->Members);
	}

	post_parse_mask_types(
		v: parser::Mask *,
		ns: scoper::Namespace \) VOID
	{
		post_parse_members_types(ns, &v->Members);
	}

	post_parse_union_types(
		v: parser::Union *,
		ns: scoper::Namespace \) VOID
	{
		post_parse_members_types(ns, &v->Members);
	}

	post_parse_union_field(
		v: parser::UnionField *,
		ns: scoper::Namespace \,
		ms: parser::Members \) VOID
	{
		job(v->Type, ns, ms, &ms->Templates);
	}


	post_parse_templates(
		v: parser::Templates &,
		ns: scoper::Namespace \,
		ms: parser::Members *) VOID
	{
		;
	}

	prefetch_tokens(s: parser::TokenSpan #&) VOID -- {
		PREFETCH_READ &FileTokens[][s.File].Hots[s.Start];
	}

	prefetch_function_types(v: parser::Function *) VOID --
	{
		prefetch_tokens(v->Args.Preparse);
		prefetch_tokens(v->Return.Preparse.Type);
	}

	post_parse_function_types(
		v: parser::Function *,
		v_next: parser::Function *,
		ns: scoper::Namespace \,
		ms: parser::Members *) VOID
	{
		prefetch_function_types(v_next ?? v_next : v);

		{
			post_parse_templates(v->Templates, ns, ms);
		}

		{
			p ::= parser(v->Args.Preparse);
			post_parse_function_args(p, ns, ms, &v->Templates.Postparse);
			p.expect_done();
		}

		{
			p ::= parser(v->Return.Preparse.Type);

			v->Return.Postparse.Type := post_parse_type(p);
			v->Return.Postparse.Inline := p.consume_s(:PrefixOrPostfixOp(:doubleMinus));
			p.expect_done();
		}
	}

	post_parse_export_function_types(
		v: parser::ExportFunction \,
		ns: scoper::Namespace \) VOID
	{
		post_parse_function_types(&v->Fn, NULL, ns, NULL);
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

	post_parse_variable_type(
		v: parser::GlobalVariable *,
		ns: scoper::Namespace \,
		ms: parser::Members *,
		tpl: :TemplateCtx *) VOID
	{
		job(v->Type, ns, ms, tpl);
	}
}