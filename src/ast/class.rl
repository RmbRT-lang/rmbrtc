INCLUDE "scopeitem.rl"
INCLUDE "scope.rl"
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
		ctx: Stage::Context+ #&
	} -> (p):
		Visibility := p.Visibility,
		IsVirtual := p.IsVirtual,
		Type := ctx.transform_inheritance(p.Type);

	Visibility: rlc::Visibility;
	IsVirtual: BOOL;
	Type: Stage::Inheritance;
}

::rlc::ast [Stage: TYPE] MemberFunctions
{
	Functions: ast::[Stage]MemberFunction-std::VecSet;
	Converter: ast::[Stage]Converter-std::DynOpt;
	Operators: ast::[Stage]Operator-std::VecSet;
	Factory: ast::[Stage]Factory-std::DynOpt;

	{};

	:transform{
		p: [Stage::Prev+]MemberFunctions #&,
		ctx: Stage::Context+ #&
	}:
		Functions := :reserve(##p.Functions),
		Converter := :if(p.Converter, :transform(p.Converter.ok(), ctx)),
		Operators := :reserve(##p.Operators),
		Factory := :if(p.Factory, :transform(p.Factory.ok(), ctx))
	{
		FOR(fn ::= p.Functions.start())
			Functions += :transform(fn!, ctx);
		FOR(o ::= p.Operators.start())
			Operators += :transform(o!, ctx);
	}

	THIS += (fn: [Stage]Abstractable-std::Dyn) VOID
	{
		pos ::= <<CodeObject \>>(fn)->Position;
		TYPE SWITCH(fn!)
		{
		ast::[Stage]Converter:
			IF(!Converter)
				Converter := :<>(&&fn);
			ELSE THROW <rlc::ReasonError>(pos, "multiple converters");
		ast::[Stage]MemberFunction:
		{
			fn_: [Stage]MemberFunction & := >>fn!;
			IF(existing ::= Functions.find(fn_))
				existing->merge(&&fn_);
			ELSE ASSERT(Functions += &&fn_);
		}
		ast::[Stage]Operator:
			IF!(Operators += &&<<ast::[Stage]Operator&>>(fn!))
				THROW <rlc::ReasonError>(pos, "duplicate operator");
		}
	}

	set_factory(f: ast::[Stage]Factory-std::Dyn) VOID
	{
		IF(!Factory)
			Factory := &&f;
		ELSE
		{
			pos ::= <<CodeObject \>>(f)->Position;
			THROW <rlc::ReasonError>(pos, "duplicate factory");
		}
	}

	#? item(name: Stage::Name #&) ?
	{
		fn: [Stage]MemberFunction (BARE);
		fn.Name := name;
		= Functions.find(fn).ptr();
	}
}

::rlc::ast [Stage: TYPE] Fields
{
	NamedVars: [Stage]MemberScope;
	AnonVars: [Stage]AnonMemberVariable - std::Vec;

	{parent: [Stage]ScopeBase \}: NamedVars := :childOf(parent);

	:transform{
		p: [Stage::Prev+]Fields #&,
		ctx: Stage::Context+ #&
	}:
		NamedVars := :childOf(ctx.Parent),
		AnonVars := :reserve(##p.AnonVars)
	{
		FOR(m ::= p.NamedVars.start())
			NamedVars.insert(:make(m!.Value!, ctx));

		FOR(v ::= p.AnonVars.start())
			AnonVars += :transform(v!, ctx);
	}

	THIS += (v: [Stage]MaybeAnonMemberVar-std::Dyn) VOID
	{
		TYPE SWITCH(v!)
		{
		ast::[Stage]AnonMemberVariable:
			AnonVars += <[Stage]AnonMemberVariable &&>(&&v!);
		ast::[Stage]MemberVariable:
			NamedVars.insert(:<>(&&v));
		}
	}

	#? item(name: Stage::Name #&) ? := NamedVars.scope_item(name);
}

::rlc::ast [Stage: TYPE] Constructors
{
	/// The auto-generated structural (member-wise) constructor.
	StructuralCtor: [Stage]StructuralConstructor-std::DynOpt;
	DefaultCtor: [Stage]DefaultConstructor-std::DynOpt;
	CopyCtor: [Stage]CopyConstructor-std::DynOpt;
	MoveCtor: [Stage]MoveConstructor-std::DynOpt;
	NullCtor: [Stage]NullConstructor-std::DynOpt;
	BareCtor: [Stage]BareConstructor-std::DynOpt;
	/// Custom unnamed constructor. If there is a structural ctor, they must differ in their argument count.
	ImplicitCtor: [Stage]CustomConstructor-std::DynOpt;
	CustomCtors: [Stage]CustomConstructor-std::VecSet;


	:transform{
		p: [Stage::Prev+]Constructors #&,
		ctx: Stage::Context+ #&
	}:
		StructuralCtor:= :if(p.StructuralCtor,
			:transform(p.StructuralCtor.ok(), ctx)),
		DefaultCtor := :if(p.DefaultCtor,
				:transform(p.DefaultCtor.ok(), ctx)),
		CopyCtor := :if(p.CopyCtor,
			:transform(p.CopyCtor.ok(), ctx)),
		MoveCtor := :if(p.MoveCtor,
			:transform(p.MoveCtor.ok(), ctx)),
		NullCtor := :if(p.NullCtor,
			:transform(p.NullCtor.ok(), ctx)),
		BareCtor := :if(p.BareCtor,
			:transform(p.BareCtor.ok(), ctx)),
		ImplicitCtor := :if(p.ImplicitCtor,
			:transform(p.ImplicitCtor.ok(), ctx)),
		CustomCtors := :reserve(##p.CustomCtors)
	{
		FOR(ctor ::= p.CustomCtors.start())
			CustomCtors += :transform(ctor!, ctx);
	}

	THIS += (ctor: [Stage]Constructor-std::Dyn) BOOL
	{
		pos ::= ctor->Position;
		TYPE SWITCH(ctor!)
		{
		ast::[Stage]NullConstructor:
			IF(NullCtor)
				THROW <ReasonError>(pos, "multiple NULL constructors");
			ELSE = NullCtor := :<>(&&ctor);
		ast::[Stage]BareConstructor:
			IF(BareCtor)
				THROW <ReasonError>(pos, "multiple BARE constructors");
			ELSE = BareCtor := :<>(&&ctor);
		ast::[Stage]StructuralConstructor:
			IF(StructuralCtor)
				THROW <ReasonError>(pos, "multiple structural constructors");
			ELSE = StructuralCtor := :<>(&&ctor);
		ast::[Stage]DefaultConstructor:
			IF(DefaultCtor)
				THROW <ReasonError>(pos, "multiple default constructors");
			ELSE = DefaultCtor := :<>(&&ctor);
		ast::[Stage]CopyConstructor:
			IF(CopyCtor)
				THROW <ReasonError>(pos, "multiple copy constructors");
			ELSE = CopyCtor := :<>(&&ctor);
		ast::[Stage]MoveConstructor:
			IF(MoveCtor)
				THROW <ReasonError>(pos, "multiple copy constructors");
			ELSE = MoveCtor := :<>(&&ctor);
		ast::[Stage]CustomConstructor:
			= CustomCtors += <[Stage]CustomConstructor&&>(&&ctor!);
		}
	}
}

::rlc::ast [Stage: TYPE] ClassMembers -> [Stage]ScopeBase
{
	Fields: ast::[Stage]Fields - std::DynOpt;
	Functions: [Stage]MemberFunctions-std::DynOpt;
	Ctors: ast::[Stage]Constructors;
	Destructor: ast::[Stage]Destructor-std::DynOpt;
	Statics: [Stage]MemberScope;

	:transform{
		p: [Stage::Prev+]ClassMembers #&,
		ctx: Stage::Context+ #&
	} -> (:childOf, ctx.Parent):
		Ctors := :transform(p.Ctors, ctx.in_parent(&p, &THIS)),
		Statics := :transform_virtual(p.Statics, ctx.in_parent(&p, &THIS)),
		Fields := :if(p.Fields, :transform(p.Fields.ok(), ctx.in_parent(&p, &THIS))),
		Functions := :if(p.Functions, :transform(p.Functions.ok(), ctx.in_parent(&p, &THIS))),
		Destructor := :if(p.Destructor, :transform(p.Destructor.ok(), ctx.in_parent(&p, &THIS)));

	#? FINAL scope_item(name: Stage::Name #&) [Stage]ScopeItem #? *
	{
		IF(item ::= Statics.scope_item(name))
			= item;
		= NULL;
	}

	#? FINAL local(name: Stage::Name #&, LocalPosition) [Stage]ScopeItem #? *
	{
		IF(Fields)
			IF(item ::= Fields->item(name))
				= item;
		IF(Functions)
			IF(item ::= Functions->item(name))
				= item;
		IF(item ::= Statics.item(name))
				= item;
		= NULL;
	}

	THIS += (member: [Stage]Member - std::Dyn) VOID
	{
		IF(named ::= <<[Stage]ScopeItem *>>(member))
			IF(exists ::= local(named->Name, 0))
				THROW <MergeError>(exists, named);

		IF(member->Attribute == :static)
			Statics.insert(&&member);
		ELSE TYPE SWITCH(member!)
		{
		ast::[Stage]Constructor:
			Ctors += :<>(&&member);
		ast::[Stage]Destructor:
		{
			IF(Destructor)
				THROW <ReasonError>(
					<<ast::[Stage]Destructor \>>(member)->Position,
					"duplicate destructor");
			Destructor := :<>(&&member);
		}
		ast::[Stage]Abstractable:
			Functions.ensure() += :<>(&&member);
		ast::[Stage]Factory:
			Functions.ensure().set_factory(:<>(&&member));
		ast::[Stage]MaybeAnonMemberVar:
			Fields.ensure() += :<>(&&member);

		ast::[Stage]MemberTypedef,
		ast::[Stage]MemberClass,
		ast::[Stage]MemberEnum,
		ast::[Stage]MemberUnion,
		ast::[Stage]MemberRawtype:
			Statics.insert(&&member);
		}
	}
}

::rlc::ast [Stage: TYPE] Class VIRTUAL ->
	[Stage]ScopeItem,
	[Stage]Templateable,
	[Stage]ScopeBase
{
	Virtual: BOOL;
	Inheritances: class::[Stage]Inheritance - std::Vec;

	Members: [Stage]ClassMembers;

	:transform{
		p: [Stage::Prev+]Class #&,
		ctx: Stage::Context+ #&
	} -> (:transform, p, ctx), (:transform, p, ctx.in_parent(&p, &THIS)), (:childOf, ctx.Parent):
		Virtual := p.Virtual,
		Inheritances := :reserve(##p.Inheritances),
		Members := :transform(p.Members, ctx.in_parent(&p, &THIS))
	{
		FOR(i ::= p.Inheritances.start())
			Inheritances += :transform(i!, ctx);
	}

	#? scope_item(name: Stage::Name #&) [Stage]ScopeItem #? * := Members.scope_item(name);
	#? local(name: Stage::Name #&, pos: LocalPosition) [Stage]ScopeItem #? * := NULL;
}

::rlc::ast [Stage: TYPE] GlobalClass -> [Stage]Global, [Stage]Class
{
	:transform{
		p: [Stage::Prev+]GlobalClass #&,
		ctx: Stage::Context+ #&
	} -> (), (:transform, p, ctx);
}

::rlc::ast [Stage: TYPE] MemberClass -> [Stage]Member, [Stage]Class
{
	:transform{
		p: [Stage::Prev+]MemberClass #&,
		ctx: Stage::Context+ #&
	} -> (:transform, p), (:transform, p, ctx);
}