INCLUDE "../scoper/scope.rl"
INCLUDE "../parser/parser.rl"

::rlc::compiler CodeParser
{
	Output { } // Currently, we have no per-job output. Instead, we have one output once all parsing of all files is complete.

	Input {
		Tokens: @(CACHELINE) tok::FileTokens;
		LocalIds: U2;
		File: src::File;
	}

	// Parser stack and temporaries.
	//PRIVATE Alloc: std::temp::Alloc;

	// The global rootscope.
	PRIVATE RootScope: scoper::Namespace;

	{}
		//Alloc := :custom(1024 * 1024, 1024 * 1024)
	{
		RootScope.Entries.reserve(1<<16);
	}

	STATIC name() CHAR#[#] -- := "code preparser";

	handle_job(in: Input &, out: Output *) VOID
	{
		// 2. pre-parse global scope entries (skipping bodies via matching braces) into scope global tree. Populate global scope lookups.
		p: rlc::parser::Parser(in.Tokens, in.File);
		WHILE(!p.eof())
		{
			preparse_ns_entry(p, &RootScope, NULL);
			//Alloc.clear_and_optimise(4096);
		}


		// 3. fully parse everything, immediately resolving all things to their proper scope entries. -- actually, this does not happen yet. We want a separate stage for this, after we have the fully populated global scope.

		// 4. instantiate, type check, code gen, etc.
	}

	TokenSpan {
		File: src::File; Start: U4; End: U4;
		{...} --; {NULL} --;

		# <BOOL> -- := Start != End;
		# ##THIS U4 -- := End - Start;
	}

	token_span(start: U4, p: parser::Parser &) TokenSpan -- := (p.File, start, p.progress());

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
				templates: TokenSpan;
			}

			{BARE};

			scope: scoper::Namespace \;
			name: Identifier;
			span: TokenSpan;
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

		{}: Allocs( :custom(64<<10, 64<<10) );


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
			span: TokenSpan,
			templates: TokenSpan) VOID
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
			span: TokenSpan,
			link_name: Identifier) VOID
		{
			e ::= Allocs[type].[Entry]alloc();
			e->scope := scope;
			e->name := name;
			e->span := span;
			e->extra.link_name := link_name;

			insert_entry(type, e);
		}

		register_test(scope: scoper::Namespace \, span: TokenSpan, name: tok::TokenStringPayload) VOID
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

	preparse_ns_entry(p: parser::Parser &, scope: scoper::Namespace \, template: TokenSpan) VOID
	{
		// Namespace entries use the global identifier IDs. Never register a local ID in a namespace.
		// All other scopes use file-local IDs for members, allowing for smaller LUTs and better cache coherence.

		TRY SWITCH(p.type())
		{
		:Identifier:
		{
			at ::= p.progress();  name ::= p.payload().Identifier.Global;  p.next();

			entry ::= scope->ensure(name);
			start ::= p.progress();

			SWITCH(p.type())
			{
			:Punctuation:
				SWITCH(p.stype().Punctuation)
				{
				:parentheseOpen: {
					p.skip_nesting(); // skip arguments.
					IF(p.match_s(0, :Punctuation(:braceOpen)))
						p.skip_nesting(); // skip return type if it is a tuple.

					p.skip_nesting_until_after(:braceClose, :semicolon); // skip body.

					preparse.register(:Function, scope, name, token_span(start, p), template);
					entry->set_vtype(:Function, name, at, p);
				}
				:braceOpen: {
					p.skip_nesting();

					preparse.register(:Class, scope, name, token_span(start, p), template);
					entry->set_nvtype(:Class, name, at, p);
				}
				:colon: {
					IF(template)
						p.fail("Variables cannot be templated");

					p.skip_nesting_until_after(:semicolon);

					preparse.register(:Variable, scope, name, token_span(start, p), NULL);
					entry->set_vtype(:Variable, name, at, p);
				}
				}
			:Declaration:
				SWITCH(kw ::= p.stype().Declaration)
				{
				:virtual, :abstract, :final:
				{
					p.skip_nesting_until_after(:braceClose, :semicolon);
					preparse.register(:Class, scope, name, token_span(start, p), template);
					entry->set_nvtype(:Class, name, at, p);
				}
				}
			:BinaryOp:
				SWITCH(p.stype().BinaryOp)
				{
				:minusGreater:
				{
					p.skip_nesting_until_after(:braceClose, :semicolon);

					preparse.register(:Class, scope, name, token_span(start, p), template);
					entry->set_nvtype(:Class, name, at, p);
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
				name ::= p.payload_expect_p(:Identifier).Identifier.Global;
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


				IF(p.payload_consume_s(:Punctuation(:braceOpen)))
				{
					//save ::= Alloc.save();
					WHILE(!p.payload_consume_s(:Punctuation(:braceClose)))
					{
						preparse_ns_entry(p, child_ns, NULL);
						//Alloc.restore(save);
					}
				} ELSE preparse_ns_entry(p, child_ns, NULL);
			}
			:parentheseOpen: {
				start ::= p.progress();
				p.skip_nesting();
				at ::= p.progress();
				name ::= p.payload_expect_p(:Identifier).Identifier.Global;
				entry ::= scope->ensure(name);

				p.skip_nesting_until_after(:braceClose, :semicolon);
				preparse.register(:Rawtype, scope, name, token_span(start, p), template);
				entry->set_nvtype(:Rawtype, name, at, p);
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

				name ::= p.payload_expect_p(:Identifier).Identifier.Global;
				entry ::= scope->ensure(name);
				p.skip_braces();
				preparse.register(:Enum, scope, name, token_span(start, p), NULL);
				entry->set_nvtype(:Enum, name, at, p);
			}
			:extern: {
				IF(template)
					p.fail("External symbols cannot be templated");
				link_name ::= 0;
				IF(p.pos_consume_s(:Punctuation(:bracketOpen)))
				{
					link_name := p.payload_expect_p(:Identifier).Identifier.Global;
					p.expect_s(:Punctuation(:bracketClose));
				}

				start := p.progress();
				name ::= p.payload_expect_p(:Identifier).Identifier.Global;
				entry ::= scope->ensure(name);
				punct ::= p.stype().Punctuation;
				IF(p.type() != :Punctuation)
					p.fail();

				p.skip_nesting_until_after(:semicolon);
				span ::= token_span(start, p);
				SWITCH(punct)
				{
				:colon: {
					preparse.register_l(:ExternVariable, scope, name, span, link_name);
					entry->set_vtype(:ExternVariable, name, at, p);
				}
				:parentheseOpen: {
					preparse.register_l(:ExternFunction, scope, name, span, link_name);
					entry->set_vtype(:ExternFunction, name, at, p);
				}
				DEFAULT: p.fail();
				}
			}
			:export: {
				IF(template)
					p.fail("Exported symbols cannot be templated");
				link_name ::= 0;
				IF(p.pos_consume_s(:Punctuation(:bracketOpen)))
				{
					link_name := p.payload_expect_p(:Identifier).Identifier.Global;
					p.expect_s(:Punctuation(:bracketClose));
				}

				start := p.progress();
				name ::= p.payload_expect_p(:Identifier).Identifier.Global;
				entry ::= scope->ensure(name);
				punct ::= p.stype().Punctuation;
				IF(p.type() != :Punctuation)
					p.fail();

				span ::= token_span(start, p);
				SWITCH(punct)
				{
				:colon: {
					p.skip_nesting_until_after(:semicolon);
					preparse.register_l(:ExportVariable, scope, name, span, link_name);
					entry->set_vtype(:ExportVariable, name, at, p);
				}
				:parentheseOpen: {
					p.skip_nesting();
					IF(p.match_s(0, :Punctuation(:braceOpen)))
						p.skip_nesting();

					p.skip_nesting_until_after(:braceClose, :semicolon);
					preparse.register_l(:ExportFunction, scope, name, span, link_name);
					entry->set_vtype(:ExportFunction, name, at, p);
				}
				}
			}
			:mask: {
				name ::= p.payload_expect_p(:Identifier).Identifier.Global;
				entry ::= scope->ensure(name);
				p.skip_braces();
				preparse.register(:Mask, scope, name, token_span(start, p), template);
				entry->set_nvtype(:Mask, name, at, p);
			}
			:test: {
				IF(template)
					p.fail("Tests cannot be templated");
				name ::= p.expect_s(:String(:StringQuote)).String;
				p.skip_braces();
				preparse.register_test(scope, token_span(start, p), name);
			}
			:union: {
				name ::= p.payload_expect_p(:Identifier).Identifier.Global;
				entry ::= scope->ensure(name);
				p.skip_braces();
				preparse.register(:Union, scope, name, token_span(start, p), template);
				entry->set_nvtype(:Union, name, at, p);
			}
			}
		}
		:AuxKeyword:
			SWITCH(p.stype().AuxKeyword)
			{
			:type: {
				at ::= p.progress(); p.next();
				name ::= p.payload_expect_p(:Identifier).Identifier.Global;

				entry ::= scope->ensure(name);
				start ::= p.progress();

				p.skip_nesting_until_after(:semicolon);
				preparse.register(:Typedef, scope, name, token_span(start, p), template);
				entry->set_nvtype(:Typedef, name, at, p);
			}
			}
		} CATCH(CHAR #*) {
			p.fail("expected namespace entry");
		}
	}
}