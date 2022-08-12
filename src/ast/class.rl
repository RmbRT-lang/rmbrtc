INCLUDE "scopeitem.rl"
INCLUDE "codeobject.rl"
INCLUDE "constructor.rl"
INCLUDE "../src/file.rl"

INCLUDE 'std/vector'
INCLUDE 'std/memory'
INCLUDE 'std/set'


::rlc::ast::class [Stage: TYPE] Inheritance -> CodeObject
{
	{}: Visibility := :public;

	Visibility: rlc::Visibility;
	IsVirtual: BOOL;
	Type: Stage::Inheritance;
}

::rlc::ast [Stage: TYPE] Class VIRTUAL ->
	[Stage]ScopeItem,
	[Stage]Templateable,
	CodeObject
{
	Virtual: BOOL;
	Members: [Stage]Member - std::DynVec;
	Inheritances: class::[Stage]Inheritance - std::Vec;

	DefaultCtor: [Stage]DefaultConstructor-std::Dyn;
	CopyCtor: [Stage]CopyConstructor-std::Dyn;
	MoveCtor: [Stage]MoveConstructor-std::Dyn;
	ImplicitCtor: [Stage]CustomConstructor-std::Dyn;
	CustomCtors: [Stage]CustomConstructor-std::AutoDynVecSet;

	:transform{
		p: [Stage::Prev+]Class #&,
		f: Stage #&
	} -> (:transform(p, f)), (:transform(p, f)), (p):
		Virtual := p.Virtual,
		Members := :reserve(##p.Members),
		Inheritances := :reserve(##p.Inheritances)
	{
		FOR(m ::= p.Members.start(); m; ++m)
			Members += <<<[Stage]Member>>>(m!, f);
		FOR(i ::= p.Inheritances.start(); i; ++i)
			Inheritances += :transform(i!, f);

		IF(p.DefaultCtor)
			DefaultCtor := :a(:transform(*p.DefaultCtor, f));
		IF(p.CopyCtor)
			CopyCtor := :a(:transform(*p.CopyCtor, f));
		IF(p.MoveCtor)
			MoveCtor := :a(:transform(*p.MoveCtor, f));
		IF(p.ImplicitCtor)
			ImplicitCtor := :a(:transform(*p.ImplicitCtor, f));
		loc: UM := 0;
		FOR(ctor ::= p.CustomCtors.start(); ctor; ++ctor)
			CustomCtors.emplace_at(loc++, :a(:transform(*(ctor!), f)));
	}

}

::rlc::ast [Stage: TYPE] GlobalClass -> [Stage]Global, [Stage]Class
{
	:transform{
		p: [Stage::Prev+]GlobalClass #&,
		f: Stage #&
	} -> (), (:transform(p, f));
}

::rlc::ast [Stage: TYPE] MemberClass -> [Stage]Member, [Stage]Class
{
	:transform{
		p: [Stage::Prev+]MemberClass #&,
		f: Stage #&
	} -> (p), (:transform(p, f));
}