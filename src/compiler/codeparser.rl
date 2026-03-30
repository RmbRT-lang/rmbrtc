INCLUDE "../scoper/scope.rl"
INCLUDE "../parser/parser.rl"
INCLUDE "../parser/class.rl"
INCLUDE "../parser/rawtype.rl"
INCLUDE "../parser/enum.rl"
INCLUDE "../parser/union.rl"
INCLUDE "../parser/mask.rl"
INCLUDE "../parser/function.rl"
INCLUDE "../parser/field.rl"
INCLUDE "../parser/symbolconstant.rl"
INCLUDE "../parser/typedef.rl"
INCLUDE "../parser/globalvariable.rl"
INCLUDE "../parser/extern.rl"

::rlc::compiler CodeParser
{
	Output { } // Currently, we have no per-job output. Instead, we have one output once all parsing of all files is complete.

	Input {
		Tokens: @(CACHELINE) tok::FileTokenView;
		LocalIds: U2;
		File: src::File;
	}

	// Parser stack and temporaries.

	// The global rootscope.
	PRIVATE RootScope: scoper::Namespace;
	PRIVATE MemberScopes: parser::Members \ -std::Vec;
	PRIVATE FileTokens: tok::FileTokenView-std::Vec;
	PRIVATE LocalIds: U2-std::Vec;
	PRIVATE LocalDecls: U2-std::Vec;
	PRIVATE LocalDeclLut: U2-std::Vec-std::Vec; // LocalIdx -> LocalDeclIdx

	{}:
		MemberScopes := :reserve(1024),
		FileTokens := :reserve(1024),
		LocalIds := :reserve(2048),
		LocalDecls := :reserve(2048),
		LocalDeclLut := :reserve(2048)
	{
		RootScope.Entries.reserve(1<<16);
	}

	STATIC name() CHAR#[#] -- := "code preparser";

	handle_job(in: Input &, out: Output *) VOID
	{
		// Remember tokens for later.
		IF(in.File <= ##FileTokens)
			FileTokens.resize_bare(in.File+1);
		FileTokens[:ok(in.File)] := in.Tokens; // copy, let the toker reuse the buffer.

		// Global/Local ID buffers
		IF(in.File <= ##LocalIds)
		{
			LocalIds.resize_bare(in.File+1);
			LocalDecls.resize_bare(in.File+1);
			LocalDeclLut.resize_bare(in.File+1);
		}
		LocalIds[:ok(in.File)] := in.LocalIds;
		LocalDecls[:ok(in.File)] := 0;
		LocalDeclLut[:ok(in.File)].resize(in.LocalIds);

		// 2. pre-parse global scope entries (skipping bodies via matching braces) into scope global tree. Populate global scope lookups.
		p: rlc::parser::Parser(FileTokens[:ok(in.File)], in.File);
		WHILE(!p.eof())
			preparse_ns_entry(p, &RootScope, NULL);

		FOR(MemberScopes!) finalise_members(LocalIds[:ok(in.File)], IT);
		MemberScopes.clear_reuse();

		s_member_alloc.clear_and_optimise(4*KI);
		s_member_shrunk_alloc.clear_and_optimise(4*KI);
		s_member_alloc.clear_and_optimise(4*KI);
	}

	token_span(start: U4, p: parser::Parser &) parser::TokenSpan --
		:= (p.File, start, p.progress());

	Preparse {
		ENUM PreparsedThing {
			Class,
			Rawtype,
			Function,
			ExternFunction,
			ExportFunction,
			Variable,
			ExternVariable,
			ExportVariable,
			Enum,
			Union,
			Mask,
			Typedef,
			Test
		}

		Entry {
			UNION Extra {
				link_name: Identifier;
				name_str: tok::TokenStringPayload;
				templates: parser::TokenSpan;
			}

			{BARE};

			scope: scoper::Namespace \;
			name: Identifier;
			span: parser::TokenSpan;
			extra: Extra;
			Next: Entry *; // Entries are allocated in a bump allocator, but we cannot guarantee continuity, so we have a linked list.
		}

		EntryList {
			First: Entry *;
			Last:  Entry *;
		}

		Allocs: std::temp::Alloc-std::Alloc[TABLE PreparsedThing];
		Entries:                  EntryList[TABLE PreparsedThing];
		// Per-file exported identifiers.
		ExportIdentifiers: U2[#];

		{}: Allocs( :custom(64*KI, 64*KI) );


		PRIVATE insert_entry(type: PreparsedThing, e: Entry *) VOID --
		{
			e->Next := NULL;
			IF!(Entries[type].Last)
				Entries[type].First := e;
			ELSE
				Entries[type].Last->Next := e;
			Entries[type].Last := e;
		}
		register(
			type: PreparsedThing,
			scope: scoper::Namespace \,
			name: Identifier,
			span: parser::TokenSpan,
			templates: parser::TokenSpan) VOID
		{
			e ::= Allocs[type].[Entry]alloc();
			e->scope := scope;
			e->name := name;
			e->span := span;
			e->extra.templates := templates;

			insert_entry(type, e);
		}

		register_l(
			type: PreparsedThing,
			scope: scoper::Namespace \,
			name: Identifier,
			span: parser::TokenSpan,
			link_name: Identifier) VOID
		{
			e ::= Allocs[type].[Entry]alloc();
			e->scope := scope;
			e->name := name;
			e->span := span;
			e->extra.link_name := link_name;

			insert_entry(type, e);
		}

		register_test(scope: scoper::Namespace \, span: parser::TokenSpan, name: tok::TokenStringPayload) VOID
		{
			e ::= Allocs[:Test].[Entry]alloc();
			e->scope := scope;
			e->name := 0; // NIL / tests have no name.
			e->span := span;
			e->extra.name_str := name;

			insert_entry(:Test, e);
		}
	}

	preparse: Preparse;

	preparse_ns_entry(
		p: parser::Parser &,
		scope: scoper::Namespace \,
		template: parser::TokenSpan) VOID
	{
		// Namespace entries use the global identifier IDs. Never register a local ID in a namespace.
		// All other scopes use file-local IDs for members, allowing for smaller LUTs and better cache coherence.

		TRY SWITCH(p.type())
		{
		:Identifier:
		{
			at ::= p.progress();  name ::= p.stype().Identifier;  p.next();

			entry ::= scope->ensure(name);
			start ::= p.progress();

			SWITCH(p.type())
			{
			:Punctuation:
				SWITCH(p.stype().Punctuation)
				{
				:parentheseOpen: {
					out ::= mempool::[parser::Function]alloc_unhashed_t();
					preparse_function(p, out.(0), name, template);
					entry->set_value(:Function, out.(1), name, at, p);
				}
				:braceOpen: {
					out ::= mempool::[parser::Class]alloc_unhashed_t();
					preparse_class(p, out.(0), name, template);
					entry->set_nonvalue(:Class, out.(1), name, at, p);
				}
				:colon: {
					IF(template)
						p.fail("Variables cannot be templated");

					out ::= mempool::[parser::GlobalVariable]alloc_unhashed_t();
					preparse_global_variable(p, out.(0), name);
					entry->set_value(:Variable, out.(1), name, at, p);
				}
				}
			:Declaration:
				SWITCH(kw ::= p.stype().Declaration)
				{
				:virtual, :abstract, :final:
				{
					out ::= mempool::[parser::Class]alloc_unhashed_t();
					preparse_class(p, out.(0), name, template);
					entry->set_nonvalue(:Class, out.(1), name, at, p);
				}
				}
			:BinaryOp:
				SWITCH(p.stype().BinaryOp)
				{
				:minusGreater:
				{
					out ::= mempool::[parser::Class]alloc_unhashed_t();
					preparse_class(p, out.(0), name, template);
					entry->set_nonvalue(:Class, out.(1), name, at, p);
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
				entry ::= scope->ensure(name);
				pentry ::= entry.get();

				child_ns: scoper::Namespace * (NOINIT);

				IF(pentry->NVType == :Namespace)
				{
					// Merge / reuse existing namespace.
					child_ns := <scoper::Namespace-Handle>(pentry->NVMem).get();
				} ELSE IF(pentry->NVType == :Nil)
				{
					// Nil: insert new namespace.
					ns_entry ::= mempool::[scoper::Namespace]alloc_unhashed_t();
					child_ns := ns_entry.(0);
					child_ns->{};
					pentry->NVType := :Namespace;
					pentry->NVMem := ns_entry.(1);
				} ELSE
				{
					p.fail("Symbol ", std::io::format::hex(<UM>(pentry)) ," redefined as namespace, was ", std::str::enum(pentry->NVType));
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
				entry ::= scope->ensure(name);
				entry->set_nonvalue(:Rawtype, out.(1), name, at, p);
			}
			:bracketOpen: {
				IF(template)
					p.fail("already had a template declaration");
				start ::= p.progress();
				p.skip_nesting();
				tpl ::= token_span(start, p);
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
				entry ::= scope->ensure(name);
				out ::= mempool::[parser::Enum]alloc_unhashed_t();
				entry->set_nonvalue(:Enum, out.(1), name, at, p);
				preparse_enum(p, out.(0), name);
			}
			:extern: {
				IF(template)
					p.fail("External symbols cannot be templated");

				out ::= mempool::[parser::Extern]alloc_unhashed_t();

				out.(0)->LinkName := 0;
				IF(p.consume_s(:Punctuation(:bracketOpen)))
				{
					out.(0)->LinkName := p.expect_p(:Identifier).Identifier;
					p.expect_s(:Punctuation(:bracketClose));
				}


				start := p.progress();
				name ::= p.expect_p(:Identifier).Identifier;
				out.(0)->Name := name;
				entry ::= scope->ensure(name);
				punct ::= p.stype().Punctuation;
				expect ::= tok::Punctuation::FLAGS(:colon, :parentheseOpen);
				IF!(expect >> <U1>(punct) & (p.type() == :Punctuation))
					p.fail("expected ':' or '('");

				p.next_if(punct == :colon);
				rest_start ::= p.progress();
				p.skip_nesting_until_after(:semicolon);
				out.(0)->Rest := token_span(rest_start, p);
				vtype ::= punct == :colon ?? scoper::ValueGlobal::ExternVariable : scoper::ValueGlobal::ExternFunction;
				entry->set_value(vtype, out.(1), name, at, p);
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
				entry ::= scope->ensure(name);
				punct ::= p.stype().Punctuation;
				IF(p.type() != :Punctuation)
					p.fail();

				span ::= token_span(start, p);
				SWITCH(punct)
				{
				:colon: {
					out ::= mempool::[parser::ExportVariable]alloc_unhashed_t();
					out.(0)->LinkName := link_name;

					preparse_global_variable(p, &out.(0)->Var, name);
					entry->set_value(:ExportVariable, out.(1), name, at, p);
				}
				:parentheseOpen: {
					out ::= mempool::[parser::ExportFunction]alloc_unhashed_t();
					out.(0)->LinkName := link_name;

					preparse_function(p, &out.(0)->Fn, name, template);
					entry->set_value(:ExportFunction, out.(1), name, at, p);
				}
				DEFAULT: p.fail("expected ':' or '('");
				}
			}
			:mask: {
				name ::= p.expect_p(:Identifier).Identifier;
				out ::= mempool::[parser::Mask]alloc_unhashed_t();
				entry ::= scope->ensure(name);
				out.(0)->Name := name;
				preparse_mask(p, out.(0));
				entry->set_nonvalue(:Mask, out.(1), name, at, p);
			}
			:test: {
				IF(template)
					p.fail("Tests cannot be templated");
				name ::= p.expect_s(:String(:StringQuote)).String;
				p.skip_braces();
				preparse.register_test(scope, token_span(start, p), name);
			}
			:union: {
				name ::= p.expect_p(:Identifier).Identifier;
				entry ::= scope->ensure(name);
				out ::= mempool::[parser::Union]alloc_unhashed_t();
				preparse_union(p, out.(0), name, template);
				entry->set_nonvalue(:Union, out.(1), name, at, p);
			}
			}
		}
		:AuxKeyword:
			SWITCH(p.stype().AuxKeyword)
			{
			:type: {
				at ::= p.progress(); p.next();
				name ::= p.expect_p(:Identifier).Identifier;

				entry ::= scope->ensure(name);
				out ::= mempool::[parser::Typedef]alloc_unhashed_t();
				preparse_typedef(p, out.(0), name, template);
				entry->set_nonvalue(:Typedef, out.(1), name, at, p);
			}
			}
		} CATCH(err: CHAR #*) {
			p.fail("expected namespace entry: ", std::str::c(err[]));
		}
	}

	preparse2() VOID
	{
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
		mode := > ( MASK(match) & POPCNT (mask & (2 << <U1>(decl) -1)) );

		= mode;
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
	alloc_members(file: src::File, m: parser::Members \) std::temp::Alloc::Checkpoint
	{
		s ::= s_member_alloc.save();
		max_cap ::= LocalIds[:ok(file)];
		m->IdLut := s_member_alloc.[parser::Members::LUTEntry-Handle]alloc_raw_array(max_cap)[FOR 0];
		m->Entries := s_member_alloc.[{U2, parser::Members::LUTEntry-Handle}]alloc_raw_array(max_cap)[FOR 0];

		MemberScopes += m;
		= s;
	}

	// Call this after parsing the member scope.
	shrink_members(m: parser::Members \, s: std::temp::Alloc::Checkpoint #&) VOID
	{
		// We can move these directly into the mempool.
		m->Entries := mempool::insert_unhashed_array(m->Entries).(0);

		// We do not yet know the final maximum capacity for members.
		idlut ::= s_member_shrunk_alloc.[parser::Members::LUTEntry-Handle]alloc_raw_array(##m->IdLut);
		FOR(m->IdLut) idlut[][IOTA].{ IT }; // FOR(idlut, m->IdLut) LHS.{ RHS };
		m->IdLut := idlut;

		s_member_alloc.restore(s);
	}

	// Call this when a file is fully parsed.
	finalise_members(fileLocalIdCount: U2, m: parser::Members \) VOID
	{
		new ::= mempool::[parser::Members::LUTEntry-Handle]alloc_unhashed_array(fileLocalIdCount).(0);

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

		save ::= alloc_members(p.File, &out->Members);

		// Inheritance.
		inheritance: parser::TokenSpan;
		IF(p.consume_s(:BinaryOp(:minusGreater)))
		{
			inh_start ::= p.progress();
			p.skip_nesting_until(:braceOpen, :semicolon);
			inheritance := token_span(inh_start, p);
		}

		out->Inheritance := inheritance;

		IF(p.consume_s(:Punctuation(:semicolon)))
			RETURN;

		p.expect_s(:Punctuation(:braceOpen));

		vis: rlc::Visibility := :public;
		WHILE(!p.consume_s(:Punctuation(:braceClose)))
			preparse_member(p, &out->Members, &out->Ctors, NULL, :none, &vis,
				Members::FLAGS(:Constructors, :Fields, :Functions, :Types));

		shrink_members(&out->Members, save);
	}

	preparse_rawtype(
		p: parser::Parser &,
		out: parser::Rawtype \,
		template: parser::TokenSpan #&) FileLocalIdentifier
	{
		out->Templates := template;

		p.expect_s(:Punctuation(:parentheseOpen));
		start ::= p.progress();
		cls ::= p.skip_until_nesting_ends_or(:comma);
		out->Size := token_span(start, p);
		p.next();
		IF(cls == :comma)
		{
			start := p.progress();
			p.skip_until_nesting_ends();
			out->Alignment := token_span(start, p);
			p.expect_s(:Punctuation(:parentheseClose));
		}

		local_name ::= p.payload().Identifier.FileLocal;
		out->Name := p.expect_p(:Identifier).Identifier;

		IF(p.consume_s(:Punctuation(:semicolon)))
			RETURN local_name;

		p.expect_s(:Punctuation(:braceOpen));

		save ::= alloc_members(p.File, &out->Members);

		vis: Visibility := :public;
		WHILE(!p.consume_s(:Punctuation(:braceClose)))
			preparse_member(p, &out->Members, &out->Ctors, NULL, :none, &vis,
				Members::FLAGS(:Constructors, :Functions, :Types));

		shrink_members(&out->Members, save);

		= local_name;
	}

	STATIC s_postparse_alloc:           std::temp::Alloc := :custom(1*MI, 1*MI);
	STATIC s_member_alloc:        std::temp::Alloc := :custom(128*KI, 128*KI);
	STATIC s_member_shrunk_alloc: std::temp::Alloc := :custom(128*KI, 128*KI);

	preparse_enum(p: parser::Parser &, out: parser::Enum \, name: Identifier) VOID
	{
		p.expect_s(:Punctuation(:braceOpen));

		IF(p.consume_s(:Punctuation(:braceClose)))
			RETURN;

		checkpoint ::= s_postparse_alloc.save();
		aliases: FileDeclIdentifier-std::[std::temp::Alloc-std::PAlloc]VecT := :reserve(1024, &s_postparse_alloc);

		save ::= alloc_members(p.File, &out->Members);

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
			dedup_id ::= local_to_decl_name(local_id, p.File);

			main_entry ::= out->Members.ensure(dedup_id);
			IF(main_entry->VType)
				p.fail_pos(at, "duplicate enum constant");
			main_entry->VType := :EnumConstant;
			main_entry->VEntry.{ :EnumConstant(entry_val, dedup_id) };

			WHILE(p.consume_s(:Punctuation(:colonEqual)))
			{
				at ::= p.progress();
				alias_local_id ::= p.payload_expect_p(:Identifier).Identifier.FileLocal;
				dedup_alias_id ::= local_to_decl_name(alias_local_id, p.File);
				aliases += dedup_alias_id;

				alias_entry ::= out->Members.ensure(dedup_alias_id).get();
				IF(alias_entry->VType)
					p.fail_pos(at, "duplicate enum constant");
				alias_entry->VType := :EnumConstant;
				alias_entry->VEntry.{ :EnumConstant(entry_val, dedup_alias_id) };
			}

			aliases.clear_reuse();
		} FOR(!p.consume_s(:Punctuation(:comma)); ++entry_val)

		p.expect_s(:Punctuation(:braceClose));

		shrink_members(&out->Members, save);

		s_postparse_alloc.restore(checkpoint);
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

		save ::= alloc_members(p.File, &out->Members);

		p.expect_s(:Punctuation(:braceOpen));

		FOR(field_idx ::= 0;;field_idx++)
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
		}
		p.expect_s(:Punctuation(:braceClose));

		shrink_members(&out->Members, save);
	}

	preparse_mask(p: parser::Parser &, out: parser::Mask \) VOID
	{
		p.expect_s(:Punctuation(:braceOpen));

		save ::= alloc_members(p.File, &out->Members);
		vis: Visibility := :public;
		WHILE(!p.consume_s(:Punctuation(:braceClose)))
			preparse_member(p, &out->Members, NULL, NULL, :none, &vis,
				Members::FLAGS(:Functions));
		shrink_members(&out->Members, save);
	}

	preparse_function(
		p: parser::Parser &,
		out: parser::Function \,
		name: Identifier,
		template: parser::TokenSpan #&) VOID
	{
		out->Name := name;
		out->File := p.File;
		out->Templates := template;

		args_start ::= p.progress();

		p.skip_nesting(); // skip arguments.

		out->Args := token_span(args_start, p);
		return_start ::= p.progress();

		IF(p.match_s(0, :Punctuation(:braceOpen)))
			p.skip_nesting(); // skip return type if it is a tuple.
		ELSE
			p.skip_nesting_until(:braceOpen, :semicolon, :colonEqual);


		out->Return := token_span(return_start, p);
		return_end ::= p.progress();

		punct ::= <U8>(1) << <U1>(p.stype().Punctuation);
		flags ::= tok::Punctuation::FLAGS(:colonEqual, :semicolon, :braceOpen);
		idx ::= POPCNT ((punct-1) & flags);
		out->BodyType := >idx;

		body_start ::= p.progress() +1; // skip the first token of the body.

		p.skip_nesting_until_after(:braceClose, :semicolon); // skip body.
		out->Body := token_span(return_end, p);
	}

	preparse_symbolic_constant(p: parser::Parser &, delim: tok::Punctuation) parser::SymbolConstant
	{
		ret: parser::SymbolConstant (NOINIT);

		p.expect_s(:Punctuation(:colon));
		IF[name](pl ::= p.consume_p(:Identifier))
		{
			ret.Name := :Identifier(pl->Identifier);
		} ELSE
		{
			STATIC specials: {TAGGED tok::Type, parser::SymbolConstant::SpecialName}#[?](
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
			ret.Template := token_span(tpl_start, p);
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

		type_start ::= p.progress();
		// If the type is a function pointer.
		IF(p.match_s(0, :Punctuation(:parentheseOpen)))
			p.skip_nesting(); // Skip the function signature.

		after_type ::= p.skip_nesting_until(:colonEqual, :parentheseOpen, :semicolon);
		out->Type := token_span(type_start, p);

		p.next_if(after_type == :colonEqual);

		v_start ::= p.progress();
		p.skip_nesting_until(:semicolon);
		out->Initialiser := token_span(v_start, p);

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
		type ::= token_span(type_start, p);

		p.next();

		out->Type := type;
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

	local_to_decl_name(name_local: rlc::FileLocalIdentifier, file: src::File) rlc::FileDeclIdentifier --
	{
		decl_count: U2 * := &LocalDecls[:ok(file)];
		dedup_id: U2 * := &LocalDeclLut[:ok(file)][:ok(name_local.V)];
		old ::= *dedup_id;
		count ::= *decl_count;
		fresh ::= old == 0;
		new ::= fresh ?? count : old;
		count += fresh;
		*decl_count := count;
		*dedup_id := new;
		= new;
	}

	ENUM ParsedMemberAttr {
	*	none,
	?	isolated,
	?	maybeIsolated
	}

	preparse_member(
		p: parser::Parser &,
		scope: parser::Members \,
		ctors: parser::Constructors \,
		template: parser::TokenSpan,
		attr: ParsedMemberAttr,
		vis: Visibility \,
		allowed: U4) VOID
	{
		// member classes, functions, fields, ctors, etc.. Only register them by name (except for member classes etc., which also declare public fields. They also should be parsed. But no function bodies or anything. Also do not parse the types of variables.

		TRY SWITCH(p.type())
		{
		:Identifier: {
			at ::= p.progress();
			name ::= p.stype().Identifier;
			name_local ::= p.payload().Identifier.FileLocal;
			name_local_decl ::= local_to_decl_name(name_local, p.File);

			p.next();

			entry ::= scope->ensure(name_local_decl);
			start ::= p.progress();

			SWITCH(p.type())
			{
			:Punctuation:
				SWITCH(p.stype().Punctuation)
				{
				:parentheseOpen: {
					fn ::= mempool::[parser::Function]alloc_unhashed_t();
					entry->set_value(:Function, name, at, p, :Normal(*vis, fn.(1)));
					preparse_function(p, fn.(0), name, template);
				}
				:braceOpen: {
					IF(attr) p.fail_pos(at, "must not have an attribute");

					class ::= mempool::[parser::Class]alloc_unhashed_t();
					entry->set_nonvalue(:Class, name, at, p, :Normal(*vis, class.(1)));
					preparse_class(p, class.(0), name, template);
				}
				:colon: {
					IF(attr == :maybeIsolated) p.fail("must not have #? attribute");
					IF(template) p.fail("Variables cannot be templated");

					p.next();
					type_start ::= p.progress();
					field ::= mempool::[parser::Field]alloc_unhashed_t();
					p.skip_nesting_until(:semicolon);

					field.(0)->Name := name;
					field.(0)->File := p.File;
					field.(0)->Isolated := FALSE;
					field.(0)->Type := token_span(type_start, p);
					p.expect_s(:Punctuation(:semicolon));

					entry->set_value(:Field, name, at, p, :Normal(*vis, field.(1)));
				}
				}
			:Declaration:
				SWITCH(kw ::= p.stype().Declaration)
				{
				:virtual, :abstract, :final:
				{
					IF(attr) p.fail("must not have an attribute");

					class ::= mempool::[parser::Class]alloc_unhashed_t();
					entry->set_nonvalue(:Class, name, at, p, :Normal(*vis, class.(1)));
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
					entry->set_nonvalue(:Class, name, at, p, :Normal(*vis, class.(1)));
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
				entry ::= scope->ensure(local_to_decl_name(lname, p.File));
				entry->set_nonvalue(:Rawtype, gname, at, p, :Normal(*vis, rawtype.(1)));
			}
			:bracketOpen: {
				IF(template) p.fail("already had a template declaration");
				IF(attr) p.fail("templates must come before the attribute");

				start ::= p.progress();
				p.skip_nesting();
				tpl ::= token_span(start, p);
				IF(##tpl == 2) tpl := NULL;
				preparse_member(p, scope, ctors, tpl, attr, vis, allowed);
			}
			:colon: { // :named{} ctor
				IF(attr) p.fail("must not have an attribute");

				sym ::= preparse_symbolic_constant(p, :braceOpen);
				rest ::= p.progress();
				p.skip_braces();
				p.skip_nesting_until_after(:semicolon, :braceClose);

				ctors->register_named_ctor(sym, token_span(rest, p), template, rest, p);
			}
			:braceOpen: { // {} ctor
				IF(attr) p.fail("must not have an attribute");

				at ::= p.progress(); p.next();

				special: parser::SpecialCtors (BARE);
				id: Identifier (0);

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
					p.expect_s(:Punctuation(:braceClose));
					special := :Structure;
				} ELSE IF(p.consume_s(:PrefixOrBinaryOp(:doubleAmp)))
				{
					id: Identifier := 0;
					IF(t ::= p.consume_p(:Identifier)) id := t->Identifier;
					special := :Move;
				} ELSE IF(p.consume_ss(:Punctuation(:hash), :PrefixOrBinaryOp(:amp)))
				{
					id: Identifier := 0;
					IF(t ::= p.consume_p(:Identifier)) id := t->Identifier;
					special := :Copy;
				} ELSE IF(p.match_s(0, :Punctuation(:braceClose)))
				{
					special := :Default;
				} ELSE {
					BREAK;
				}

				p.expect_s(:Punctuation(:braceClose));
				body_start ::= p.progress();
				p.skip_nesting_until_after(:semicolon, :braceClose);
				ctors->register_special_ctor(special, id, at, p);
			}
			:hash: {
				IF(attr) p.fail();
				p.next();

				IF(p.consume_s(:PostfixOp(:questionMark)))
					attr := :maybeIsolated;
				ELSE
					attr := :isolated;

				preparse_member(p, scope, ctors, template, attr, vis, allowed);
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
				decl_name ::= local_to_decl_name(local_name, p.File);
				entry ::= scope->ensure(decl_name);
				def ::= mempool::[parser::Enum]alloc_unhashed_t();
				entry->set_nonvalue(:Enum, global_name, at, p, :Normal(*vis, def.(1)));
				preparse_enum(p, def.(0), global_name);
			}
			:mask: {
				IF(attr) p.fail("must not have an attribute");

				p.next();

				local_name ::= p.payload().Identifier.FileLocal;
				global_name ::= p.expect_p(:Identifier).Identifier;
				decl_name ::= local_to_decl_name(local_name, p.File);
				entry ::= scope->ensure(decl_name);
				def ::= mempool::[parser::Mask]alloc_unhashed_t();
				entry->set_nonvalue(:Mask, global_name, at, p, :Normal(*vis, def.(1)));
				preparse_mask(p, def.(0));
			}
			:union: {
				IF(attr) p.fail("must not have an attribute");

				p.next();

				local_name ::= p.payload().Identifier.FileLocal;
				global_name ::= p.expect_p(:Identifier).Identifier;
				decl_name ::= local_to_decl_name(local_name, p.File);
				entry ::= scope->ensure(decl_name);
				def ::= mempool::[parser::Union]alloc_unhashed_t();
				entry->set_nonvalue(:Union, global_name, at, p, :Normal(*vis, def.(1)));
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
				body ::= token_span(body_start, p);

				ctors->Destructor := :a( p.at_pos(at), inline, body );
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
				decl_name ::= local_to_decl_name(local_name, p.File);

				entry ::= scope->ensure(decl_name);
				start ::= p.progress();

				def ::= mempool::[parser::Typedef]alloc_unhashed_t();
				def_p ::= def.(0);

				preparse_typedef(p, def_p, global_name, template);
				entry->set_nonvalue(:Typedef, global_name, at, p, :Normal(*vis, def.(1)));
			}
			:this: {
				p.next();

				// op: Operator;
				IF(t ::= p.consume_p(:PostfixOp))
				{
					op ::= parser::postfixOpsfromPostfixTok[*t];
					preparse_postfix_operator(p, at, members, op, template, attr);
				} ELSE IF(t ::= p.consume_p(:PrefixOrPostfixOp))
				{
					op ::= parser::postfixOpsfromPrefixTok[*t];
					preparse_postfix_operator(p, at, members, op, template, attr);
				} ELSE IF(t ::= p.consume_p(:BinaryOp))
				{
					op ::= parser::binopsFromBinaryTok[*t];
					preparse_binary_operator(p, at, members, op, template, attr);
				} ELSE IF(t ::= p.consume_p(:PrefixOrBinaryOp))
				{
					op ::= parser::binopsFromPrefixTok[*t];
					preparse_binary_operator(p, at, members, op, template, attr);
				} ELSE {
					p.fail("expected postfix or binary operator");
				}

				p.fail("operator unimplemented");
			}
			}
		} CATCH(err: CHAR#*) p.fail("expected member: ", std::str::c(err[]));
	}
}