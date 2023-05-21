INCLUDE "../scoper/stage.rl"
INCLUDE "../resolver/symbol.rl"
INCLUDE "symbol.rl"

::rlc::instantiator Config
{
	TYPE Prev := resolver::Config;
	TYPE RootScope := instantiator::detail::RootScope;
	TYPE Context := instantiator::Context;

	TYPE Name := resolver::Config::Name;
	TYPE Symbol := instantiator::Symbol;

	TYPE Number := Prev::Number+;
	TYPE CharLiteral := Prev::CharLiteral+;
	TYPE StringLiteral := Prev::StringLiteral+;

	TYPE ControlLabelName := :nothing;
	TYPE ControlLabelReference := ast::[THIS]LabelledStatement #\;

	MemberReference
	{
		Type: InstanceType -std::Val;
		Member: ast::[Prev]Member #\;
		Templates: ast::[Config]TemplateArg-std::Vec;

		:field{id: InstanceID #\, index: UM} { DIE "TODO"; }
	}

	{
		config: resolver::Config &,
		cli: ::cli::Console \,
		generator: instantiator::Generator -std::Shared
	}:
		Roots := :reserve(##config.Processed),
		Cli := cli,
		Generator := &&generator
	{
		FOR(root ::= config.Processed.start())
			Roots += (root!.Value.ptr(), Cli);
	}

	Roots: RootScope -std::Vec;
	Cli: cli::Console \;
	Generator: instantiator::Generator-std::Shared;

	generate_entry_point_by_name(name: std::str::CV #&) VOID
	{
		mainFn: ast::[resolver::Config]Function #*;
		mainFnDefault: ast::[resolver::Config]Functoid #*;
		FOR(root ::= Roots.start())
		{
			item ::= root!.find_by_name(name);
			IF(item.(1))
			{
				IF(mainFnDefault)
					THROW <rlc::ast::MergeError>(mainFn, item.(1));

				IF!(mainFn := <<ast::[resolver::Config]Function #*>>(item.(1)))
					CONTINUE;
				IF!(mainFn->Default)
					CONTINUE;
				mainFnDefault := &mainFn->Default!;

				parent: InstanceID #*;
				FOR(child ::= item.(0).start())
				{
					id ::= root!.Cache.IDs.ensure(:default_key(parent, child!)).ptr();
					root!.Cache.generate_default(Generator!, parent, child!);
					parent := id;
				}
				root!.Cache.generate_default(Generator!, parent, >>item.(1));
			}
		}
		IF(!mainFnDefault)
			THROW "No entry point found to generate.";
	}

	generate_everything() VOID
	{
		generate_tests();

		FOR(root ::= Roots.start())
			FOR(global ::= root!.Prev->ScopeItems.start())
				IF(inst ::= <<ast::[resolver::Config]Instantiable #*>>(&global!.Value!))
					generate_everything_instantiable_impl(root!.Cache, inst, NULL);
				ELSE
					generate_everything_global_impl(root!.Cache, &global!.Value!);
	}

	PRIVATE generate_everything_global_impl(
		cache: Cache &,
		item: ast::[resolver::Config]Global #\) VOID
	{
		IF(tpl ::= <<ast::[resolver::Config]Templateable #*>>(item))
			IF(tpl->has_templates())
				RETURN;

		IF(s ::= <<ast::[resolver::Config]ScopeItem #*>>(item))
		{
			std::io::write(&std::io::out, :stream(<<ast::CodeObject #&>>(*item).Position), " ", s->Name!++, :ch('\n'));
		}

		TYPE SWITCH(item)
		{
		ast::[resolver::Config]Namespace:
		{
			ns ::= <<ast::[resolver::Config]Namespace #\>>(item);
			FOR(global ::= ns->Entries.start())
			{
				IF(inst ::= <<ast::[resolver::Config]Instantiable #*>>(&global!.Value!))
					generate_everything_instantiable_impl(cache, inst, NULL);
				ELSE
					generate_everything_global_impl(cache, &global!.Value!);
			}
		}
		ast::[resolver::Config]GlobalEnum: cache.Enums += >>(item);
		ast::[resolver::Config]GlobalFunction:
		{
			fn ::= <<ast::[resolver::Config]GlobalFunction #\>>(item);
			IF(fn->Default)
				generate_everything_instantiable_impl(cache, &fn->Default!, NULL);
			FOR(var ::= fn->SpecialVariants.start())
				generate_everything_instantiable_impl(cache, &var!.Value!, NULL);
			FOR(var ::= fn->Variants.start())
				generate_everything_instantiable_impl(cache, &var!.Value!, NULL);
		}
		ast::[resolver::Config]GlobalVariable: cache.GlobalVars += >>item;
		ast::[resolver::Config]ExternFunction: cache.ExternFns += >>item;
		ast::[resolver::Config]ExternVariable: cache.ExternVars += >>item;
		ast::[resolver::Config]GlobalTypedef:
			generate_everything_instantiable_impl(cache, >>item, NULL);
		}
	}

	PRIVATE generate_everything_instantiable_impl(
		cache: Cache &,
		item: ast::[resolver::Config]Instantiable #\,
		parent: Instance *
	) VOID {
		IF(tpl ::= <<ast::[resolver::Config]Templateable #*>>(item))
			IF(tpl->has_templates())
				RETURN;

		IF(s ::= <<ast::[resolver::Config]ScopeItem #*>>(item))
		{
			std::io::write(&std::io::out, :stream(<<ast::CodeObject #&>>(*item).Position), " ", s->Name!++, :ch('\n'));
		}

		//item_i ::= cache.generate_default(Generator!, parent, item);
	}

	generate_tests() VOID
	{
		FOR(root ::= Roots.start())
		{
			FOR(test ::= root!.Prev->Tests.start())
				root!.Cache.generate_default(Generator!, NULL, &test!);

			FOR(global ::= root!.Prev->ScopeItems.start())
				IF(ns ::= <<ast::[resolver::Config]Namespace #*>>(&global!))
					generate_tests_in_namespace(root!.Cache, *ns);
		}
	}

	PRIVATE generate_tests_in_namespace(
		cache: Cache &,
		ns: ast::[resolver::Config]Namespace #&
	) VOID
	{
		FOR(test ::= ns.Tests.start())
			cache.generate_default(Generator!, NULL, &test!);

		FOR(global ::= ns.Entries.start())
			IF(inner_ns ::= <<ast::[resolver::Config]Namespace #*>>(&global!.Value!))
				generate_tests_in_namespace(cache, *inner_ns);
	}
}

::rlc::instantiator {
	TYPE ValTplArg := ast::[Config]TemplateArg-std::Val;
	TYPE ValTplArgSet := ValTplArg-std::Vec-std::Val;
}