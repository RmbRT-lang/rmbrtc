INCLUDE "scopeitem.rl"
INCLUDE "global.rl"
INCLUDE "member.rl"

::rlc::instantiator
{
	Variable VIRTUAL -> ScopeItem
	{
		Type: instantiator::Type #\;
		InitValues: Expression - std::DynVector;

		{res: resolver::Variable #\, scope: Scope #&}:
			Type(res->VariableType),
			InitValues(:reserve(##res->InitValues))
		{
			FOR(v ::= res->InitValues.start(:ok); v; ++v)
				InitValues += :gc(<<<Expression>>>(v!, scope));
		}
	}

	GlobalVariable -> Global, Variable
	{
		{res: resolver::GlobalVariable, scope: Scope #&}
			->	Variable(res, scope);
	}

	MemberVariable -> Member, Variable
	{
		{res: resolver::MemberVariable, scope: Scope #&}
			->	Member(res),
				Variable(res, scope);
	}

	LocalVariable -> Variable
	{
		Position: UM;
		{res: resolver::LocalVariable #\, scope: Scope #&}
			->	Variable(res, scope)
			:	Position(res->Position);
	}
}