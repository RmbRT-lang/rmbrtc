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

	Inits: Initialisers - std::DynOpt;
	Body: [Stage]BlockStatement - std::DynOpt;
	Inline: BOOL;

	:transform{
		p: [Stage::Prev+]Constructor #&,
		ctx: Stage::Context+ #&
	} -> (:transform, p), (:transform, p, ctx), (p):
		Inits := :make_if(p.Inits, p.Inits.ok(), ctx),
		Body := :if(p.Body, :transform(p.Body.ok(), ctx)),
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
	Argument: ast::[Stage]Argument-std::Opt;

	:named_arg{
		name: Stage::Name
	} -> (BARE): Argument := :a(name, :a.[Stage]ThisType(:cref));
	:unnamed_arg{} -> (BARE);

	:transform{
		p: [Stage::Prev+]CopyConstructor #&,
		ctx: Stage::Context+ #&
	} -> (:transform, p, ctx)
	{
		IF(p.Argument)
			Argument := :a(:transform(p.Argument!, ctx));
	}
}

::rlc::ast [Stage: TYPE] MoveConstructor -> [Stage]Constructor
{
	Argument: ast::[Stage]Argument-std::Opt;

	{};
	:named_arg{
		name: Stage::Name
	} -> (BARE): Argument(:a(name, :gc(std::heap::[[Stage]ThisType]new(:tempRef))));
	:unnamed_arg{} -> (BARE);

	:transform{
		p: [Stage::Prev+]MoveConstructor #&,
		ctx: Stage::Context+ #&
	} -> (:transform, p, ctx)
	{
		IF(p.Argument)
			Argument := :a(:transform(p.Argument!, ctx));
	}
}

::rlc::ast [Stage: TYPE] CustomConstructor -> [Stage]Constructor
{
	Name: [Stage]SymbolConstant - std::Opt;
	Arguments: [Stage]TypeOrArgument - std::DynVec;

	# named() BOOL INLINE := Name;

	:transform{
		p: [Stage::Prev+]CustomConstructor #&,
		ctx: Stage::Context+ #&
	} -> (:transform, p, ctx):
		Arguments := :reserve(##p.Arguments)
	{
		IF(p.Name)
			Name := :a(:transform(p.Name!, ctx));

		FOR(a ::= p.Arguments.start())
			Arguments += :make(a!, ctx);
	}

	# THIS <>(rhs: THIS#&) S1 := Name <> rhs.Name;
}