INCLUDE "scopeitem.rl"
INCLUDE "codeobject.rl"
INCLUDE "constructor.rl"
INCLUDE "../src/file.rl"

INCLUDE 'std/vector'
INCLUDE 'std/memory'
INCLUDE 'std/hashset'


::rlc::ast::class [Stage: TYPE] Inheritance -> CodeObject
{
	{}: Visibility := :public;

	Visibility: rlc::Visibility;
	IsVirtual: BOOL;
	Type: Stage::Inheritance;
}

::rlc::ast [Stage: TYPE] Class VIRTUAL -> [Stage]ScopeItem, CodeObject
{
	Virtual: BOOL;
	Members: [Stage]Member - std::DynVec;
	Inheritances: class::[Stage]Inheritance - std::Vec;

	DefaultCtor: [Stage]DefaultConstructor-std::Dyn;
	CopyCtor: [Stage]CopyConstructor-std::Dyn;
	MoveCtor: [Stage]MoveConstructor-std::Dyn;
	ImplicitCtor: [Stage]CustomConstructor-std::Dyn;
	CustomCtors: [Stage]CustomConstructor-std::DynHashSet;
}

::rlc::ast [Stage: TYPE] GlobalClass -> [Stage]Global, [Stage]Class
{
}

::rlc::ast [Stage: TYPE] MemberClass -> [Stage]Member, [Stage]Class
{
}