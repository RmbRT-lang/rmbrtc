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
			f: Stage::PrevFile+,
			s: Stage &
		} -> (:transform, p, f, s);
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
			ASSERT(!<<Stage-type::Auto *>>(Type!) || ##InitValues == 1);
		}

		:transform{
			p: [Stage::Prev+]InitialisedVariable #&,
			f: Stage::PrevFile+,
			s: Stage &
		} -> (:transform, p, f, s) :
			Type := <<<[Stage]MaybeAutoType>>>(p.Type!, f, s),
			InitValues := :reserve(##p.InitValues)
		{
			FOR(v ::= p.InitValues.start())
				InitValues += <<<[Stage]Expression>>>(v!, f, s);
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
			f: Stage::PrevFile+,
			s: Stage &
		} -> (:transform, p, f, s):
			Type := <<<ast::[Stage]Type>>>(p.Type!, f, s);
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
			f: Stage::PrevFile+,
			s: Stage &
		} -> (), (:transform, p, f, s);
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
			f: Stage::PrevFile+,
			s: Stage &
		} -> (), (:transform, p, f, s), (:transform, p, f, s);
	}

	[Stage: TYPE] MaybeAnonMemberVar VIRTUAL -> [Stage]Member
	{
		<<<
			p: [Stage::Prev+]MaybeAnonMemberVar #\,
			f: Stage::PrevFile+,
			s: Stage &
		>>> THIS-std::Dyn
		{
			TYPE SWITCH(p)
			{
			[Stage::Prev+]MemberVariable:
				= :dup(<[Stage]MemberVariable>(:transform(
					<<[Stage::Prev+]MemberVariable #&>>(*p), f, s)));
			[Stage::Prev+]AnonMemberVariable:
				= :dup(<[Stage]AnonMemberVariable>(:transform(
					<<[Stage::Prev+]AnonMemberVariable #&>>(*p), f, s)));
			[Stage::Prev+]StaticMemberVariable:
				= :dup(<[Stage]StaticMemberVariable>(:transform(
					<<[Stage::Prev+]StaticMemberVariable #&>>(*p), f, s)));
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
			f: Stage::PrevFile+,
			s: Stage &
		} -> (:transform, p, f, s), (:transform, p);
	}

	[Stage:TYPE] AnonMemberVariable -> [Stage]MaybeAnonMemberVar
	{
		Type: ast::[Stage]Type - std::Dyn;

		:transform{
			p: [Stage::Prev+]AnonMemberVariable #&,
			f: Stage::PrevFile+,
			s: Stage &
		} -> (:transform, p):
			Type := <<<ast::[Stage]Type>>>(p.Type!, f, s);
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
			f: Stage::PrevFile+,
			s: Stage &
		} -> (:transform, p), (:transform, p, f, s);
	}

	TYPE LocalPosition := U2;
	/// A function-local entity whose visibility depends on order of occurrence.
	[Stage:TYPE] Local VIRTUAL
	{
		Position: LocalPosition;

		{pos: LocalPosition}: Position(pos) { ASSERT(pos > 0); }
		:arg{}: Position(0);

		:transform{p: [Stage::Prev+]Local #&}: Position := p.Position;

		<<<
			g: [Stage::Prev+]Local #\,
			f: Stage::PrevFile+,
			s: Stage &
		>>> THIS - std::Dyn
		{
			TYPE SWITCH(g)
			{
			[Stage::Prev+]Argument:
				= :dup(<[Stage]Argument>(:transform(
					<<[Stage::Prev+]Argument #&>>(*g), f, s)));
			[Stage::Prev+]LocalVariable:
				= :dup(<[Stage]LocalVariable>(:transform(
					<<[Stage::Prev+]LocalVariable #&>>(*g), f, s)));
			[Stage::Prev+]CatchVariable:
				= :dup(<[Stage]CatchVariable>(:transform(
					<<[Stage::Prev+]CatchVariable #&>>(*g), f, s)));
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
			f: Stage::PrevFile+,
			s: Stage &
		} -> (:arg), (:transform, p, f, s), ();
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
			f: Stage::PrevFile+,
			s: Stage &
		} -> (:transform, p), (:transform, p, f, s), ();
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
			type: [Stage]MaybeAutoType-std::Dyn
		} -> (position), (&&name, &&type), ();

		:transform{
			p: [Stage::Prev+]CatchVariable #&,
			f: Stage::PrevFile+,
			s: Stage &
		} -> (:transform, p), (:transform, p, f, s), ();
	}
}