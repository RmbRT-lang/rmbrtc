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
		Arguments: [Stage]Expression - std::DynVec;
	}

	MemberInit -> CodeObject
	{
		Member: Stage::MemberReference;
		Arguments: [Stage]Expression - std::DynVec;
	}

	BaseInits: BaseInit - std::Vec;
	MemberInits: MemberInit - std::Vec;
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
	Arguments: [Stage]LocalVariable - std::Vec;

	# named() INLINE BOOL := Name!;
}