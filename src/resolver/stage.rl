INCLUDE "symbol.rl"
INCLUDE "../scoper/stage.rl"
INCLUDE "../ast/stage.rl"

::rlc::resolver Config
{
	ScopedRegistry: ast::[scoper::Config]FileRegistry;
	Registry: ast::[THIS]FileRegistry;

	TYPE Context := resolver::Context;
	TYPE Symbol := resolver::Symbol;
	TYPE Prev := scoper::Config;
	TYPE PrevFile := _;
	Includes {}
	TYPE RootScope := resolver::RootScope;

	TYPE String := std::str::CV;
	TYPE StringLiteral := std::str::CV;
	TYPE Number := Prev::Number;

	TYPE Name := std::str::CV;
	TYPE MemberReference := ast::[THIS]Symbol::Child;
	TYPE MemberVariableReference := Name;
	TYPE CharLiteral := U4;
	TYPE Inheritance := Symbol;

	TYPE ControlLabelReference := ast::[Config]LabelledStatement \;
	TYPE ControlLabelName := Name;

	{prev: scoper::Config-std::Opt &&}:
		ScopedRegistry := &&prev!.Registry,
		Registry := &THIS
	{
		prev := NULL;
	}

	transform() VOID
	{
	}

	transform_root_scope(
		root: scoper::Config::RootScope #&,
		out: RootScope &) VOID
	{
		FOR(item ::= root.ScopeItems.start())
			out.ScopeItems += :make(item!.Value!, <Context>());

		FOR(test ::= root.Tests.start())
			out.Tests += :transform(test!, <Context>());
	}
}

::rlc::resolver RootScope -> ast::[Config]ScopeBase
{
	ScopeItems: ast::[Config]GlobalScope;
	Tests: ast::[Config]Test - std::Vec;

	{}: ScopeItems := :childOf(&THIS);
}

::rlc::resolver Context -> ast::[Config]DefaultContext
{
	TYPE Prev := scoper::Config;

	PrevParent: ast::[scoper::Config]ScopeBase #*;
	Parent: ast::[Config]ScopeBase *;
	Stmt: ast::[Config]Statement *;

	# in_parent(
		prev: ast::[scoper::Config]ScopeBase #*,
		parent: ast::[Config]ScopeBase *
	) THIS
	{
		ret ::= THIS;
		ret.PrevParent := prev;
		ret.Parent := parent;
		= &&ret;
	}

	# in_stmt(
		prev: ast::[scoper::Config]Statement #*,
		cur: ast::[Config]Statement *
	) THIS
	{
		ret ::= THIS;
		ret.PrevStmt := prev;
		ret.Stmt := cur;
		= ret;
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
		FOR(stmt ::= THIS.Stmt; stmt; stmt := stmt->Parent)
			IF(labelled ::= <<ast::[Config]LabelledStatement *>>(stmt))
				IF(!p)
				{
					IF(<<ast::[Config]LoopStatement *>>(labelled))
						= :a(labelled);
				} ELSE IF(labelled->Label && labelled->Label->Name == *p)
					= :a(labelled);

		IF(p)
			THROW <rlc::ReasonError>(pos, "unknown control label name");
		ELSE
			THROW <rlc::ReasonError>(pos, "not within a labellable statement");
	}
}