INCLUDE "type.rl"
INCLUDE "expression.rl"
INCLUDE "global.rl"
INCLUDE "member.rl"
INCLUDE "scopeitem.rl"

INCLUDE 'std/memory'
INCLUDE 'std/vector'

::rlc::ast
{
	[Stage:TYPE] Variable VIRTUAL -> [Stage]ScopeItem
	{
		{ name: Stage::Name } -> (&&name);
	}

	[Stage:TYPE] InitialisedVariable VIRTUAL -> [Stage]Variable
	{
		Type: [Stage]MaybeAutoType - std::Dyn;
		InitValues: Stage-Expression - std::DynVector;
		
		{
			name: Stage::Name,
			type: [Stage]MaybeAutoType - std::Dyn,
			initValues: [Stage]Expression - std::DynVector
		} ->
			(&&name):
			Type(&&type),
			InitValues(&&initValues)
		{
			// Make sure that an auto variable has a single-value initialiser.
			ASSERT(!<<Stage-type::Auto>>(Type!) || ##InitValues == 1);
		}
	}

	[Stage:TYPE] UninitialisedVariable VIRTUAL -> [Stage]Variable
	{
		Type: ast::[Stage]Type - std::Dyn;

		{
			name: Stage::Name,
			type: ast::[Stage]Type-std::Dyn
		} ->
			(&&name):
			Type(&&type);
	}

	[Stage:TYPE] GlobalVariable -> [Stage]Global, [Stage]InitialisedVariable
	{
		{
			name: Stage::Name,
			type: [Stage]MaybeAutoType - std::Dyn,
			initValues: [Stage]Expression - std::DynVector
		} -> (), (&&name, &&type, &&initValues);
	}

	[Stage:TYPE] MemberVariable -> [Stage]Member, [Stage]UninitialisedVariable
	{
		{
			name: Stage::Name,
			type: [Stage]Type - std::Dyn
		} -> (), (&&name, &&type);
	}

	TYPE LocalPosition := U2;
	/// A function-local entity whose visibility depends on order of occurrence.
	[Stage:TYPE] Local VIRTUAL
	{
		Position: LocalPosition;

		{pos: LocalPosition}: Position(pos) { ASSERT(pos > 0); }
		:arg{}: Position(0);
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
	}

	/// A local variable inside a function.
	[Stage:TYPE] LocalVariable ->
		[Stage]Local,
		[Stage]InitialisedVariable
	{
		{
			name: Stage::Name,
			position: LocalPosition,
			type: [Stage]MaybeAutoType-std::Dyn,
			initValues: [Stage]Expression-std::DynVector
		} -> (position), (&&name, &&type, &&initValues);
	}
}