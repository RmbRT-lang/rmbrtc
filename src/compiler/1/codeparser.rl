INCLUDE "../../scoper/scope.rl"
INCLUDE "../../parser/parser.rl"
INCLUDE "../../parser/class.rl"
INCLUDE "../../parser/rawtype.rl"
INCLUDE "../../parser/enum.rl"
INCLUDE "../../parser/union.rl"
INCLUDE "../../parser/mask.rl"
INCLUDE "../../parser/function.rl"
INCLUDE "../../parser/field.rl"
INCLUDE "../../parser/symbolconstant.rl"
INCLUDE "../../parser/typedef.rl"
INCLUDE "../../parser/globalvariable.rl"
INCLUDE "../../parser/extern.rl"
INCLUDE "../../parser/ids.rl"

::rlc::compiler::stage1::parse {

	[T]PostParseQueue {
		Buckets: T[#]-std::Vec;
		EntryCount: U4;
		EntryAlloc: std::temp::Alloc-std::Alloc;

		init() VOID
		{
			Buckets.reserve(1024);
			EntryAlloc.Impl.{:custom(1*MI, 1*MI)};
		}

		delete() VOID
		{
			EntryAlloc.Impl.delete();
			Buckets.clear_delete();
		}

		// Add a new entry, return its ID.
		THIS += (v: T) U4 --
		{
			IF(EntryAlloc.Impl.try_grow_last_allocation_by(SIZEOF(T)))
			{
				bucket: T[#] & := Buckets[##Buckets-1];
				bucket[][##bucket] := v;
				++##bucket;
			} ELSE {
				obj ::= EntryAlloc.[T]alloc();
				Buckets += obj[FOR 1];
				obj->{v};
			}

			= ++EntryCount;
		}
	}

	Preparsed {
		Span: parser::TokenSpan;
		Ns: U2;
		Ms: U2;
	}
	PreparsedBody {
		Core: Preparsed;
		Args: parser::ArgsID;
	}

	PreparsedSpecialCtorBody {
		Core: Preparsed;
		ArgName: FileLocalIdentifier;
	}

	// The global rootscope. This is the only real output of the preparser.
	RootScope: scoper::Namespace;

	// Caches the file contents of all code files.
	FileTokens: tok::FileTokenView-std::Vec;


	Types:             Preparsed               -PostParseQueue;
	Arguments:         Preparsed               -PostParseQueue;
	Returns:           PreparsedBody           -PostParseQueue;

	Expressions:       Preparsed               -PostParseQueue;
	Bodies:            PreparsedBody           -PostParseQueue;
	SpecialCtorBodies: PreparsedSpecialCtorBody-PostParseQueue;

	Namespaces: scoper::Namespace * -std::Vec;
	MemberScopes: parser::Members * -std::Vec;

	init() VOID {
		RootScope.Entries.reserve(1<<16);
		FileTokens.reserve(2048);

		Types.init();
		Arguments.init();
		Returns.init();

		Expressions.init();
		Bodies.init();
		SpecialCtorBodies.init();

		Namespaces.reserve(2048);      Namespaces += NULL;
		MemberScopes.reserve(16 * KI); MemberScopes += NULL;
	}
}
::rlc::compiler::stage1::parse CodeParser
{
	Output { } // Currently, we have no per-job output. Instead, we have one output once all parsing of all files is complete.

	Input {
		Tokens: @(CACHELINE) tok::FileTokenView;
		LocalIds: U2;
		File: src::File;
	}

	LocalDeclLut: U2-std::Vec;
	LocalIds: U2;
	LocalDecls: U2;

	// We need this because we do not know how large the number of decl IDs is in a file before we finished parsing it. So we first allocate member lookup tables here.
	PessimisticMemberAlloc: std::temp::Alloc;
	// This could be removed, as we currently shrink the lookup tables down and then pad them out again to their final size during the post-pass. TODO: A/B performance testing.
	ShrunkMemberAlloc:      std::temp::Alloc;

	// Gets reset after every file.
	FileOuterMemberScopes: parser::Members \ -std::Vec; // we might also want to be registering other things here, such as a list of all functions, or all return types or something. And we might want to have a union type that we can patch in the post-pass, so that we do not need to move data around.

	{}: FileOuterMemberScopes := :reserve(2048),
		LocalDeclLut := :reserve(1<<16),
		PessimisticMemberAlloc := :custom(128*KI, 128*KI),
		ShrunkMemberAlloc := :custom(128*KI, 128*KI);

	STATIC name() CHAR#[#] -- := "code preparser";


	Ns: U2;
	Ms: U2;

	handle_job(in: Input &, out: Output *) VOID
	{
		// Remember tokens for later.
		IF!(in.File < ##FileTokens)
		{
			FileTokens.resize_bare(in.File+1);
		}
		ASSERT(##FileTokens > in.File);
		FileTokens[:ok(in.File)] := in.Tokens; // copy, let the toker reuse the buffer.

		// Global/Local ID buffers
		LocalIds := in.LocalIds;
		LocalDecls := 0;
		LocalDeclLut.clear_reuse();
		LocalDeclLut.resize(in.LocalIds);

		member_scopes_start ::= ##MemberScopes;

		// 2. pre-parse global scope entries into the global scope tree. Populate global scope lookups. Function bodies, expressions, and type names are skipped via matching parentheses.
		p: rlc::parser::Parser(FileTokens[:ok(in.File)], in.File);
		WHILE(!p.eof())
			preparse_ns_entry(p, &RootScope, NULL);

		// 3. Post-process the member scopes in the file, giving them the ##LocalDeclIds capacity for their LUTs (i.e., no bounds checks needed), and create scope-relative lookup tables.
		ids ::= LocalDecls;
		FOR(MemberScopes![FROM member_scopes_start]) finalise_members(IT);
		FOR(FileOuterMemberScopes!) IT->post_process(NULL, NULL, ids);
		FileOuterMemberScopes.clear_reuse();

		ShrunkMemberAlloc.clear_and_optimise(4*KI);
		PessimisticMemberAlloc.clear_and_optimise(4*KI);
	}

	PRIVATE span_impl(start: U4, p: parser::Parser &) Preparsed --
		:= ((p.File, start, p.progress()), Ns, Ms);
	todo_token_span(start: U4, p: parser::Parser &) parser::TokenSpan --
		:= (p.File, start, p.progress());
	type_token_span(start: U4, p: parser::Parser &) parser::TypeID --
		:= Types += span_impl(start, p);
	expression_token_span(start: U4, p: parser::Parser &) parser::ExpressionID --
		:= Expressions += span_impl(start, p);
	return_token_span(start: U4, p: parser::Parser &, args: parser::ArgsID) parser::RestID --
		:= Returns += (span_impl(start, p), args);
	body_token_span(start: U4, p: parser::Parser &, args: parser::ArgsID) parser::BodyID --
		:= Bodies += (span_impl(start, p), args);
	special_ctor_body_token_span(start: U4, p: parser::Parser &, argName: FileLocalIdentifier) parser::SpecialCtorBodyID --
		:= SpecialCtorBodies += (span_impl(start, p), argName);
	args_token_span(start: U4, p: parser::Parser &) parser::ArgsID --
		:= Arguments += span_impl(start, p);

	// TODO: see how we want to actually access the tests again later on. Based on that, we want to redo this structure, probably.
	PreparsedTests {
		Entry {
			{BARE};

			scope: scoper::Namespace \;
			name_str: tok::TokenStringPayload;
			span: parser::TokenSpan;
			Next: Entry *; // Entries are allocated in a bump allocator, but we cannot guarantee continuity, so we have a linked list.
		}

		TestList {
			First: Entry *;
			Last:  Entry *;
		}

		Alloc: std::temp::Alloc - std::Alloc;
		Tests: TestList;

		{}: Alloc := :custom(64*KI, 64*KI);

		register_test(scope: scoper::Namespace \, span: parser::TokenSpan, name: tok::TokenStringPayload) VOID
		{
			e ::= Alloc.[Entry]alloc();
			e->scope := scope;
			e->name_str := name;
			e->span := span;
			e->Next := NULL;
			IF!(Tests.Last)
				Tests.First := e;
			ELSE
				Tests.Last->Next := e;
			Tests.Last := e;
		}
	}
	preparsedTests: PreparsedTests;

	preparse_ns_entry(
		p: parser::Parser &,
		scope: scoper::Namespace \,
		template: parser::TokenSpan) VOID
	{
		old_ns ::= Ns;
		Ns := scope->Id;

		// Namespace entries use the global identifier IDs. Never register a local ID in a namespace.
		// All other scopes use file-local IDs for members, allowing for smaller LUTs and better cache coherence.

		TRY SWITCH(p.type())
		{
		:Identifier:
		{
			at ::= p.progress();  name ::= p.stype().Identifier;  p.next();

			global_decl_name ::= global_to_decl_name(name);

			entry ::= scope->ensure(global_decl_name);
			start ::= p.progress();

			SWITCH(p.type())
			{
			:Punctuation:
				SWITCH(p.stype().Punctuation)
				{
				:parentheseOpen: {
					out ::= mempool::[parser::Function]alloc_unhashed_t();
					preparse_function(p, out.(0), name, template);
					entry->set_value(:Function(out.(1)), name, at, p);
				}
				:braceOpen: {
					out ::= mempool::[parser::Class]alloc_unhashed_t();
					preparse_class(p, out.(0), name, template);
					entry->set_nonvalue(:Class(out.(1)), name, at, p);
				}
				:colon: {
					IF(template)
						p.fail("Variables cannot be templated");

					out ::= mempool::[parser::GlobalVariable]alloc_unhashed_t();
					preparse_global_variable(p, out.(0), name);
					entry->set_value(:Variable(out.(1)), name, at, p);
				}
				}
			:Declaration:
				SWITCH(kw ::= p.stype().Declaration)
				{
				:virtual, :abstract, :final:
				{
					out ::= mempool::[parser::Class]alloc_unhashed_t();
					preparse_class(p, out.(0), name, template);
					entry->set_nonvalue(:Class(out.(1)), name, at, p);
				}
				}
			:BinaryOp:
				SWITCH(p.stype().BinaryOp)
				{
				:minusGreater:
				{
					out ::= mempool::[parser::Class]alloc_unhashed_t();
					preparse_class(p, out.(0), name, template);
					entry->set_nonvalue(:Class(out.(1)), name, at, p);
				}
				}
			}
		}
		:Punctuation:
			SWITCH(p.stype().Punctuation)
			{
			:doubleColon:
			{
				IF(template)
					p.fail("Namespaces cannot have templates");

				p.next();
				name ::= p.expect_p(:Identifier).Identifier;
				global_decl_name ::= global_to_decl_name(name);
				entry ::= scope->ensure(global_decl_name);
				pentry ::= &entry->NonValue;

				child_ns: scoper::Namespace *;// (NOINIT);

				IF(pentry->Type == :Namespace)
				{
					// Merge / reuse existing namespace.
					child_ns := pentry->Mem.Namespace.get();
				} ELSE IF(pentry->Type == :Nil)
				{
					// Nil: insert new namespace.
					ns_entry ::= mempool::[scoper::Namespace]alloc_unhashed_t();
					child_ns := ns_entry.(0);
					child_ns->{};
					child_ns->Id := ##Namespaces; Namespaces += child_ns;
					pentry->Type := :Namespace;
					pentry->Mem := :Namespace(ns_entry.(1));
					scope->Namespaces += (global_decl_name.V, ns_entry.(1));
				} ELSE
				{
					p.fail("Symbol ", ident::strings[name.V] ," redefined as namespace, was ", std::str::enum(pentry->Type));
				}

				IF(p.consume_s(:Punctuation(:braceOpen)))
				{
					WHILE(!p.consume_s(:Punctuation(:braceClose)))
						preparse_ns_entry(p, child_ns, NULL);
				} ELSE preparse_ns_entry(p, child_ns, NULL);
			}
			:parentheseOpen: {
				at ::= p.progress();
				out ::= mempool::[parser::Rawtype]alloc_unhashed_t();
				preparse_rawtype(p, out.(0), template);
				name ::= out.(0)->Name;
				global_decl_name ::= global_to_decl_name(name);
				entry ::= scope->ensure(global_decl_name);
				entry->set_nonvalue(:Rawtype(out.(1)), name, at, p);
			}
			:bracketOpen: {
				IF(template)
					p.fail("already had a template declaration");
				start ::= p.progress();
				p.skip_nesting();
				tpl ::= todo_token_span(start, p);
				IF(##tpl == 2) tpl := NULL;
				preparse_ns_entry(p, scope, tpl);
			}
			}
		:Declaration:
		{
			at ::= p.progress();
			decl ::= p.stype().Declaration;
			start ::= p.progress();
			p.next();
			SWITCH(decl)
			{
			:enum: {
				IF(template)
					p.fail("Enums cannot be templated");

				name ::= p.expect_p(:Identifier).Identifier;
				global_decl_name ::= global_to_decl_name(name);
				entry ::= scope->ensure(global_decl_name);
				out ::= mempool::[parser::Enum]alloc_unhashed_t();
				entry->set_nonvalue(:Enum(out.(1)), name, at, p);
				preparse_enum(p, out.(0), name);
			}
			:extern: {
				IF(template)
					p.fail("External symbols cannot be templated");


				linkname: Identifier (0);
				IF(p.consume_s(:Punctuation(:bracketOpen)))
				{
					linkname := p.expect_p(:Identifier).Identifier;
					p.expect_s(:Punctuation(:bracketClose));
				}


				start := p.progress();
				name ::= p.expect_p(:Identifier).Identifier;
				global_decl_name ::= global_to_decl_name(name);
				entry ::= scope->ensure(global_decl_name);
				punct ::= p.stype().Punctuation;
				expect ::= tok::Punctuation::FLAGS(:colon, :parentheseOpen);
				IF!(expect >> <U1>(punct) & (p.type() == :Punctuation))
					p.fail("expected ':' or '('");

				IF(punct == :colon)
				{
					p.next();
					out ::= mempool::[parser::ExternVariable]alloc_unhashed_t();
					out.(0)->Name := name;
					type_start ::= p.progress();
					p.skip_nesting_until(:semicolon);
					type ::= type_token_span(type_start, p);
					out.(0)->Type.Preparse := type;
					entry->set_value(:ExternVariable(out.(1)), name, at, p);
				} ELSE
				{
					out ::= mempool::[parser::ExternFunction]alloc_unhashed_t();
					out.(0)->Name := name;
					p.expect_s(:Punctuation(:parentheseOpen));
					args_start ::= p.progress();
					p.skip_until_nesting_ends();
					args ::= args_token_span(args_start, p);
					p.expect_s(:Punctuation(:parentheseClose));
					out.(0)->Args := args;

					type_start ::= p.progress();
					p.skip_nesting_until(:semicolon);
					rest ::= return_token_span(type_start, p, args);
					out.(0)->Rest.Preparse := rest;

					entry->set_value(:ExternFunction(out.(1)), name, at, p);
				}
				p.next(); // ;
			}
			:export: {
				IF(template)
					p.fail("Exported symbols cannot be templated");

				link_name: rlc::Identifier;
				IF(p.consume_s(:Punctuation(:bracketOpen)))
				{
					link_name := p.expect_p(:Identifier).Identifier;
					p.expect_s(:Punctuation(:bracketClose));
				}

				start := p.progress();
				name ::= p.expect_p(:Identifier).Identifier;
				global_decl_name ::= global_to_decl_name(name);
				entry ::= scope->ensure(global_decl_name);
				punct ::= p.stype().Punctuation;
				IF(p.type() != :Punctuation)
					p.fail();

				SWITCH(punct)
				{
				:colon: {
					out ::= mempool::[parser::ExportVariable]alloc_unhashed_t();
					out.(0)->LinkName := link_name;

					preparse_global_variable(p, &out.(0)->Var, name);
					entry->set_value(:ExportVariable(out.(1)), name, at, p);
				}
				:parentheseOpen: {
					out ::= mempool::[parser::ExportFunction]alloc_unhashed_t();
					out.(0)->LinkName := link_name;

					preparse_function(p, &out.(0)->Fn, name, template);
					entry->set_value(:ExportFunction(out.(1)), name, at, p);
				}
				DEFAULT: p.fail("expected ':' or '('");
				}
			}
			:mask: {
				name ::= p.expect_p(:Identifier).Identifier;
				out ::= mempool::[parser::Mask]alloc_unhashed_t();
				global_decl_name ::= global_to_decl_name(name);
				entry ::= scope->ensure(global_decl_name);
				out.(0)->Name := name;
				preparse_mask(p, out.(0), name);
				entry->set_nonvalue(:Mask(out.(1)), name, at, p);
			}
			:test: {
				IF(template)
					p.fail("Tests cannot be templated");
				name ::= p.expect_s(:String(:StringQuote)).String;
				p.skip_braces();
				preparsedTests.register_test(scope, todo_token_span(start, p), name);
			}
			:union: {
				name ::= p.expect_p(:Identifier).Identifier;
				global_decl_name ::= global_to_decl_name(name);
				entry ::= scope->ensure(global_decl_name);
				out ::= mempool::[parser::Union]alloc_unhashed_t();
				preparse_union(p, out.(0), name, template);
				entry->set_nonvalue(:Union(out.(1)), name, at, p);
			}
			}
		}
		:AuxKeyword:
			SWITCH(p.stype().AuxKeyword)
			{
			:type: {
				at ::= p.progress(); p.next();
				name ::= p.expect_p(:Identifier).Identifier;

				global_decl_name ::= global_to_decl_name(name);
				entry ::= scope->ensure(global_decl_name);
				out ::= mempool::[parser::Typedef]alloc_unhashed_t();
				preparse_typedef(p, out.(0), name, template);
				entry->set_nonvalue(:Typedef(out.(1)), name, at, p);
			}
			}
		} CATCH(err: CHAR #*) {
			p.fail("expected namespace entry: ", std::str::c(err[]));
		}

		Ns := old_ns;
	}

	preparse2() VOID
	{
		RootScope.post_process_1(NULL, NULL);
		RootScope.post_process_2();


		// 3. fully parse everything, immediately resolving all things to their proper scope entries. -- actually, this does not happen yet. We want a separate stage for this, after we have the fully populated global scope.

		// We only parse those things that have internal scopes and define things inside that get looked up from the outside.

		RETURN; // it makes no sense to not parse these things when they first appear, I think.

		// 4. instantiate, type check, code gen, etc.
	}

	consume_vmode(p: parser::Parser &) parser::Class::DeclMode -- {
		mode: parser::Class::DeclMode := :normal;

		match ::= p.type() == :Declaration;
		decl ::= p.stype().Declaration;
		mask ::= tok::DeclarationKeyword::FLAGS(:abstract, :final, :virtual);

		p.next_if(match);

		// = 1 + index of the bit in the sequence.
		mode := >POPCNT (  MASK(match) & (mask & (2 << <U1>(decl) -1))  );

		= mode;
	}

	extract_abstractness(p: parser::Parser &) parser::Abstractness {
		mask ::= tok::DeclarationKeyword::FLAGS(:abstract, :final, :override, :virtual);
		decl ::= p.stype().Declaration;
		p.next();

		= >POPCNT (  mask & (2 << <U1>(decl) -1)  );
	}

	parser_from_span(span: parser::TokenSpan#&) parser::Parser --
		:= (FileTokens[span.File], span.File);

	ENUM Members {
		Constructors,
		Fields,
		Functions,
		Types
	}

	// Call when starting to parse a member scope.
	alloc_members(
		m: parser::Members \,
		ops: parser::Operators *,
		ctors: parser::Constructors *,
		needs_inner_lut: BOOL) std::temp::Alloc::Checkpoint
	{
		m->Id := ##MemberScopes; MemberScopes += m;

		s ::= PessimisticMemberAlloc.save();
		max_cap ::= LocalIds;
		m->IdLut := PessimisticMemberAlloc.[parser::Members::LUTEntry-Handle]alloc_raw_array(max_cap)[FOR 0];
		m->Entries := PessimisticMemberAlloc.[{U2, parser::Members::LUTEntry-Handle}]alloc_raw_array(max_cap)[FOR 0];

		m->InnerLutV := NULL;
		m->InnerLutNV := NULL;

		IF(!IsInMember && needs_inner_lut)
			FileOuterMemberScopes += m;

		IF(ops)
		{
			ops->{};
			ops->Binary.Ops :=
				PessimisticMemberAlloc.[parser::PreparsedBinaryOperator]alloc_raw_array(
					###parser::BinaryOperator);
			ops->Prefix.Ops :=
				PessimisticMemberAlloc.[parser::PreparsedPrefixOperator]alloc_raw_array(
					###parser::PrefixOperator);
			ops->Postfix.Ops :=
				PessimisticMemberAlloc.[parser::PreparsedPostfixOperator]alloc_raw_array(
					###parser::PostfixOperator);
		}

		IF(ctors)
		{
			ctors->{};
			ctors->NamedCtors := PessimisticMemberAlloc.[parser::CustomCtor-Handle]alloc_raw_array(max_cap)[FOR 0];
			ctors->NamedCtorEntries := PessimisticMemberAlloc.[{FileDeclIdentifier, parser::CustomCtor-Handle}]alloc_raw_array(max_cap)[FOR 0];
		}
		= s;
	}

	// Call this after parsing the member scope.
	shrink_members(
		m: parser::Members \,
		ops: parser::Operators *,
		ctors: parser::Constructors *,
		s: std::temp::Alloc::Checkpoint #&) VOID
	{
		// We can move these directly into the mempool.
		m->Entries := mempool::insert_unhashed_array(m->Entries).(0);

		// We do not yet know the final maximum capacity for members.
		idlut ::= ShrunkMemberAlloc.[parser::Members::LUTEntry-Handle]alloc_raw_array(##m->IdLut);
		FOR(m->IdLut) idlut[][IOTA].{ IT }; // FOR(idlut, m->IdLut) LHS.{ RHS };
		m->IdLut := idlut;

		IF(ops)
		{
			pre ::= mempool::[parser::PreparsedPrefixOperator]alloc_unhashed_array(##ops->Prefix).(0);
			post ::= mempool::[parser::PreparsedPostfixOperator]alloc_unhashed_array(##ops->Postfix).(0);
			bin ::= mempool::[parser::PreparsedBinaryOperator]alloc_unhashed_array(##ops->Binary).(0);

			{
				v ::= &ops->Prefix; arr ::= pre;

				count ::= ##*v;
				flags ::= v->Present;
				FOR(i ::= 0; i < count; i++)
				{
					op ::= FIRST1POS flags;
					flags ^= 1<<op;
					arr[i] := v->Ops[op];
				}
				v->Ops := arr;
			}

			{
				v ::= &ops->Postfix; arr ::= post;

				count ::= ##*v;
				flags ::= v->Present;
				FOR(i ::= 0; i < count; i++)
				{
					op ::= FIRST1POS flags;
					flags ^= 1<<op;
					arr[i] := v->Ops[op];
				}
				v->Ops := arr;
			}

			{
				v ::= &ops->Binary; arr ::= bin;

				count ::= ##*v;
				flags ::= v->Present;
				FOR(i ::= 0; i < count; i++)
				{
					op ::= FIRST1POS flags;
					flags ^= 1<<op;
					arr[i] := v->Ops[op];
				}
				v->Ops := arr;
			}
		}

		IF(ctors)
		{
			// We can move these directly into the mempool.
			ctors->NamedCtorEntries := mempool::insert_unhashed_array(ctors->NamedCtorEntries).(0);

			// We do not yet know the final maximum capacity for members.
			idlut ::= ShrunkMemberAlloc.[parser::Members::LUTEntry-Handle]alloc_raw_array(##m->IdLut);
			FOR(m->IdLut) idlut[][IOTA].{ IT }; // FOR(idlut, m->IdLut) LHS.{ RHS };
			m->IdLut := idlut;
		}

		PessimisticMemberAlloc.restore(s);
	}

	// Call this when a file is fully parsed.
	finalise_members(m: parser::Members \) VOID
	{
		new ::= mempool::[parser::Members::LUTEntry-Handle]alloc_unhashed_array(
			LocalDecls).(0);

		FOR(m->IdLut) new[IOTA].{ IT };
		FOR(new[FROM ##m->IdLut]) IT.{ };

		m->IdLut := new;
	}

	preparse_class(
		p: parser::Parser &,
		out: parser::Class \,
		name: Identifier,
		template: parser::TokenSpan) VOID
	{
		out->Name := name;
		out->File := p.File;
		out->Templates := template;
		out->Decl := consume_vmode(p);

		save ::= alloc_members(&out->Members, &out->Ops, &out->Ctors, TRUE);

		// Inheritance.
		inheritance: parser::TokenSpan;
		IF(p.consume_s(:BinaryOp(:minusGreater)))
		{
			inh_start ::= p.progress();
			p.skip_nesting_until(:braceOpen, :semicolon);
			inheritance := todo_token_span(inh_start, p);
		}

		out->Inheritance := inheritance;

		IF(p.consume_s(:Punctuation(:semicolon)))
			RETURN;

		p.expect_s(:Punctuation(:braceOpen));

		vis: rlc::Visibility := :public;
		WHILE(!p.consume_s(:Punctuation(:braceClose)))
			preparse_member(p, &out->Members, &out->Ctors, &out->Ops, NULL, :none, &vis, FALSE,
				Members::FLAGS(:Constructors, :Fields, :Functions, :Types));

		shrink_members(&out->Members, &out->Ops, &out->Ctors, save);
	}

	preparse_rawtype(
		p: parser::Parser &,
		out: parser::Rawtype \,
		template: parser::TokenSpan #&) FileLocalIdentifier
	{
		out->Templates := template;
		out->File := p.File;

		p.expect_s(:Punctuation(:parentheseOpen));
		start ::= p.progress();
		cls ::= p.skip_until_nesting_ends_or(:comma);
		out->Size := expression_token_span(start, p);
		p.next();
		IF(cls == :comma)
		{
			start := p.progress();
			p.skip_until_nesting_ends();
			out->Alignment := expression_token_span(start, p);
			p.expect_s(:Punctuation(:parentheseClose));
		}

		local_name ::= p.payload().Identifier.FileLocal;
		out->Name := p.expect_p(:Identifier).Identifier;

		IF(p.consume_s(:Punctuation(:semicolon)))
			RETURN local_name;

		p.expect_s(:Punctuation(:braceOpen));

		save ::= alloc_members(&out->Members, &out->Ops, &out->Ctors, TRUE);

		vis: Visibility := :public;
		WHILE(!p.consume_s(:Punctuation(:braceClose)))
			preparse_member(p, &out->Members, &out->Ctors, &out->Ops, NULL, :none, &vis, FALSE,
				Members::FLAGS(:Constructors, :Functions, :Types));

		shrink_members(&out->Members, &out->Ops, &out->Ctors, save);

		= local_name;
	}

	preparse_enum(p: parser::Parser &, out: parser::Enum \, name: Identifier) VOID
	{
		p.expect_s(:Punctuation(:braceOpen));

		IF(p.consume_s(:Punctuation(:braceClose)))
			RETURN;

		out->Name := name;
		out->File := p.File;
		out->DefaultField := -1;
		out->TruthyFields := 0;

		save ::= alloc_members(&out->Members, NULL, NULL, FALSE);

		DO(entry_val ::= 0)
		{
			at ::= p.progress();

			IF(out->TruthyFields && entry_val >= 64)
				p.fail("An enum with '?'-tagged fields must not have more than 64 entries");

			IF(p.consume_s(:PrefixOrBinaryOp(:asterisk)))
			{
				IF(out->DefaultField != -1)
					p.fail_before("Only one field can be tagged '*'");
				out->DefaultField := entry_val;
			}

			IF(p.consume_s(:PostfixOp(:questionMark)))
				out->TruthyFields |= 1 << entry_val;

			local_id ::= p.payload_expect_p(:Identifier).Identifier.FileLocal;
			dedup_id ::= local_to_decl_name(local_id);

			main_entry ::= &out->Members.ensure(dedup_id)->Value;
			IF(main_entry->Type)
				p.fail_pos(at, "duplicate enum constant");
			main_entry->Type := :EnumConstant;
			main_entry->Visibility := :public;
			main_entry->Entry := :EnumConstant(entry_val, dedup_id);

			WHILE(p.consume_s(:Punctuation(:colonEqual)))
			{
				at ::= p.progress();
				alias_local_id ::= p.payload_expect_p(:Identifier).Identifier.FileLocal;
				dedup_alias_id ::= local_to_decl_name(alias_local_id);

				alias_entry ::= &out->Members.ensure(dedup_alias_id)->Value;
				IF(alias_entry->Type)
					p.fail_pos(at, "duplicate enum constant");
				alias_entry->Type := :EnumConstant;
				alias_entry->Visibility := :public;
				alias_entry->Entry := :EnumConstant(entry_val, dedup_alias_id);
			}
		} FOR(p.consume_s(:Punctuation(:comma)); ++entry_val)

		p.expect_s(:Punctuation(:braceClose));

		shrink_members(&out->Members, NULL, NULL, save);
	}

	preparse_union(
		p: parser::Parser &,
		out: parser::Union \,
		name: Identifier,
		template: parser::TokenSpan) VOID
	{
		out->Name := name;
		out->File := p.File;
		out->Templates := template;
		out->DefaultField := -1;
		out->ValueOfField := -1;
		out->TruthyFields := 0;

		save ::= alloc_members(&out->Members, NULL, NULL, FALSE);

		p.expect_s(:Punctuation(:braceOpen));

		FOR(field_idx ::= 0; !p.match_s(0, :Punctuation(:braceClose)); field_idx++)
		{
			at ::= p.progress();
			IF(p.consume_s(:PrefixOrBinaryOp(:asterisk)))
			{
				IF(out->DefaultField != -1)
					p.fail_before("Only one field can be tagged '*'");
				out->DefaultField := field_idx;
			}

			IF(p.consume_s(:PrefixOrPostfixOp(:exclamationMark)))
			{
				IF(out->ValueOfField != -1)
					p.fail_before("Only one field can be tagged '!'");
				out->ValueOfField := field_idx;
			}

			IF(p.consume_s(:PostfixOp(:questionMark)))
				out->TruthyFields |= 1 << field_idx;

			local_name ::= p.payload().Identifier.FileLocal;
			name ::= p.expect_p(:Identifier).Identifier;
			IF(p.consume_s(:Punctuation(:semicolon)))
				CONTINUE;

			p.expect_s(:Punctuation(:colon));
			type_entry ::= mempool::[parser::UnionField]alloc_unhashed_t();
			type_start ::= p.progress();
			p.skip_nesting_until(:semicolon);
			*type_entry.(0) := :Preparse(type_token_span(type_start, p));
			p.expect_s(:Punctuation(:semicolon));

			decl_name ::= local_to_decl_name(local_name);

			entry ::= out->Members.ensure(decl_name);
			entry->set_value(name, at, p, (:public, :UnionField(type_entry.(1))));
		}
		p.expect_s(:Punctuation(:braceClose));

		shrink_members(&out->Members, NULL, NULL, save);
	}

	preparse_mask(p: parser::Parser &, out: parser::Mask \, name: Identifier) VOID
	{
		out->Name := name;
		out->File := p.File;

		p.expect_s(:Punctuation(:braceOpen));

		save ::= alloc_members(&out->Members, &out->Ops, NULL, FALSE);
		vis: Visibility := :public;
		WHILE(!p.consume_s(:Punctuation(:braceClose)))
			preparse_member(p, &out->Members, NULL, &out->Ops, NULL, :none, &vis, FALSE,
				Members::FLAGS(:Functions));
		shrink_members(&out->Members, &out->Ops, NULL, save);
	}

	preparse_function(
		p: parser::Parser &,
		out: parser::Function \,
		name: Identifier,
		template: parser::TokenSpan #&) VOID --
	{
		args ::= preparse_function_internal(p, out, name, template);
		(out->BodyType, out->Body) := skip_function_body(p, args);
	}

	preparse_function_internal(
		p: parser::Parser &,
		out: parser::Function \,
		name: Identifier,
		template: parser::TokenSpan #&) parser::ArgsID
	{
		out->Name := name;
		out->File := p.File;
		out->Templates := :Preparse(template);

		p.expect_s(:Punctuation(:parentheseOpen));
		args_start ::= p.progress();
		p.skip_until_nesting_ends();
		args ::= args_token_span(args_start, p);
		p.expect_s(:Punctuation(:parentheseClose));
		out->Args := :Preparse(args);

		out->Return.Preparse := skip_function_return_type(p, args);

		= args;
	}

	preparse_symbolic_constant(p: parser::Parser &, delim: tok::Punctuation) parser::DefinitionSymbolConstant
	{
		ret: parser::DefinitionSymbolConstant (NOINIT);

		p.expect_s(:Punctuation(:colon));
		IF[name](pl ::= p.payload_consume_p(:Identifier))
		{
			ret.Name := :Identifier(local_to_decl_name(pl->Identifier.FileLocal));
		} ELSE
		{
			STATIC specials: {TAGGED tok::Type, parser::SpecialName}#[?](
				(:BinaryOp(:less), :less),
				(:BinaryOp(:lessGreater), :lessGreater),
				(:BinaryOp(:greater), :greater),
				(:PrefixOrPostfixOp(:exclamationMark), :exclamationMark),
				(:PostfixOp(:questionMark), :questionMark));
			FOR(specials)
				IF(p.consume_s(IT.(0)))
				{
					ret.Name := :Special(IT.(1));
					BREAK [name];
				}

			p.fail("Expected symbolic constant name");
		}

		IF(p.consume_s(:BinaryOp(:dot)))
		{
			tpl_start ::= p.progress();
			p.skip_nesting_until(delim);
			ret.Template := todo_token_span(tpl_start, p);
		} ELSE
		{
			ret.Template := NULL;
			IF!(p.match_s(0, :Punctuation(delim)))
				p.fail("Expected punctuation: ", std::str::enum(delim));
		}

		= ret;
	}

	preparse_global_variable(p: parser::Parser &, out: parser::GlobalVariable \, name: Identifier) VOID
	{
		out->Name := name;
		p.expect_s(:Punctuation(:colon));

		alignment: parser::ExpressionID;
		IF(p.consume_s(:Punctuation(:at)))
		{
			p.expect_s(:Punctuation(:parentheseOpen));
			align_start ::= p.progress();
			p.skip_until_nesting_ends();
			alignment := expression_token_span(align_start, p);
			p.expect_s(:Punctuation(:parentheseClose));
		}
		out->Alignment := alignment;

		type_start ::= p.progress();
		// If the type is a function pointer.
		IF(p.match_s(0, :Punctuation(:parentheseOpen)))
			p.skip_nesting(); // Skip the function signature.

		after_type ::= p.skip_nesting_until(:colonEqual, :parentheseOpen, :semicolon);
		out->Type.Preparse := type_token_span(type_start, p);

		p.next_if(after_type == :colonEqual);

		v_start ::= p.progress();
		p.skip_nesting_until(:semicolon);
		out->Initialiser := expression_token_span(v_start, p);

		p.expect_s(:Punctuation(:semicolon));
	}

	preparse_typedef(
		p: parser::Parser &,
		out: parser::Typedef \,
		name: Identifier,
		template: parser::TokenSpan) VOID
	{
		p.expect_s(:Punctuation(:colonEqual));

		type_start ::= p.progress();
		p.skip_nesting_until(:semicolon);
		type ::= type_token_span(type_start, p);

		p.next();

		out->Type := :Preparse(type);
		out->Name := name;
		out->Templates := template;
		out->File := p.File;
	}

	ENUM PreparsedMember {
		Function,
		StaticFunction,
		Field,
		Class,
		Rawtype,
		Union,
		Typedef,
		Enum,
		Constructor,
		Destructor
	}

	global_to_decl_name(name_global: rlc::Identifier) rlc::GlobalDeclIdentifier --
	{
		count: U2 := ident::GlobalDeclCount;
		dedup_id: U2 * := &ident::GlobalDeclsLut[name_global.V];
		old ::= *dedup_id;
		fresh ::= old == 0;
		new ::= fresh ?? count : old;
		count += fresh;
		*dedup_id := new;
		ident::GlobalDeclCount := count;
		= new;
	}

	local_to_decl_name(name_local: rlc::FileLocalIdentifier) rlc::FileDeclIdentifier --
	{
		decl_count: U2 * := &LocalDecls;
		dedup_id: U2 * := &LocalDeclLut[:ok(name_local.V)];
		old ::= *dedup_id;
		count ::= *decl_count;
		fresh ::= old == 0;
		new ::= fresh ?? count : old;
		count += fresh;
		*decl_count := count;
		*dedup_id := new;
		= new;
	}

	IsInMember: U4;

	preparse_member(
		p: parser::Parser &,
		scope: parser::Members \ #,
		ctors: parser::Constructors \ #,
		ops: parser::Operators * #,
		template: parser::TokenSpan,
		attr: parser::ParsedMemberAttr,
		vis: Visibility \,
		novis: BOOL, // visibility modifiers forbidden?
		allowed: U4) VOID
	{
		// member classes, functions, fields, ctors, etc.. Only register them by name (except for member classes etc., which also declare public fields. They also should be parsed. But no function bodies or anything. Also do not parse the types of variables.

		++IsInMember;
		old_ms ::= Ms;
		Ms := scope->Id;

		TRY SWITCH(p.type())
		{
		:Identifier: {
			at ::= p.progress();
			name ::= p.stype().Identifier;
			name_local ::= p.payload().Identifier.FileLocal;
			name_local_decl ::= local_to_decl_name(name_local);

			p.next();

			entry ::= scope->ensure(name_local_decl);
			start ::= p.progress();

			SWITCH(p.type())
			{
			:Punctuation:
				SWITCH(p.stype().Punctuation)
				{
				:parentheseOpen: {
					fn: parser::Function *;// (NOINIT);
					IF(attr == :static)
					{
						sfn ::= mempool::[parser::Function]alloc_unhashed_t();
						fn := sfn.(0);

						entry->set_value(name, at, p, (*vis, :StaticMemberFunction(sfn.(1))));
					} ELSE
					{
						mfn ::= mempool::[parser::MemberFunction]alloc_unhashed_t();
						fn := &mfn.(0)->Fn;
						mfn.(0)->Abstractness := :none;

						entry->set_value(name, at, p, (*vis, :MemberFunction(mfn.(1))));
					}
					preparse_function(p, fn, name, template);
				}
				:braceOpen: {
					IF(attr) p.fail_pos(at, "must not have an attribute");

					class ::= mempool::[parser::Class]alloc_unhashed_t();
					entry->set_nonvalue(name, at, p, (*vis, :Class(class.(1))));
					preparse_class(p, class.(0), name, template);
				}
				:colon: {
					IF(attr == :maybeIsolated) p.fail("must not have #? attribute");
					IF(template) p.fail("Variables cannot be templated");

					p.next();

					alignment: parser::ExpressionID;
					IF(p.consume_s(:Punctuation(:at)))
					{
						p.expect_s(:Punctuation(:parentheseOpen));
						align_start ::= p.progress();
						p.skip_until_nesting_ends();
						alignment := expression_token_span(align_start, p);
						p.expect_s(:Punctuation(:parentheseClose));
					}

					type_start ::= p.progress();
					IF(p.match_s(0, :Punctuation(:parentheseOpen)))
						p.skip_parentheses();
					p.skip_nesting_until(:parentheseOpen, :semicolon, :colonEqual);
					type_span ::= type_token_span(type_start, p);

					IF(attr == :static)
					{
						field ::= mempool::[parser::GlobalVariable]alloc_unhashed_t();
						field.(0)->Name := name;
						field.(0)->Alignment := alignment;
						field.(0)->Type := :Preparse(type_span);

						p.consume_s(:Punctuation(:colonEqual));
						start_init ::= p.progress();
						p.skip_nesting_until(:semicolon);
						field.(0)->Initialiser := expression_token_span(start_init, p);

						entry->set_value(name, at, p, (*vis, :StaticField(field.(1))));
					} ELSE
					{
						field ::= mempool::[parser::Field]alloc_unhashed_t();
						field.(0)->Name := name;
						field.(0)->Location := p.at_pos(at);
						field.(0)->Alignment := alignment;
						field.(0)->Isolated := attr == :isolated;
						field.(0)->Index := scope->Fields++;
						field.(0)->Type := :Preparse(type_span);

						entry->set_value(name, at, p, (*vis, :Field(field.(1))));
					}

					p.expect_s(:Punctuation(:semicolon));
				}
				:semicolon: // Name; fields.
				{
					IF(attr == :maybeIsolated) p.fail("must not have #? attribute");
					IF(template) p.fail("Variables cannot be templated");

					type_span ::= type_token_span(at, p);

					IF(attr == :static)
					{
						field ::= mempool::[parser::GlobalVariable]alloc_unhashed_t();
						field.(0)->Name := name;
						field.(0)->Alignment := NULL;
						field.(0)->Type := :Preparse(type_span);

						field.(0)->Initialiser := NULL;

						entry->set_value(name, at, p, (*vis, :StaticField(field.(1))));
					} ELSE
					{
						field ::= mempool::[parser::Field]alloc_unhashed_t();
						field.(0)->Name := name;
						field.(0)->Location := p.at_pos(at);
						field.(0)->Alignment := NULL;
						field.(0)->Isolated := attr == :isolated;
						field.(0)->Index := scope->Fields++;
						field.(0)->Type := :Preparse(type_span);

						entry->set_value(name, at, p, (*vis, :Field(field.(1))));
					}

					p.expect_s(:Punctuation(:semicolon));
				}
				}
			:Declaration:
				SWITCH(kw ::= p.stype().Declaration)
				{
				:virtual, :abstract, :final:
				{
					IF(attr) p.fail("must not have an attribute");

					class ::= mempool::[parser::Class]alloc_unhashed_t();
					entry->set_nonvalue(name, at, p, (*vis, :Class(class.(1))));
					preparse_class(p, class.(0), name, template);
				}
				}
			:BinaryOp:
				SWITCH(p.stype().BinaryOp)
				{
				:minusGreater:
				{
					IF(attr) p.fail("must not have an attribute");

					class ::= mempool::[parser::Class]alloc_unhashed_t();
					entry->set_nonvalue(name, at, p, (*vis, :Class(class.(1))));
					preparse_class(p, class.(0), name, template);
				}
				}
			}
		}
		:Punctuation:
			SWITCH(p.stype().Punctuation)
			{
			:parentheseOpen: {
				IF(attr) p.fail("must not have an attribute");

				at ::= p.progress();

				rawtype ::= mempool::[parser::Rawtype]alloc_unhashed_t();
				lname ::= preparse_rawtype(p, rawtype.(0), template);
				gname ::= rawtype.(0)->Name;
				entry ::= scope->ensure(local_to_decl_name(lname));
				entry->set_nonvalue(gname, at, p, (*vis, :Rawtype(rawtype.(1))));
			}
			:bracketOpen: {
				IF(template) p.fail("already had a template declaration");
				IF(attr) p.fail("templates must come before the attribute");

				start ::= p.progress();
				p.skip_nesting();
				tpl ::= todo_token_span(start, p);
				IF(##tpl == 2) tpl := NULL;
				preparse_member(p, scope, ctors, ops, tpl, attr, vis, novis, allowed);
			}
			:colon: { // :named{} ctor
				IF(attr) p.fail("must not have an attribute");

				at ::= p.progress();

				sym ::= preparse_symbolic_constant(p, :braceOpen);
				p.expect_s(:Punctuation(:braceOpen));
				args_start ::= p.progress();
				p.skip_until_nesting_ends();
				args ::= args_token_span(args_start, p);
				p.expect_s(:Punctuation(:braceClose));

				rest_start ::= p.progress();
				p.skip_nesting_until(:semicolon, :braceOpen);
				rest ::= todo_token_span(rest_start, p);

				body_start ::= p.progress();
				p.skip_nesting_until_after(:semicolon, :braceClose);
				body ::= body_token_span(body_start, p, args);

				ctors->register_named_ctor(sym, args, rest, template, at, p);
			}
			:braceOpen: { // {} ctor
				IF(attr) p.fail("must not have an attribute");

				at ::= p.progress(); p.next();

				special: parser::SpecialCtors (BARE);

				isCustom ::= FALSE;
				custom_args: parser::ArgsID;
				special_arg_name: FileLocalIdentifier;

				mask ::= tok::AuxKeyword::FLAGS(:bare, :null);
				kw ::= p.stype().AuxKeyword;
				IF(p.match_p(0, :AuxKeyword)
				&& mask & 1 << <U1>(kw))
				{
					p.next();
					// (.REF A): = index of the bit in the sequence.
					special := > POPCNT (mask & (1 << <U1>(kw) -1));
				} ELSE IF(p.consume_s(:Punctuation(:tripleDot)))
				{
					special := :Structure;
				} ELSE IF(p.consume_s(:PrefixOrBinaryOp(:doubleAmp)))
				{
					IF(v ::= p.payload_consume_p(:Identifier))
						special_arg_name := v->Identifier.FileLocal;
					special := :Move;
				} ELSE IF(p.consume_ss(:Punctuation(:hash), :PrefixOrBinaryOp(:amp)))
				{
					IF(v ::= p.payload_consume_p(:Identifier))
						special_arg_name := v->Identifier.FileLocal;
					special := :Copy;
				} ELSE IF(p.match_s(0, :Punctuation(:braceClose)))
				{
					special := :Default;
				} ELSE {
					args_start ::= p.progress();
					p.skip_nesting_until(:braceClose);
					custom_args := args_token_span(args_start, p);
					isCustom := TRUE;
				}

				IF(!isCustom && template)
					p.fail_pos(at, std::str::enum(special), " constructors cannot be templated");

				p.expect_s(:Punctuation(:braceClose));
				rest_start ::= p.progress();
				p.skip_nesting_until(:semicolon, :braceOpen);
				rest ::= todo_token_span(rest_start, p);

				body_start ::= p.progress();
				p.skip_nesting_until_after(:semicolon, :braceClose);
				IF(isCustom)
				{
					body ::= body_token_span(body_start, p, custom_args);
					ctors->register_custom_ctor(custom_args, rest, body, template, at, p);
				}
				ELSE
				{
					body ::= special_ctor_body_token_span(body_start, p, special_arg_name);
					ctors->register_special_ctor(special, rest, body, at, p);
				}
			}
			:hash: {
				IF(attr) p.fail();
				p.next();

				IF(p.consume_s(:PostfixOp(:questionMark)))
					attr := :maybeIsolated;
				ELSE
					attr := :isolated;

				preparse_member(p, scope, ctors, ops, template, attr, vis, novis, allowed);
			}
			}
		:Declaration:
		{
			at ::= p.progress();
			decl ::= p.stype().Declaration;
			start ::= p.progress();
			SWITCH(decl)
			{
			:enum: {
				IF(attr) p.fail("must not have an attribute");
				IF(template) p.fail("Enums cannot be templated");

				p.next();

				local_name ::= p.payload().Identifier.FileLocal;
				global_name ::= p.expect_p(:Identifier).Identifier;
				decl_name ::= local_to_decl_name(local_name);
				entry ::= scope->ensure(decl_name);
				def ::= mempool::[parser::Enum]alloc_unhashed_t();
				entry->set_nonvalue(global_name, at, p, (*vis, :Enum(def.(1))));
				preparse_enum(p, def.(0), global_name);
			}
			:mask: {
				IF(attr) p.fail("must not have an attribute");

				p.next();

				local_name ::= p.payload().Identifier.FileLocal;
				global_name ::= p.expect_p(:Identifier).Identifier;
				decl_name ::= local_to_decl_name(local_name);
				entry ::= scope->ensure(decl_name);
				def ::= mempool::[parser::Mask]alloc_unhashed_t();
				entry->set_nonvalue(global_name, at, p, (*vis, :Mask(def.(1))));
				preparse_mask(p, def.(0), global_name);
			}
			:union: {
				IF(attr) p.fail("must not have an attribute");

				p.next();

				local_name ::= p.payload().Identifier.FileLocal;
				global_name ::= p.expect_p(:Identifier).Identifier;
				decl_name ::= local_to_decl_name(local_name);
				entry ::= scope->ensure(decl_name);
				def ::= mempool::[parser::Union]alloc_unhashed_t();
				entry->set_nonvalue(global_name, at, p, (*vis, :Union(def.(1))));
				preparse_union(p, def.(0), global_name, template);
			}
			:destructor: {
				IF(template) p.fail("Destructors cannot be templated");
				IF(attr) p.fail("must not have an attribute");

				IF(ctors->Destructor)
					p.fail("redefinition of destructor");

				p.next();

				inline ::= p.consume_s(:PrefixOrPostfixOp(:doubleMinus)) || p.consume_s(:AuxKeyword(:inline));

				body_start ::= p.progress();
				p.skip_braces();
				body ::= body_token_span(body_start, p, NULL);

				ctors->Destructor := :a( p.at_pos(at), inline, body );
			}
			:private: {
				IF(novis) p.fail("No visibility specifier allowed here");
				p.next();
				new_vis: Visibility := :private;
				IF(p.consume_s(:Punctuation(:colon)))
					*vis := new_vis;
				ELSE { vis := &new_vis; novis := TRUE; }

				preparse_member(p, scope, ctors, ops, template, attr, vis, novis, allowed);
			}
			:public: {
				IF(novis) p.fail("No visibility specifier allowed here");
				p.next();
				new_vis: Visibility := :public;
				IF(p.consume_s(:Punctuation(:colon)))
					*vis := new_vis;
				ELSE { vis := &new_vis; novis := TRUE; }

				preparse_member(p, scope, ctors, ops, template, attr, vis, novis, allowed);
			}
			:protected: {
				IF(novis) p.fail("No visibility specifier allowed here");
				p.next();
				new_vis: Visibility := :protected;
				IF(p.consume_s(:Punctuation(:colon)))
					*vis := new_vis;
				ELSE { vis := &new_vis; novis := TRUE; }

				preparse_member(p, scope, ctors, ops, template, attr, vis, novis, allowed);
			}
			:static: {
				IF(attr != :none) p.fail("duplicate attribute");
				attr := :static;
				p.next();

				preparse_member(p, scope, ctors, ops, template, attr, vis, novis, allowed);
			}
			:abstract, :override, :final, :virtual: {
				IF(attr == :static) p.fail("cannot have abstractness on a static member");
				abst ::= extract_abstractness(p);
				name_local ::= p.payload().Identifier.FileLocal;
				name ::= p.expect_p(:Identifier).Identifier;
				name_decl ::= local_to_decl_name(name_local);

				out ::= mempool::[parser::MemberFunction]alloc_unhashed_t();
				fn ::= &out.(0)->Fn;
				out.(0)->Abstractness := abst;

				args ::= preparse_function_internal(p, fn, name, template);
				IF(abst == :abstract)
				{
					p.expect_s(:Punctuation(:semicolon));
					fn->BodyType := :none;
				} ELSE
				{
					(fn->BodyType, fn->Body) := skip_function_body(p, args);
				}

				entry ::= scope->ensure(name_decl);
				entry->set_value(name, at, p, (*vis, :MemberFunction(out.(1))));
			}
			}
		}
		:AuxKeyword:
			SWITCH(p.stype().AuxKeyword)
			{
			:type: {
				IF(attr) p.fail("must not have an attribute");

				at ::= p.progress(); p.next();
				local_name ::= p.payload().Identifier.FileLocal;
				global_name ::= p.expect_p(:Identifier).Identifier;
				decl_name ::= local_to_decl_name(local_name);

				entry ::= scope->ensure(decl_name);
				start ::= p.progress();

				def ::= mempool::[parser::Typedef]alloc_unhashed_t();
				def_p ::= def.(0);

				preparse_typedef(p, def_p, global_name, template);
				entry->set_nonvalue(global_name, at, p, (*vis, :Typedef(def.(1))));
			}
			:this: {
				IF!(ops) p.fail("it is illegal to define operators here");

				p.next();
				at ::= p.progress();

				// op: Operator;
				IF(t ::= p.consume_p(:PostfixOp))
				{
					op ::= parser::postfixOpsFromPostfixTok[t->PostfixOp];
					preparse_postfix_operator(p, at, &ops->Postfix, op, template, attr);
				} ELSE IF(t ::= p.consume_p(:PrefixOrPostfixOp))
				{
					op ::= parser::postfixOpsFromPrefixTok[t->PrefixOrPostfixOp];
					preparse_postfix_operator(p, at, &ops->Postfix, op, template, attr);
				} ELSE IF(t ::= p.consume_p(:BinaryOp))
				{
					op ::= parser::binOpsFromBinaryTok[t->BinaryOp];
					preparse_binary_operator(p, at, &ops->Binary, op, template, attr);
				} ELSE IF(t ::= p.consume_p(:PrefixOrBinaryOp))
				{
					op ::= parser::binOpsFromPrefixTok[t->PrefixOrBinaryOp];
					preparse_binary_operator(p, at, &ops->Binary, op, template, attr);
				} ELSE IF(t ::= p.consume_p(:AssignmentOp))
				{
					IF(attr != :none)
						p.fail_pos(at, "assignments are not possible on constant objects");
					op ::= parser::binOpsFromAssignmentTok[t->AssignmentOp];
					preparse_binary_operator(p, at, &ops->Binary, op, template, attr);
				} ELSE IF(t ::= p.match_s(0, :Punctuation(:doubleQuestionMark))) {
					p.fail("cannot overload conditional operator");
				} ELSE IF(p.consume_s(:Punctuation(:parentheseOpen)))
				{
					IF(ops->HasSpecial & parser::SpecialOperator::FLAGS(:call))
						p.fail("Re-definition of call operator");
					ops->HasSpecial |= parser::SpecialOperator::FLAGS(:call);

					ops->Call.Attr := attr;
					ops->Call.Template := template;

					args_start ::= p.progress();
					p.skip_until_nesting_ends();
					args ::= args_token_span(args_start, p);
					ops->Call.Args := :Preparse(args);
					p.expect_s(:Punctuation(:parentheseClose));

					ops->Call.Rest.Preparse := skip_function_return_type(p, args);
					(ops->Call.BodyType, ops->Call.Body) := skip_function_body(p, args);
				} ELSE IF(p.consume_s(:Punctuation(:bracketOpen)))
				{
					IF(ops->HasSpecial & parser::SpecialOperator::FLAGS(:subscript))
						p.fail("Re-definition of subscript operator");
					ops->HasSpecial |= parser::SpecialOperator::FLAGS(:subscript);

					ops->Subscript.Attr := attr;
					ops->Subscript.Template := template;

					args_start ::= p.progress();
					p.skip_until_nesting_ends();
					args ::= args_token_span(args_start, p);
					p.expect_s(:Punctuation(:bracketClose));

					ret_type ::= skip_function_return_type(p, args);
					body ::= skip_function_body(p, args);

					operator: parser::PreparsedBinaryOperator(
						attr,
						template,
						:Preparse(args),
						:Preparse(ret_type),
						body.(0),
						body.(1));

					// \parseBinaryOp
					ops->Subscript := operator;
				} ELSE {
					p.fail("expected postfix or binary operator");
				}
			}
			}
		:PrefixOp:
		{
			IF!(ops) p.fail("cannot overload operators here");

			op ::= parser::prefixOpsFromPrefixTok[p.stype().PrefixOp];
			at ::= p.progress();
			p.next();

			preparse_prefix_operator(p, at, &ops->Prefix, op, template, attr);
		}
		:PrefixOrBinaryOp: {
			IF!(ops) p.fail("cannot overload operators here");

			op ::= parser::prefixOpsFromBinaryTok[p.stype().PrefixOrBinaryOp];
			at ::= p.progress();
			p.next();

			preparse_prefix_operator(p, at, &ops->Prefix, op, template, attr);
		}
		:PrefixOrPostfixOp: {
			IF!(ops) p.fail("cannot overload operators here");

			op ::= parser::prefixOpsFromPostfixTok[p.stype().PrefixOrPostfixOp];
			at ::= p.progress();
			p.next();

			preparse_prefix_operator(p, at, &ops->Prefix, op, template, attr);
		}
		:BinaryOp:
		{
			SWITCH(p.stype().BinaryOp)
			{
			:less: // <T> conversion operator
			{
				IF!(ops) p.fail("no conversion operators allowed");
				IF(ops->HasSpecial & parser::SpecialOperator::FLAGS(:conversion))
					p.fail("already has a conversion operator");
				ops->HasSpecial |= parser::SpecialOperator::FLAGS(:conversion);

				p.next(); // <
				type_start ::= p.progress();
				WHILE(!p.match_s(0, :BinaryOp(:greater)))
					p.next();
				ops->Conversion.Type := :Preparse(type_token_span(type_start, p));

				p.next(); // >

				ops->Conversion.Inline
					:= p.consume_s(:PrefixOrPostfixOp(:doubleMinus))
					|| p.consume_s(:AuxKeyword(:inline));

				p.skip_nesting_until(:braceOpen, :semicolon, :colonEqual);
				(ops->Conversion.BodyType, ops->Conversion.Body) := skip_function_body(p, NULL);
			}
			}
		}
		} CATCH(err: CHAR#*) {
			os::term::PrintLine_v(:style(:normal, :red), std::str::c(err[]));
			p.fail("expected member");
		}

		--IsInMember;
		Ms := old_ms;
	}

	preparse_prefix_operator(
		p: parser::Parser &,
		at: U4,
		ops: parser::PrefixOperators \,
		op: parser::PrefixOperator,
		template: parser::TokenSpan #&,
		attr: parser::ParsedMemberAttr) VOID
	{
		IF(attr == :static) p.fail("cannot have static operators");
		IF!(op) p.fail_pos(at, "this operator is forbidden to overload");

		p.expect_s(:AuxKeyword(:this));
		ret_type ::= skip_function_return_type(p, NULL);
		body ::= skip_function_body(p, NULL);

		entry: parser::PreparsedPrefixOperator(
			attr,
			template,
			:Preparse(ret_type),
			body.(0),
			body.(1));
		ops->register(op, entry, at, p);
	}

	preparse_postfix_operator(
		p: parser::Parser &,
		at: U4,
		ops: parser::PostfixOperators \,
		op: parser::PostfixOperator,
		template: parser::TokenSpan #&,
		attr: parser::ParsedMemberAttr) VOID
	{
		IF(attr == :static) p.fail("cannot have static operators");
		IF!(op) p.fail_pos(at, "this operator is forbidden to overload");

		ret_type ::= skip_function_return_type(p, NULL);
		body ::= skip_function_body(p, NULL);

		entry: parser::PreparsedPostfixOperator(
			attr,
			template,
			:Preparse(ret_type),
			body.(0),
			body.(1));
		ops->register(op, entry, at, p);
	}

	preparse_binary_operator(
		p: parser::Parser &,
		at: U4,
		ops: parser::BinaryOperators \,
		op: parser::BinaryOperator,
		template: parser::TokenSpan #&,
		attr: parser::ParsedMemberAttr) VOID
	{
		IF!(op) p.fail_pos(at, "this operator is forbidden to overload");

		name: FileLocalIdentifier;
		p.expect_s(:Punctuation(:parentheseOpen));
		IF(p.match_ps(:Identifier, :Punctuation(:colon)))
		{
			name := p.payload().Identifier.FileLocal;
			p.next2();
		}

		args_start ::= p.progress();
		p.skip_until_nesting_ends();
		args ::= args_token_span(args_start, p);
		p.expect_s(:Punctuation(:parentheseClose));

		ret_type ::= skip_function_return_type(p, args);
		body ::= skip_function_body(p, args);

		operator: parser::PreparsedBinaryOperator(
			attr,
			template,
			:Preparse(args),
			:Preparse(ret_type),
			body.(0),
			body.(1));
		ops->register(op, operator, at, p);
	}

	skip_function_return_type(p: parser::Parser &, args: parser::ArgsID) parser::RestID {
		start ::= p.progress();
		IF(p.match_s(0, :Punctuation(:braceOpen)))
			p.skip_braces();
		p.skip_nesting_until(:braceOpen, :semicolon, :colonEqual);
		= return_token_span(start, p, args);
	}

	skip_function_body(p: parser::Parser &, args: parser::ArgsID) {parser::BodyType, parser::BodyID}
	{
		punct ::= <U8>(1) << <U1>(p.stype().Punctuation);
		flags ::= tok::Punctuation::FLAGS(:colonEqual, :semicolon, :braceOpen);
		idx ::= POPCNT ((punct-1) & flags);
		type: parser::BodyType := >idx;

		body_start ::= p.progress() +1; // skip the first token of the body in the span.

		p.skip_nesting_until_after(:braceClose, :semicolon); // skip body.
		span ::= body_token_span(body_start, p, args);

		= (type, span);
	}
}