INCLUDE "variable.rl"
INCLUDE "expression.rl"
INCLUDE "symbol.rl"
INCLUDE "symbolconstant.rl"
INCLUDE "statement.rl"

INCLUDE 'std/vector'
INCLUDE 'std/memory'

::rlc::ast [Stage: TYPE] Constructor VIRTUAL -> [Stage]Member, CodeObject
{
	BaseInit -> CodeObject
	{
		Base: Stage::Inheritance;
		Arguments: [Stage]Expression - std::DynVector;
	}

	MemberInit -> CodeObject
	{
		Member: Stage::MemberReference;
		Arguments: [Stage]Expression - std::DynVector;
	}

	BaseInits: BaseInit - std::Vector;
	MemberInits: MemberInit - std::Vector;
	Body: [Stage]BlockStatement - std::Dyn;
	Inline: BOOL;
}

::rlc::ast [Stage: TYPE] DefaultConstructor -> [Stage]Constructor
{
}

::rlc::ast [Stage: TYPE] CopyConstructor -> [Stage]Constructor
{
	Argument: [Stage]LocalVariable;

	:named_arg{
		name: Stage::Identifier
	}: Argument(0, name, std::heap::[[Stage]ThisType]new(:cref));
	:unnamed_arg{}: Argument(:unnamed(0, std::heap::[[Stage]ThisType]new(:cref)));
}

::rlc::ast [Stage: TYPE] MoveConstructor -> [Stage]Constructor
{
	Argument: [Stage]LocalVariable;

	:named_arg{
		name: Stage::Identifier
	}: Argument(0, name, std::heap::[[Stage]ThisType]new(:tempRef));
	:unnamed_arg{}: Argument(:unnamed(0, std::heap::[[Stage]ThisType]new(:tempRef)));
}

::rlc::ast [Stage: TYPE] CustomConstructor -> [Stage]Constructor
{
	Name: [Stage]SymbolConstant - std::Dyn;
	Arguments: [Stage]LocalVariable - std::Vector;

	# named() INLINE BOOL := Name!;
}