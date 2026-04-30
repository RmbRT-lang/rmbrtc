INCLUDE "types.rl"
INCLUDE "values.rl"
INCLUDE "type-processor.rl"

::rlc::compiler CodePostParser
{
	// The global rootscope. This is the only real output of the preparser.
	RootScope: scoper::Namespace \;

	// TODO PERFORMANCE: we want to be able to iterate over all fields of a class, and all functions, etc.. So we want the member scope to already have pre-grouped homogeneous arrays. We can have one global linear allocator for that, though nested classes would break that. OR, we do not even go over it per-class, but just emit a note when parsing. Then, the post-parser can iterate over homogeneous collections. ACTUALLY: we want to only have one huge collection of all types that need to be parsed. And maybe one collection of all arguments and signatures or something. And then we just blaze through those without having to walk any scope tree. That should not be much more work for the preparser. And then variables or functions would simply have a handle to the workload. We could then have a writeback phase maybe that lets us gather all related information for a function etc. in one spot? Idk.
	// We can do the same for function bodies. We can set up a pointer to the namespace and member scope we are in, and a token span. Just jobs for later parsing. Then, we can also reuse the same system for when types depend on values, or when values depend on types. We just add more jobs. And then we can do one huge evaluation of everything, ideally interleaved. That should also solve most of our other problems. We could also do a similar thing for statements within a body, I guess. Though we also have a sequential dependency between things in a body, so we might have to go for interleaved but sequential execution here.

	Code: types::InterleavedByteCodes-std::Vec;
	Contexts: types::RequestContext[###types::InterleavedByteCodes];
	Spans: types::ByteCodeSpan[###types::InterleavedByteCodes];
	CurrentRequest: U4;
	CurrentRequestStart: U4;
	CurrentRequestLength: U2;
	CurrentRequestNs: parser::NamespaceID;
	CurrentRequestMs: parser::MemberScopeID;

	FileTokens: tok::FileTokenView[#];

	{
		rootScope: scoper::Namespace \,
		fileTokens: tok::FileTokenView[#]
	}:
		RootScope := rootScope,
		FileTokens := fileTokens,
		Code := :reserve(2048),
		Contexts (NOINIT),
		Spans (NOINIT)
	{
	}




	Entries {
		Data: VOID *[];
		Count: U4;

		append_if(if: BOOL, data: VOID *) VOID --
			{ Data[Count] := data; Count += if; }

		[T]get() T * [#] -- := <T **>(&Data[0])[FOR Count];
	}


	post_parse() VOID
	{
		prefetch ::= 4;

		// TODO: instead of pointers to namespaces & scopes, we can also just pass along their handles, since we do not use their addresses anyway here.
		FOR(compiler::stage1::parse::Types.Buckets!) FOR(IT)
		{
			next ::= &(&IT)[##RANGE <= IOTA+prefetch ?? 0 : prefetch];
			prefetch_tokens(next->Span);

			CurrentRequestNs := IT.Ns;
			CurrentRequestMs := IT.Ms;

			job(IT.Span,
				NULL, //>IT.Ns, //::rlc::compiler::stage1::parse::Namespaces[:ok(IT.Ns)],
				NULL, //>IT.Ms, //::rlc::compiler::stage1::parse::MemberScopes[:ok(IT.Ms)],
				NULL);
		}

		FOR(compiler::stage1::parse::Arguments.Buckets!) FOR(IT)
		{
			next ::= &(&IT)[##RANGE <= IOTA+prefetch ?? 0 : prefetch];
			prefetch_tokens(next->Span);


			CurrentRequestNs := IT.Ns;
			CurrentRequestMs := IT.Ms;

			p ::= parser(IT.Span);
			IF!(IT.Span) CONTINUE;
			post_parse_function_args(p,
				NULL, //>IT.Ns, //::rlc::compiler::stage1::parse::Namespaces[:ok(IT.Ns)],
				NULL, //>IT.Ms, //::rlc::compiler::stage1::parse::MemberScopes[:ok(IT.Ms)],
				NULL);
			p.expect_done();
		}

		FOR(compiler::stage1::parse::Returns.Buckets!) FOR(IT)
		{
			next ::= &(&IT)[##RANGE <= IOTA+prefetch ?? 0 : prefetch];
			prefetch_tokens(next->Core.Span);

			CurrentRequestNs := IT.Core.Ns;
			CurrentRequestMs := IT.Core.Ms;

			job_sig(IT.Core.Span,
				NULL, //>IT.Core.Ns, //::rlc::compiler::stage1::parse::Namespaces[:ok(IT.Core.Ns)],
				NULL, //>IT.Core.Ms, //::rlc::compiler::stage1::parse::MemberScopes[:ok(IT.Core.Ms)],
				NULL);
		}

		FOR(compiler::stage1::parse::Expressions.Buckets!) FOR(IT)
		{
			next ::= &(&IT)[##RANGE <= IOTA+prefetch ?? 0 : prefetch];
			prefetch_tokens(next->Span);

			CurrentRequestNs := IT.Ns;
			CurrentRequestMs := IT.Ms;

			job_exp(IT.Span);
		}
	}



	post_parse_function_args(
		p: parser::Parser &,
		ns: scoper::Namespace \,
		ms: parser::Members *,
		templateCtx: :TemplateCtx *) VOID --
	{
		IF!(p.match_s(0, :Punctuation(:parentheseClose)))
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

				ArgType ::= post_parse_type(p);
			} WHILE(p.consume_s(:Punctuation(:comma)))
		}
	}

	job_sig(
		sig: parser::TokenSpan &,
		scope: scoper::Namespace \,
		members: parser::Members *,
		templateCtx: :TemplateCtx *) VOID --
	{
		p ::= parser(sig);
		Type ::= post_parse_type(p);
		Inline ::=
			p.consume_s(:PrefixOrPostfixOp(:doubleMinus)) ||
			p.consume_s(:AuxKeyword(:inline));
		p.expect_done();
	}

	job(
		type: parser::TokenSpan &,
		scope: scoper::Namespace \,
		members: parser::Members *,
		templateCtx: :TemplateCtx *) VOID --
	{
		p ::= parser(type);
		PostParse ::= post_parse_type(p);
		p.expect_done();
	}

	job_exp(
		exp: parser::TokenSpan &) VOID --
	{
		p ::= parser(exp);
		PostParse ::= post_parse_expression(p);
		p.expect_done();
	}

	// Expression plan: we differentiate between constant expressions that are available to the type system and those that aren't. Only global integer constant variables get evaluated at compile time. Global variables cannot have runtime initialisers, but other types (such as vectors) cannot be used as compile time constants for stuff like array bounds. Non-integer types will be evaluated at compile time AFTER all type checking is completed, and will have their initialised state baked into the .DATA/.CDATA section (such as lookup tables). We do not want to have to be able to run compile time functions in order to construct types. This means global constant variables cannot call functions as initialisers. Maybe we can later on declare some special kind of compile time functions. Actually, function calls are fine for global initialisers, as long as those functions can be run at compile time. But we do not allow any functions to be run before typing the global scope. So a global integer constant initialised by a function call will still get its initial value baked into .CDATA, but that value will not be available at type checking time.

	(/ Sequence:

		- Parse and resolve all types in global/static scopes, but keep expressions in the types (such as array sizes) as placeholders.
		- For all global variables, do a check whether the type is a constant integer. These are flagged for evaluation during type-checking.
		- Parse all initialisers of global integer constants, and all expressions in types, and try to evaluate these as integer constants. Global constant initialisers abort when they encounter something that is not a compile-time constant (like a function call for example), flagging that constant as deferred to after type-checking. Cyclical dependencies directly trigger a compilation error.
			- Do we want all global constants evaluated before we start processing any bodies? This could be a good guarantee for a more efficient implementation.
			- We might have to instantiate templated constants already, and also we need to be able to access type sizes already.
			- Types cannot depend on deferred or cyclical constants.
		- Parse bodies. Any constants encountered during parsing get inlined. We can also compute deferred constants at this time.
			- Although, we also want to have the same restriction on expression-dependent types in functions, I think -- so, no deferred expressions in types in bodies?

		NOTE: if we used a unified bytecode for types and values, and also had one unified interpreter, we could have "turing-complete" arbitrary compile time execution during type checking. Problems:
			- this could be expensive, because it might be hard to batch-process or multi-thread. (contention, etc.)
			- this could lead to, and encourage, ugly programs.
			- this obfuscates what types and sizes we have from the programmer, and we want high clarity / readability of the code.
	/)


	// runtime expression
	post_parse_expression(p: parser::Parser &) :? --
	{
		parse_expression(p);
		= :?;
	}
	submit_expression_batch() VOID {}
	end_expression_request() :? --
	{ = :?; }
	emit_valuecode(op: TAGGED values::ByteCode) VOID --
	{
	}


	// Workflow: one thread (or multiple threads?) traverses the root scope, and one more thread receives requests to deduplicate types. We want to create entries for the instantiator, so that each type first gets deduplicated and then checked whether it already got instantiated.
	// We pass requests in batches to reduce the synchronisation overhead.

	submit_type_batch() VOID { }
	end_type_request() :? --
	{
		Spans[CurrentRequest % ###types::InterleavedByteCodes] := (CurrentRequestStart, CurrentRequestLength + CurrentRequestLength);
		CurrentRequestStart += CurrentRequestLength;
		CurrentRequestLength := 0;

		IF!(++CurrentRequest % ###types::InterleavedByteCodes) submit_type_batch();

		= :?;
	}

	emit_typecode(op: TAGGED types::ByteCode) VOID --
	{
		IF(##Code == CurrentRequestLength)
		{
			Code.prepare_pushback();
			Code.set_size_ok(CurrentRequestLength+1);
		}
		Code[:ok(CurrentRequestLength++)][CurrentRequest % ###types::InterleavedByteCodes]
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
			{ p.next(); emit_typecode(:MakeThisType(p.consume_s(:PrefixOrPostfixOp(:exclamationMark)))); }
			:void: { p.next(); emit_typecode(:MakeVoid); }
			:null: { p.next(); emit_typecode(:MakeNullType); }
			}
		:Declaration:
			SWITCH(p.stype().Declaration)
			{
			:enum:
			{ p.next(); emit_typecode(:GetUnionTag); type_parse_symbol(p); }
			:tagged:
			{ p.next(); emit_typecode(:MakeTaggedUnion); type_parse_symbol(p); }
			}
		:BuiltinType:
		{
			emit_typecode(:MakeBuiltinType(p.stype().BuiltinType));
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
						emit_typecode(:MakeTemplateSymbolType(id->Identifier));
						post_parse_type(p);
					} ELSE
						emit_typecode(:MakeSymbolType(id->Identifier));
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
							emit_typecode(:MakeSpecialSymbolType(IOTA));
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
					emit_typecode(:MakeTuple(elems));
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

				emit_typecode(:MakeFnSig(args));
			}
			}
		:PostfixOp:
			SWITCH(p.stype().PostfixOp)
			{
			:questionMark: {
				p.next();
				emit_typecode(:MakeAutoType);
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
						emit_typecode(:MakeSlice);
					ELSE IF(p.consume_ss(:Punctuation(:hash), :Punctuation(:bracketClose))) // [#]
						emit_typecode(:MakeSizedSlice);
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

					emit_typecode(:AddModifier(mod));
				}
				:tripleDot:
				{
					p.next();
					emit_typecode(:ExpandVariadicType);
				}
				}
			:PrefixOrBinaryOp:
				SWITCH(p.stype().PrefixOrBinaryOp)
				{
				:asterisk: { p.next(); emit_typecode(:MakePointer); }
				// T-std::Vector  -> std::[T]Vector
				// V-std::[K]Map  -> std::[K;V]Map
				:minus:
				{
					p.next();
					type_parse_symbol(p);
					emit_typecode(:AddTemplateArg);
				}
				:amp: {
					p.next();
					m: types::PackedModifier;
					m.set0_region(:UnknownReference);
					emit_typecode(:AddModifier(m));
				}
				:doubleAmp: {
					p.next();
					m: types::PackedModifier;
					m.set0_region(:ExpiringReference);
					emit_typecode(:AddModifier(m));
				}
				:plus: {
					p.next(); // T::Type+ is a hack for C++ codegen.
				}
				}
			:PrefixOp:
				SWITCH(p.stype().PrefixOp)
				{
				:backslash: { p.next(); emit_typecode(:MakeNonNullPointer); }
				}
			:BinaryOp:
				SWITCH(p.stype().BinaryOp)
				{
				:greater: BREAK [follow_up];
				:dot: {
					p.next();
					m: types::PackedModifier;
					m.set0_sharedness(:ThreadShared);
					emit_typecode(:AddModifier(m));
				}
				:circumflex:
				{
					p.next();
					emit_typecode(:MakeProcessHandle);
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

		= end_type_request();
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
			emit_typecode(:MakeNoDecayType);
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
			emit_typecode(:LookRootScope(name));
			type_parse_symbol_child(p);
		} ELSE
		{
			// we want the child as a type.
			emit_typecode(:LookRootType(name));
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
			emit_typecode(:LookRelativeScope(name));
			type_parse_symbol_child(p);
		} ELSE
		{
			// we want the child as a type.
			emit_typecode(:LookRelativeType(name));
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
			emit_typecode(:LookChildScope(name));

			// parse next child.
			IF(p.match_s(0, :Punctuation(:bracketOpen)))
			{
				type_parse_templates(p);
			}
			name_at := p.progress();
			name := p.expect_p(:Identifier).Identifier;
		}

		// we want the child as a type.
		emit_typecode(:LookChildType(name));
	}

	token_span(start: U4, p: parser::Parser &) parser::TokenSpan --
		:= (p.File, start, p.progress());

	emit_expression_job(parser::TokenSpan) U4 -- := 0;
	emit_storage(types::Storage) U2 -- := 0;

	// TODO: do we even want to keep types and expressions separate anymore?
	parse_expression(p: parser::Parser &) VOID
	{
		start ::= p.progress();
		p.skip_until_nesting_ends_or(:comma, :semicolon);
		job ::= emit_expression_job(token_span(start, p));
		slot ::= emit_storage(:ExpressionLink(job));
		emit_typecode(:StorageLink(:ExpressionLink, slot));
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
				emit_typecode(:PushAsTemplate);
				++pack_size;
			} WHILE(p.consume_s(:Punctuation(:comma)))
			emit_typecode(:PushTemplatePack(pack_size));
			++pack_count;
		} WHILE(p.consume_s(:Punctuation(:semicolon)))

		emit_typecode(:AddTemplatePacks(pack_count));
		p.expect_s(:Punctuation(:bracketClose));
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

	post_parse_templates(
		v: parser::Templates &,
		ns: scoper::Namespace \,
		ms: parser::Members *) VOID
	{
		;
	}

	prefetch_tokens(s: parser::TokenSpan #&) VOID -- {
		addr: UM := > &FileTokens[][s.File].Hots[s.Start];
		PREFETCH_READ <VOID*>(addr + SIZEOF(tok::TokenHot) * (s.End - s.Start) -1);
		PREFETCH_READ <VOID*>(addr);
	}

}