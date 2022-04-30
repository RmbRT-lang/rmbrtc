INCLUDE "scopeitem.rl"
INCLUDE "codeobject.rl"
INCLUDE "constructor.rl"
INCLUDE "../src/file.rl"

INCLUDE 'std/vector'
INCLUDE 'std/memory'
INCLUDE 'std/hashset'


::rlc::ast::class [Stage: TYPE] Inheritance -> CodeObject
{
	Visibility: rlc::Visibility;
	IsVirtual: BOOL;
	Type: Stage::Inheritance;
}

::rlc::ast [Stage: TYPE] Class VIRTUAL -> [Stage]ScopeItem, CodeObject
{
	Virtual: BOOL;
	Members: [Stage]Member - std::DynVector;
	Inheritances: class::[Stage]Inheritance - std::Vector;

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