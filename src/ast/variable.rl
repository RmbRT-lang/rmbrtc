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
		{};
		{ name: Stage::Name } -> (&&name);
	}

	(//
		Variables initialised upon declaration (including default init).
		These variables all generate a constructor call.
	/)
	[Stage:TYPE] InitialisedVariable VIRTUAL -> [Stage]Variable
	{
		Type: [Stage]MaybeAutoType - std::Dyn;
		InitValues: Stage-Expression - std::DynVec;
		
		{};
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
	}

	(//
		A variable without an initialiser (including NOINIT).
		These variables do not emit a constructor call upon declaration.
	/)
	[Stage:TYPE] UninitialisedVariable VIRTUAL -> [Stage]Variable
	{
		Type: ast::[Stage]Type - std::Dyn;

		{};
		{
			name: Stage::Name,
			type: ast::[Stage]Type-std::Dyn
		} ->
			(&&name):
			Type(&&type);
	}

	/// A variable in global scope.
	[Stage:TYPE] GlobalVariable -> [Stage]Global, [Stage]InitialisedVariable
	{
		{};
		{
			name: Stage::Name,
			type: [Stage]MaybeAutoType - std::Dyn,
			initValues: [Stage]Expression - std::DynVec
		} -> (), (&&name, &&type, &&initValues);
	}

	[Stage: TYPE] ExternVariable ->
		[Stage]Global,
		[Stage]UninitialisedVariable,
		[Stage]ExternSymbol
	{
		{};
		{
			name: Stage::Name,
			type: [Stage]Type - std::Dyn,
			linkName: Stage-Name - std::Opt
		} -> (), (&&name, &&type), (&&linkName);
	}

	[Stage: TYPE] MaybeAnonMemberVar VIRTUAL -> [Stage]Member {}
	/// Member variable of a class or union.
	[Stage:TYPE] MemberVariable ->
		[Stage]UninitialisedVariable,
		[Stage]MaybeAnonMemberVar
	{
		{};
		{
			name: Stage::Name,
			type: [Stage]Type - std::Dyn
		} -> (&&name, &&type), ();
	}

	[Stage:TYPE] AnonMemberVariable -> [Stage]MaybeAnonMemberVar
	{
		Type: ast::[Stage]Type - std::Dyn;
		{};
		{type: ast::[Stage]Type - std::Dyn}: Type(&&type);
	}

	[Stage:TYPE] StaticMemberVariable ->
		[Stage]MaybeAnonMemberVar,
		[Stage]InitialisedVariable
	{
		{};
		{
			name: Stage::Name,
			type: [Stage]Type-std::Dyn,
			inits: [Stage]Expression - std::DynVec
		}-> (), (&&name, &&type, &&inits);

	}

	TYPE LocalPosition := U2;
	/// A function-local entity whose visibility depends on order of occurrence.
	[Stage:TYPE] Local VIRTUAL
	{
		Position: LocalPosition;

		{};
		{pos: LocalPosition}: Position(pos) { ASSERT(pos > 0); }
		:arg{}: Position(0);

		<<<
			g: [Stage::Prev+]Local #&,
			ctx: Stage::Context+ &
		>>> THIS - std::Dyn;

	}

	/// A named function or constructor argument.
	[Stage:TYPE] Argument ->
		[Stage]Local,
		[Stage]UninitialisedVariable,
		[Stage]TypeOrArgument
	{
		{};
		{
			name: Stage::Name,
			type: [Stage]Type-std::Dyn
		} -> (:arg), (&&name, &&type), ();
	}

	/// A local variable inside a function.
	[Stage:TYPE] LocalVariable ->
		[Stage]Local,
		[Stage]InitialisedVariable,
		[Stage]VarOrExpr
	{
		{};
		{
			name: Stage::Name,
			position: LocalPosition,
			type: [Stage]MaybeAutoType-std::Dyn,
			initValues: [Stage]Expression-std::DynVec
		} -> (position), (&&name, &&type, &&initValues), ();
	}

	/// The named exception variable of a CATCH statement.
	[Stage:TYPE] CatchVariable ->
		[Stage]Local,
		[Stage]UninitialisedVariable,
		[Stage]TypeOrCatchVariable
	{
		{};
		{
			name: Stage::Name,
			position: LocalPosition,
			type: [Stage]MaybeAutoType-std::Dyn
		} -> (position), (&&name, &&type), ();
	}
}