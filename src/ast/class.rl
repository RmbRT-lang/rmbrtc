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
		f: Stage::PrevFile+,
		s: Stage &,
		parent: [Stage]ScopeBase \
	} -> (p):
		Visibility := p.Visibility,
		IsVirtual := p.IsVirtual,
		Type := :transform(p.Type, f, s, parent);

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
		f: Stage::PrevFile+,
		s: Stage &,
		parent: [Stage]ScopeBase \
	}:
		Functions := :reserve(##p.Functions),
		Converter := :if(p.Converter, :transform(p.Converter.ok(), f, s, parent)),
		Operators := :reserve(##p.Operators),
		Factory := :if(p.Factory, :transform(p.Factory.ok(), f, s, parent))
	{
		FOR(fn ::= p.Functions.start())
			Functions += :transform(fn!, f, s, parent);
		FOR(o ::= p.Operators.start())
			Operators += :transform(o!, f, s, parent);
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
}

::rlc::ast [Stage: TYPE] Fields
{
	NamedVars: [Stage]MemberScope;
	AnonVars: [Stage]AnonMemberVariable - std::Vec;

	{parent: [Stage]ScopeBase \}: NamedVars := :childOf(parent);

	:transform{
		p: [Stage::Prev+]Fields #&,
		f: Stage::PrevFile+,
		s: Stage &,
		parent: [Stage]ScopeBase \
	}:
		NamedVars := :childOf(parent),
		AnonVars := :reserve(##p.AnonVars)
	{
		FOR(m ::= p.NamedVars.start())
			NamedVars.insert(:make(m!.Value!, f, s, parent));

		FOR(v ::= p.AnonVars.start())
			AnonVars += :transform(v!, f, s, parent);
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
		f: Stage::PrevFile+,
		s: Stage &,
		parent: [Stage]ScopeBase \
	}:
		StructuralCtor:= :if(p.StructuralCtor,
			:transform(p.StructuralCtor.ok(), f, s, parent)),
		DefaultCtor := :if(p.DefaultCtor,
				:transform(p.DefaultCtor.ok(), f, s, parent)),
		CopyCtor := :if(p.CopyCtor,
			:transform(p.CopyCtor.ok(), f, s, parent)),
		MoveCtor := :if(p.MoveCtor,
			:transform(p.MoveCtor.ok(), f, s, parent)),
		NullCtor := :if(p.NullCtor,
			:transform(p.NullCtor.ok(), f, s, parent)),
		BareCtor := :if(p.BareCtor,
			:transform(p.BareCtor.ok(), f, s, parent)),
		ImplicitCtor := :if(p.ImplicitCtor,
			:transform(p.ImplicitCtor.ok(), f, s, parent)),
		CustomCtors := :reserve(##p.CustomCtors)
	{
		FOR(ctor ::= p.CustomCtors.start())
			CustomCtors += :transform(ctor!, f, s, parent);
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
		f: Stage::PrevFile+,
		s: Stage &,
		parent: [Stage]ScopeBase \
	} -> (:childOf, parent):
		Ctors := :transform(p.Ctors, f, s, &THIS),
		Statics := :transform(p.Statics, f, s, &THIS),
		Fields := :if(p.Fields, :transform(p.Fields.ok(), f, s, &THIS)),
		Functions := :if(p.Functions, :transform(p.Functions.ok(), f, s, &THIS)),
		Destructor := :if(p.Destructor, :transform(p.Destructor.ok(), f, s, &THIS));

	THIS += (member: [Stage]Member - std::Dyn) VOID
	{
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
	[Stage]Templateable
{
	Virtual: BOOL;
	Inheritances: class::[Stage]Inheritance - std::Vec;

	Members: [Stage]ClassMembers;

	:transform{
		p: [Stage::Prev+]Class #&,
		f: Stage::PrevFile+,
		s: Stage &,
		parent: [Stage]ScopeBase \
	} -> (:transform, p, f, s), (:transform, p, f, s, &THIS):
		Virtual := p.Virtual,
		Inheritances := :reserve(##p.Inheritances),
		Members := :transform(p.Members, f, s, &THIS)
	{
		FOR(i ::= p.Inheritances.start())
			Inheritances += :transform(i!, f, s, parent);
	}
}

::rlc::ast [Stage: TYPE] GlobalClass -> [Stage]Global, [Stage]Class
{
	:transform{
		p: [Stage::Prev+]GlobalClass #&,
		f: Stage::PrevFile+,
		s: Stage &,
		parent: [Stage]ScopeBase \
	} -> (), (:transform, p, f, s, parent);
}

::rlc::ast [Stage: TYPE] MemberClass -> [Stage]Member, [Stage]Class
{
	:transform{
		p: [Stage::Prev+]MemberClass #&,
		f: Stage::PrevFile+,
		s: Stage &,
		parent: [Stage]ScopeBase \
	} -> (:transform, p), (:transform, p, f, s, parent);
}