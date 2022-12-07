INCLUDE "scopeitem.rl"
INCLUDE "global.rl"
INCLUDE "member.rl"
INCLUDE "expression.rl"
INCLUDE "../src/file.rl"

INCLUDE 'std/memory'
INCLUDE 'std/vector'

::rlc::ast [Stage:TYPE] Rawtype VIRTUAL -> [Stage]ScopeItem, [Stage]ScopeBase
{
	Size: [Stage]Expression-std::Dyn;
	Alignment: [Stage]Expression-std::DynOpt;
	Functions: [Stage]MemberFunctions;
	Ctors: [Stage]Constructors;
	Statics: [Stage]MemberScope;

	:transform{
		p: [Stage::Prev+]Rawtype #&,
		f: Stage::PrevFile+,
		s: Stage &,
		parent: [Stage]ScopeBase \
	} -> (:transform, p, f, s), (:childOf, parent):
		Size := :make(p.Size!, f, s, parent),
		Alignment := :make_if(p.Alignment, p.Alignment.ok(), f, s, parent),
		Functions := :transform(p.Functions, f, s, &THIS),
		Ctors := :transform(p.Ctors, f, s, &THIS),
		Statics := :transform(p.Statics, f, s, &THIS)
	{
		FOR(it ::= p.Statics.start())
			Statics += <<<[Stage]Member>>>(it!.Value!, f, s, &THIS);
	}

	add_member(member: ast::[Stage]Member - std::Dyn) VOID
	{
		IF(member->Attribute == :static)
			Statics.insert(&&member);
		ELSE TYPE SWITCH(member!)
		{
		ast::[Stage]Constructor:
			Ctors += :<>(&&member);
		ast::[Stage]Abstractable:
			Functions += :<>(&&member);
		}
	}
}

::rlc::ast [Stage:TYPE] GlobalRawtype -> [Stage]Global, [Stage]Rawtype
{
	:transform{
		p: [Stage::Prev+]GlobalRawtype #&,
		f: Stage::PrevFile+,
		s: Stage &,
		parent: [Stage]ScopeBase \
	} -> (), (:transform, p, f, s, parent);
}

::rlc::ast [Stage:TYPE] MemberRawtype -> [Stage]Member, [Stage]Rawtype
{
	:transform{
		p: [Stage::Prev+]MemberRawtype #&,
		f: Stage::PrevFile+,
		s: Stage &,
		parent: [Stage]ScopeBase \
	} -> (:transform, p), (:transform, p, f, s, parent);
}