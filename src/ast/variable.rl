INCLUDE "type.rl"
INCLUDE "expression.rl"
INCLUDE "global.rl"
INCLUDE "member.rl"
INCLUDE "scopeitem.rl"
INCLUDE "varorexpression.rl"

INCLUDE 'std/memory'
INCLUDE 'std/vector'

::rlc::ast
{
	/// Generic named variable.
	[Stage:TYPE] Variable VIRTUAL -> [Stage]ScopeItem
	{
		{ name: Stage::Name } -> (&&name, NULL);

		:transform{
			p: [Stage::Prev+]Variable #&,
			ctx: Stage::Context+ #&
		} -> (:transform, p, ctx);
	}

	(//
		Variables initialised upon declaration (including default init).
		These variables all generate a constructor call.
	/)
	[Stage:TYPE] InitialisedVariable VIRTUAL -> [Stage]Variable
	{
		Type: [Stage]MaybeAutoType - std::Dyn;
		InitValues: Stage-Expression - std::DynVec;

		{
			name: Stage::Name,
			type: [Stage]MaybeAutoType - std::Dyn,
			initValues: [Stage]Expression - std::DynVec
		} ->
			(&&name):
			Type(&&type),
			InitValues(&&initValues)
		{
			// Make sure that an auto variable has a single-value initialiser.
			ASSERT(!<<Stage-type::Auto *>>(Type) || ##InitValues == 1);
		}

		:transform{
			p: [Stage::Prev+]InitialisedVariable #&,
			ctx: Stage::Context+ #&
		} -> (:transform, p, ctx) :
			Type := :make(p.Type!, ctx),
			InitValues := :reserve(##p.InitValues)
		{
			FOR(v ::= p.InitValues.start())
				InitValues += :make(v!, ctx);
		}
	}

	(//
		A variable without an initialiser (including NOINIT).
		These variables do not emit a constructor call upon declaration.
	/)
	[Stage:TYPE] UninitialisedVariable VIRTUAL -> [Stage]Variable
	{
		Type: ast::[Stage]Type - std::Dyn;

		{
			name: Stage::Name,
			type: ast::[Stage]Type-std::Dyn
		} ->
			(&&name):
			Type(&&type);

		:transform{
			p: [Stage::Prev+]UninitialisedVariable #&,
			ctx: Stage::Context+ #&
		} -> (:transform, p, ctx):
			Type := :make(p.Type!, ctx);
	}

	/// A variable in global scope.
	[Stage:TYPE] GlobalVariable -> [Stage]Global, [Stage]InitialisedVariable
	{
		{
			name: Stage::Name,
			type: [Stage]MaybeAutoType - std::Dyn,
			initValues: [Stage]Expression - std::DynVec
		} -> (), (&&name, &&type, &&initValues);

		:transform{
			p: [Stage::Prev+]GlobalVariable #&,
			ctx: Stage::Context+ #&
		} -> (), (:transform, p, ctx);
	}

	[Stage: TYPE] ExternVariable ->
		[Stage]Global,
		[Stage]UninitialisedVariable,
		[Stage]ExternSymbol
	{
		{
			name: Stage::Name,
			type: [Stage]Type - std::Dyn,
			linkName: Stage::StringLiteral+ - std::Opt
		} -> (), (&&name, &&type), (&&linkName);

		:transform{
			p: [Stage::Prev+]ExternVariable #&,
			ctx: Stage::Context+ #&
		} -> (), (:transform, p, ctx), (:transform, p, ctx);
	}

	[Stage: TYPE] MaybeAnonMemberVar VIRTUAL -> [Stage]Member
	{
		<<<
			p: [Stage::Prev+]MaybeAnonMemberVar #&,
			ctx: Stage::Context+ #&
		>>> THIS-std::Dyn
		{
			TYPE SWITCH(p)
			{
			[Stage::Prev+]MemberVariable:
				= :a.[Stage]MemberVariable(:transform(
					<<[Stage::Prev+]MemberVariable #&>>(p), ctx));
			[Stage::Prev+]AnonMemberVariable:
				= :a.[Stage]AnonMemberVariable(:transform(
					<<[Stage::Prev+]AnonMemberVariable #&>>(p), ctx));
			[Stage::Prev+]StaticMemberVariable:
				= :a.[Stage]StaticMemberVariable(:transform(
					<<[Stage::Prev+]StaticMemberVariable #&>>(p), ctx));
			}
		}

		:transform{
			p: [Stage::Prev+]MaybeAnonMemberVar #&
		} -> (:transform, p);
	}

	/// Member variable of a class or union.
	[Stage:TYPE] MemberVariable ->
		[Stage]UninitialisedVariable,
		[Stage]MaybeAnonMemberVar
	{
		:transform{
			p: [Stage::Prev+]MemberVariable #&,
			ctx: Stage::Context+ #&
		} -> (:transform, p, ctx), (:transform, p);
	}

	[Stage:TYPE] AnonMemberVariable -> [Stage]MaybeAnonMemberVar
	{
		Type: ast::[Stage]Type - std::Dyn;

		:transform{
			p: [Stage::Prev+]AnonMemberVariable #&,
			ctx: Stage::Context+ #&
		} -> (:transform, p):
			Type := :make(p.Type!, ctx);
	}

	[Stage:TYPE] StaticMemberVariable ->
		[Stage]MaybeAnonMemberVar,
		[Stage]InitialisedVariable
	{
		{
			name: Stage::Name,
			type: [Stage]Type-std::Dyn,
			inits: [Stage]Expression - std::DynVec
		}-> (), (&&name, &&type, &&inits);

		:transform{
			p: [Stage::Prev+]StaticMemberVariable #&,
			ctx: Stage::Context+ #&
		} -> (:transform, p), (:transform, p, ctx);
	}

	TYPE LocalPosition := U2; /// Local variable index.
	TYPE LocalCount := U2; /// Number of local variables.

	/// A function-local entity whose visibility depends on order of occurrence.
	[Stage:TYPE] Local VIRTUAL
	{
		Position: LocalPosition;

		{pos: LocalPosition}: Position(pos) { ASSERT(pos > 0); }
		:arg{}: Position(0);

		:transform{p: [Stage::Prev+]Local #&}: Position := p.Position;

		<<<
			g: [Stage::Prev+]Local #&,
			ctx: Stage::Context+ #&
		>>> THIS - std::Dyn
		{
			TYPE SWITCH(g)
			{
			[Stage::Prev+]Argument:
				= :a.[Stage]Argument(:transform(>>g, ctx));
			[Stage::Prev+]LocalVariable:
				= :a.[Stage]LocalVariable(:transform(>>g, ctx));
			[Stage::Prev+]CatchVariable:
				= :a.[Stage]CatchVariable(:transform(>>g, ctx));
			}
		}
	}

	/// A named function or constructor argument.
	[Stage:TYPE] Argument ->
		[Stage]Local,
		[Stage]UninitialisedVariable,
		[Stage]TypeOrArgument
	{
		{
			name: Stage::Name,
			type: [Stage]Type-std::Dyn
		} -> (:arg), (&&name, &&type), ();

		:transform{
			p: [Stage::Prev+]Argument #&,
			ctx: Stage::Context+ #&
		} -> (:arg), (:transform, p, ctx), ();
	}

	/// A local variable inside a function.
	[Stage:TYPE] LocalVariable ->
		[Stage]Local,
		[Stage]InitialisedVariable,
		[Stage]VarOrExpr
	{
		{
			name: Stage::Name,
			position: LocalPosition,
			type: [Stage]MaybeAutoType-std::Dyn,
			initValues: [Stage]Expression-std::DynVec
		} -> (position), (&&name, &&type, &&initValues), ();

		:transform{
			p: [Stage::Prev+]LocalVariable #&,
			ctx: Stage::Context+ #&
		} -> (:transform, p), (:transform, p, ctx), ();
	}

	/// The named exception variable of a CATCH statement.
	[Stage:TYPE] CatchVariable ->
		[Stage]Local,
		[Stage]UninitialisedVariable,
		[Stage]TypeOrCatchVariable
	{
		{
			name: Stage::Name,
			position: LocalPosition,
			type: [Stage]Type-std::Dyn
		} -> (position), (&&name, &&type), ();

		:transform{
			p: [Stage::Prev+]CatchVariable #&,
			ctx: Stage::Context+ #&
		} -> (:transform, p), (:transform, p, ctx), ();
	}
}