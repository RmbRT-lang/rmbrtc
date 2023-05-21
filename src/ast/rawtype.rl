INCLUDE "scopeitem.rl"
INCLUDE "global.rl"
INCLUDE "member.rl"
INCLUDE "expression.rl"
INCLUDE "../src/file.rl"

INCLUDE 'std/memory'
INCLUDE 'std/vector'

::rlc::ast [Stage:TYPE] Rawtype VIRTUAL ->
	[Stage]ScopeItem,
	[Stage]ScopeBase,
	[Stage]CoreType,
	[Stage]Instantiable
{
	Size: [Stage]Expression-std::Val;
	Alignment: [Stage]Expression-std::ValOpt;
	Functions: [Stage]MemberFunctions;
	Ctors: [Stage]Constructors;
	Statics: [Stage]MemberScope;

	:transform{
		p: [Stage::Prev+]Rawtype #&,
		ctx: Stage::Context+ #&
	} -> (:transform, p, ctx), (:childOf, ctx.Parent), (), (:childOf, ctx.ParentInst!):
		Size := :make(p.Size!, ctx),
		Alignment := :make_if(p.Alignment, p.Alignment.ok(), ctx),
		Functions := :transform(p.Functions, ctx.in_parent(&p, &THIS).in_path(&THIS)),
		Ctors := :transform(p.Ctors, ctx.in_parent(&p, &THIS).in_path(&THIS)),
		Statics := :transform_virtual(p.Statics, ctx.in_parent(&p, &THIS).in_path(&THIS))
	{
		FOR(it ::= p.Statics.start())
			Statics += :make(it!.Value!, ctx.in_parent(&p, &THIS).in_path(&THIS));
	}

	add_member(member: ast::[Stage]Member - std::Val) VOID
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


	# FINAL scope_item(name: Stage::Name #&) [Stage]ScopeItem #*
	{
		IF(item ::= Statics.item(name))
			= item;
		= NULL;
	}

	# FINAL local(name: Stage::Name #&, LocalPosition) [Stage]ScopeItem #*
	{
		IF(item ::= Functions.item(name))
			= item;
		IF(item ::= Statics.item(name))
			= item;
		= NULL;
	}
}

::rlc::ast [Stage:TYPE] GlobalRawtype -> [Stage]Global, [Stage]Rawtype
{
	:transform{
		p: [Stage::Prev+]GlobalRawtype #&,
		ctx: Stage::Context+ #&
	} -> (), (:transform, p, ctx);
}

::rlc::ast [Stage:TYPE] MemberRawtype -> [Stage]Member, [Stage]Rawtype
{
	:transform{
		p: [Stage::Prev+]MemberRawtype #&,
		ctx: Stage::Context+ #&
	} -> (:transform, p), (:transform, p, ctx);
}