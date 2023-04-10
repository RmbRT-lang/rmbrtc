INCLUDE "symbol.rl"
INCLUDE "../scoper/stage.rl"
INCLUDE "../ast/stage.rl"

::rlc::resolver Config
{
	ScopedRegistry: ast::[scoper::Config]FileRegistry #\;
	Processed: std::[scoper::Config::RootScope #\, detail::RootScope-std::Dyn]Map;

	TYPE Context := resolver::Context;
	TYPE Symbol := resolver::Symbol;
	TYPE Prev := scoper::Config;
	TYPE PrevFile := _;
	Includes {}
	TYPE RootScope := resolver::detail::RootScope;

	TYPE String := std::str::CV;
	TYPE StringLiteral := std::str::CV;
	TYPE Number := Prev::Number;

	TYPE Name := std::str::CV;
	TYPE MemberReference := ast::[THIS]Symbol::Child;
	TYPE MemberVariableReference := Name;
	TYPE CharLiteral := U4;
	TYPE Inheritance := Symbol;

	TYPE ControlLabelReference := U2;
	TYPE ControlLabelName := Name;

	{prev: scoper::Config #&}:
		ScopedRegistry := &prev!.Registry;

	transform() VOID
	{
		FOR(scoped ::= ScopedRegistry->start())
			IF(!Processed.find(&scoped!.Globals!))
			{
				processed: RootScope - std::Dyn;
				transform_root_scope(scoped!.Globals!, processed!);
				processed->post_process(TRUE);
				Processed.insert(&scoped!.Globals!, &&processed);
			}
	}

	transform_root_scope(
		root: scoper::Config::RootScope #&,
		out: RootScope &) VOID
	{
		ctx ::= <Context>(&out).in_parent(&root.ScopeItems, &out.ScopeItems).in_path(NULL);
		FOR(item ::= root.ScopeItems.start())
			out.ScopeItems += :make(item!.Value!, ctx);

		FOR(test ::= root.Tests.start())
			out.Tests += :transform(test!, ctx);
	}
}

::rlc::resolver::detail RootScope
{
	PRIVATE SymbolResolver
	{
		Item: ast::[Config]ScopeItem * - std::Opt;
		References: UM;
		WriteBack: ast::[Config]ScopeItem ** -std::Vec;
	}

	Symbols: SymbolResolver - std::[ast::[scoper::Config]ScopeItem #\]Map;

	ScopeItems: ast::[Config]GlobalScope;
	Tests: ast::[Config]Test - std::DynVec;

	register_symbol_writeback(
		prev: ast::[scoper::Config]ScopeItem #\,
		writeback: ast::[Config]ScopeItem **
	) VOID {
		Symbols.ensure(prev).WriteBack += writeback;
	}

	post_process(warnUnused: BOOL) VOID
	{
		FOR(symbol ::= Symbols.start())
		{
			v: ?& := symbol!.Value;
			IF(!v.Item)
			{
				std::io::write(&std::io::out,
					:stream(symbol!.Key->Position), ": error: '",
					symbol!.Key->Name!++,
					"' is referenced (", :dec(##v.WriteBack), ") but not in resolved AST.\n");
				CONTINUE;
			} ELSE
			{
				ASSERT(v.Item);
				it ::= v.Item!;
				v.References := ##v.WriteBack;
				FOR(writeBack ::= v.WriteBack.start())
					*writeBack! := it;
			}
			v.WriteBack := BARE;
		}
	}

	{}: ScopeItems := :root;
}

::rlc::resolver Context -> ast::[Config]DefaultContext
{
	TYPE Prev := scoper::Config;

	Root: detail::RootScope \;

	{...};

	# visit_scope_item(
		p: ast::[scoper::Config]ScopeItem #\,
		n: ast::[Config]ScopeItem \
	) VOID INLINE
	{
		Root->Symbols.ensure(p).Item := :a(n);
	}

	# transform_string(p: scoper::Config::String #&) ? := p;
	# transform_name(p: scoper::Config::Name#&) ? #& := p;
	
	# transform_char_literal(p: scoper::Config::CharLiteral) ? := p;
	# transform_string_literal(
		p: scoper::Config::StringLiteral #&
	) Config::StringLiteral
		:= p!;

	# transform_symbol(
		p: scoper::Config::Symbol #&,
		locals: ast::LocalPosition
	) Symbol
		:= :resolve_local(p, locals, THIS);
	

	# transform_member_reference(p: scoper::Config::MemberReference #&) Config::MemberReference
		:= :transform(p, THIS);
	
	# transform_member_variable_reference(
		p: Prev::MemberVariableReference+ #&
	) Config::MemberVariableReference INLINE
		:= transform_name(p);

	# transform_number(p: scoper::Config::Number #&) ? := p;

	# transform_inheritance(p: scoper::Config::Inheritance #&) ? := transform_symbol(p, 0);

	# transform_control_label_name(p: scoper::Config::ControlLabelName #&) ? := p;

	# transform_control_label_reference(
		p: scoper::Config::ControlLabelReference+ -std::Opt #&,
		pos: src::Position #&
	) Config::ControlLabelReference - std::Opt
	{
		ref: Config::ControlLabelReference;
		FOR(stmt ::= THIS.Stmt!; stmt; stmt := stmt->Parent)
		{
			IF(labelled ::= <<ast::[Config]LabelledStatement *>>(stmt))
				IF(!p)
				{
					IF(<<ast::[Config]LoopStatement *>>(labelled))
						= :a(ref);
				} ELSE IF(labelled->Label && labelled->Label->Name == *p)
					= :a(ref);
			++ref;
		}

		IF(p)
			THROW <rlc::ReasonError>(pos, "unknown control label name");
		ELSE
			THROW <rlc::ReasonError>(pos, "not within a labellable statement");
	}
}