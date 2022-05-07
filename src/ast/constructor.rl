INCLUDE "variable.rl"
INCLUDE "expression.rl"
INCLUDE "symbol.rl"
INCLUDE "symbolconstant.rl"
INCLUDE "statement.rl"

INCLUDE 'std/vector'
INCLUDE 'std/memory'

::rlc::ast [Stage: TYPE] Constructor VIRTUAL ->
	[Stage]Member,
	[Stage]Templateable,
	CodeObject
{
	Initialisers VIRTUAL {}

	BaseInit -> CodeObject
	{
		Base: Stage::Inheritance;
		Arguments: [Stage]Expression - std::DynVec;
	}

	MemberInit -> CodeObject
	{
		Member: Stage::MemberVariableReference;
		Arguments: [Stage]Expression - std::DynVec;
	}

	ExplicitInits -> Initialisers
	{
		BaseInits: BaseInit - std::Vec;
		MemberInits: MemberInit - std::Vec;
	}

	CtorAlias -> Initialisers
	{
		Arguments: [Stage]Expression - std::DynVec;
	}

	Inits: Initialisers - std::Dyn;
	Body: [Stage]BlockStatement - std::Dyn;
	Inline: BOOL;
}

::rlc::ast [Stage: TYPE] DefaultConstructor -> [Stage]Constructor
{
}

::rlc::ast [Stage: TYPE] CopyConstructor -> [Stage]Constructor
{
	Argument: ast::[Stage]Argument-std::Opt;

	{};
	:named_arg{
		name: Stage::Name
	}: Argument(:a(name, :gc(std::heap::[[Stage]ThisType]new(:cref))));
	:unnamed_arg{};
}

::rlc::ast [Stage: TYPE] MoveConstructor -> [Stage]Constructor
{
	Argument: ast::[Stage]Argument-std::Opt;

	{};
	:named_arg{
		name: Stage::Name
	}: Argument(:a(name, :gc(std::heap::[[Stage]ThisType]new(:tempRef))));
	:unnamed_arg{};
}

::rlc::ast [Stage: TYPE] CustomConstructor -> [Stage]Constructor
{
	Name: [Stage]SymbolConstant - std::Opt;
	Arguments: [Stage]TypeOrArgument - std::DynVec;

	# named() BOOL INLINE := Name!;
}