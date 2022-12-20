INCLUDE "variable.rl"
INCLUDE "expression.rl"
INCLUDE "symbol.rl"
INCLUDE "symbolconstant.rl"
INCLUDE "statement.rl"

INCLUDE 'std/vector'
INCLUDE 'std/memory'

::rlc::ast [Stage: TYPE] Constructor VIRTUAL ->
	[Stage]Member,
	[Stage]Templateable,
	CodeObject
{
	Initialisers VIRTUAL {
		<<<
			p: [Stage::Prev+]Constructor::Initialisers #&,
			ctx: Stage::Context+ #&
		>>> THIS - std::Dyn
		{
			TYPE SWITCH(p)
			{
			[Stage::Prev+]Constructor::ExplicitInits+:
				= :a.ExplicitInits(:transform(>>p, ctx));
			[Stage::Prev+]Constructor::CtorAlias+:
				= :a.CtorAlias(:transform(>>p, ctx));
			}
		}
	}

	BaseInit -> CodeObject
	{
		Arguments: [Stage]Expression - std::DynVec;

		:transform{
			p: [Stage::Prev+]Constructor::BaseInit+ #&,
			ctx: Stage::Context+ #&
		} -> (p):
			Arguments := :reserve(##p.Arguments)
		{
			FOR(a ::= p.Arguments.start())
				Arguments += :make(a!, ctx);
		}
	}

	MemberInit -> CodeObject
	{
		Member: Stage::MemberVariableReference;
		Arguments: [Stage]Expression - std::DynVec;

		:transform{
			p: [Stage::Prev+]Constructor::MemberInit+ #&,
			ctx: Stage::Context+ #&
		} -> (p):
			Member := ctx.transform_member_variable_reference(p.Member),
			Arguments := :reserve(##p.Arguments)
		{
			FOR(a ::= p.Arguments.start())
				Arguments += <<<[Stage]Expression>>>(a!, ctx);
		}
	}

	ExplicitInits -> Initialisers
	{
		BaseInits: BaseInit - std::Vec;
		MemberInits: MemberInit - std::Vec;

		:transform{
			p: [Stage::Prev+]Constructor::ExplicitInits+ #&,
			ctx: Stage::Context+ #&
		}:
			BaseInits := :reserve(##p.BaseInits),
			MemberInits := :reserve(##p.MemberInits)
		{
			FOR(i ::= p.BaseInits.start())
				BaseInits += :transform(i!, ctx);
			FOR(i ::= p.MemberInits.start())
				MemberInits += :transform(i!, ctx);
		}
	}

	CtorAlias -> Initialisers
	{
		Arguments: [Stage]Expression - std::DynVec;

		:transform{
			p: [Stage::Prev+]Constructor::CtorAlias+ #&,
			ctx: Stage::Context+ #&
		}:
			Arguments := :reserve(##p.Arguments)
		{
			FOR(a ::= p.Arguments.start())
				Arguments += :make(a!, ctx);
		}
	}

	Args: [Stage]ArgScope;
	Inits: Initialisers - std::DynOpt;
	Body: [Stage]BlockStatement - std::DynOpt;
	Inline: BOOL;

	:transform{
		p: [Stage::Prev+]Constructor #&,
		ctx: Stage::Context+ #&
	} -> (:transform, p), (:transform, p, ctx), (p):
		Args := :transform(p.Args,
			ctx.in_parent(&p.Templates, &THIS.Templates)),
		Inits := :make_if(p.Inits, p.Inits.ok(),
			ctx.in_parent(&p.Args, &THIS.Args)),
		Body := :if(p.Body, :transform(p.Body.ok(),
			ctx.in_parent(&p.Args, &THIS.Args))),
		Inline := p.Inline;

	<<<
		p: [Stage::Prev+]Constructor #&,
		ctx: Stage::Context+ #&
	>>> THIS - std::Dyn
	{
		TYPE SWITCH(p)
		{
		[Stage::Prev+]NullConstructor:
			= :a.[Stage]NullConstructor(:transform(>>p, ctx));
		[Stage::Prev+]BareConstructor:
			= :a.[Stage]BareConstructor(:transform(>>p, ctx));
		[Stage::Prev+]CustomConstructor:
			= :a.[Stage]CustomConstructor(:transform(>>p, ctx));
		[Stage::Prev+]DefaultConstructor:
			= :a.[Stage]DefaultConstructor(:transform(>>p, ctx));
		[Stage::Prev+]CopyConstructor:
			= :a.[Stage]CopyConstructor(:transform(>>p, ctx));
		[Stage::Prev+]MoveConstructor:
			= :a.[Stage]MoveConstructor(:transform(>>p, ctx));
		}
	}
}


::rlc::ast [Stage: TYPE] StructuralConstructor -> [Stage]Constructor
{
	:transform{
		p: [Stage::Prev+]StructuralConstructor #&,
		ctx: Stage::Context+ #&
	} -> (:transform, p, ctx);
}

::rlc::ast [Stage: TYPE] DefaultConstructor -> [Stage]Constructor
{
	:transform{
		p: [Stage::Prev+]DefaultConstructor #&,
		ctx: Stage::Context+ #&
	} -> (:transform, p, ctx);
}

::rlc::ast [Stage: TYPE] NullConstructor -> [Stage]Constructor
{
	:transform{
		p: [Stage::Prev+]NullConstructor #&,
		ctx: Stage::Context+ #&
	} -> (:transform, p, ctx);
}

::rlc::ast [Stage: TYPE] BareConstructor -> [Stage]Constructor
{
	:transform{
		p: [Stage::Prev+]BareConstructor #&,
		ctx: Stage::Context+ #&
	} -> (:transform, p, ctx);
}

::rlc::ast [Stage: TYPE] CopyConstructor -> [Stage]Constructor
{
	:named_arg{
		name: Stage::Name,
		pos: src::Position #&
	} -> (BARE) {
		THIS.Args += :a.[Stage]Argument(name, pos, :a.[Stage]ThisType(:cref));
	}
	:unnamed_arg{} -> (BARE) {
		THIS.Args += :a.[Stage]ThisType(:cref);
	}

	:transform{
		p: [Stage::Prev+]CopyConstructor #&,
		ctx: Stage::Context+ #&
	} -> (:transform, p, ctx) {
		ASSERT(##THIS.Args == 1);
	}
}

::rlc::ast [Stage: TYPE] MoveConstructor -> [Stage]Constructor
{
	:named_arg{
		name: Stage::Name,
		pos: src::Position #&
	} -> (BARE) {
		THIS.Args += :a.[Stage]Argument(name, pos, :a.[Stage]ThisType(:tempRef));
	}
	:unnamed_arg{} -> (BARE) {
		THIS.Args += :a.[Stage]ThisType(:tempRef);
	}

	:transform{
		p: [Stage::Prev+]MoveConstructor #&,
		ctx: Stage::Context+ #&
	} -> (:transform, p, ctx) {
		ASSERT(##THIS.Args == 1);
	}
}

::rlc::ast [Stage: TYPE] CustomConstructor -> [Stage]Constructor
{
	Name: [Stage]SymbolConstant - std::Opt;

	std::NoCopy;
	std::NoMove;


	# named() BOOL INLINE := Name;

	:transform{
		p: [Stage::Prev+]CustomConstructor #&,
		ctx: Stage::Context+ #&
	} -> (:transform, p, ctx)
	{
		IF(p.Name)
			Name := :a(:transform(p.Name!,
				ctx.in_parent(&p.Templates, &THIS.Templates)));

		ASSERT(Name || ##THIS.Args != 0);
	}

	# THIS <>(rhs: THIS#&) S1 := Name <> rhs.Name;
}