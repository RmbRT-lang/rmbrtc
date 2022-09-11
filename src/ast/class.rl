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

	:transform{
		p: [Stage::Prev+]Inheritance #&,
		f: Stage::PrevFile+,
		s: Stage &
	} -> (p):
		Visibility := p.Visibility,
		IsVirtual := p.IsVirtual,
		Type := :transform(p.Type, f, s);

	Visibility: rlc::Visibility;
	IsVirtual: BOOL;
	Type: Stage::Inheritance;
}

::rlc::ast [Stage: TYPE] Class VIRTUAL ->
	[Stage]ScopeItem,
	[Stage]Templateable
{
	Virtual: BOOL;
	Members: [Stage]Member - std::DynVec;
	Inheritances: class::[Stage]Inheritance - std::Vec;

	/// The auto-generated structural (member-wise) constructor.
	StructuralCtor: [Stage]StructuralConstructor-std::Dyn;
	DefaultCtor: [Stage]DefaultConstructor-std::Dyn;
	CopyCtor: [Stage]CopyConstructor-std::Dyn;
	MoveCtor: [Stage]MoveConstructor-std::Dyn;
	NullCtor: [Stage]NullConstructor-std::Dyn;
	BareCtor: [Stage]BareConstructor-std::Dyn;

	/// Custom unnamed constructor. If there is a structural ctor, they must differ in their argument count.
	ImplicitCtor: [Stage]CustomConstructor-std::Dyn;
	CustomCtors: [Stage]CustomConstructor-std::AutoDynVecSet;

	:transform{
		p: [Stage::Prev+]Class #&,
		f: Stage::PrevFile+,
		s: Stage &
	} -> (:transform, p, f, s), (:transform, p, f, s):
		Virtual := p.Virtual,
		Members := :reserve(##p.Members),
		Inheritances := :reserve(##p.Inheritances),
		CustomCtors := :reserve(##p.CustomCtors)
	{
		FOR(m ::= p.Members.start())
			Members += <<<[Stage]Member>>>(m!, f, s);
		FOR(i ::= p.Inheritances.start())
			Inheritances += :transform(i!, f, s);

		IF(p.StructuralCtor)

		IF(p.DefaultCtor)
			DefaultCtor := :a(:transform(*p.DefaultCtor, f, s));
		IF(p.CopyCtor)
			CopyCtor := :a(:transform(*p.CopyCtor, f, s));
		IF(p.MoveCtor)
			MoveCtor := :a(:transform(*p.MoveCtor, f, s));
		IF(p.ImplicitCtor)
			ImplicitCtor := :a(:transform(*p.ImplicitCtor, f, s));
		FOR(ctor ::= p.CustomCtors.start())
			CustomCtors.emplace_at(##CustomCtors, :a(:transform(*ctor!, f, s)));
	}
}

::rlc::ast [Stage: TYPE] GlobalClass -> [Stage]Global, [Stage]Class
{
	:transform{
		p: [Stage::Prev+]GlobalClass #&,
		f: Stage::PrevFile+,
		s: Stage &
	} -> (), (:transform, p, f, s);
}

::rlc::ast [Stage: TYPE] MemberClass -> [Stage]Member, [Stage]Class
{
	:transform{
		p: [Stage::Prev+]MemberClass #&,
		f: Stage::PrevFile+,
		s: Stage &
	} -> (:transform, p), (:transform, p, f, s);
}