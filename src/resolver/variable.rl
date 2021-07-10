INCLUDE "../scoper/variable.rl"
INCLUDE "global.rl"
INCLUDE "member.rl"
INCLUDE "type.rl"
INCLUDE "../util/dynunion.rl"

::rlc::resolver
{
	VariableType
	{
		PRIVATE V: util::[Type; Type::Auto]DynUnion;
		{};
		{:gc, t: Type \}: V(:gc(t));
		{:gc, t: Type::Auto \}: V(:gc(t));

		# is_type() INLINE BOOL := V.is_first();
		# type() INLINE Type \ := V.first();
		# is_auto() INLINE BOOL := V.is_second();
		# auto() Type::Auto \ := V.second();

		# <BOOL> INLINE := V;

		[T:TYPE] THIS:=(v: T!&&) VariableType &
			:= std::help::custom_assign(THIS, <T!&&>(v));
	}

	Variable VIRTUAL -> ScopeItem
	{
		# FINAL type() ScopeItem::Type := :variable;

		Type: VariableType;
		HasInitialiser: BOOL;
		InitValues: Expression - std::Dynamic - std::Vector;

		{
			v: scoper::Variable #\,
			cache: Cache &
		}->	ScopeItem(v, cache)
		:	HasInitialiser(v->HasInitialiser)
		{
			scope ::= v->parent_scope();
			IF(v->Type.is_type())
				Type := :gc(resolver::Type::create(scope, v->Type.type()));
			ELSE
				Type := :gc(std::[resolver::Type::Auto]new(*v->Type.auto()));

			FOR(it ::= v->InitValues.start(); it; ++it)
				InitValues += :gc(Expression::create(scope, *it));
		}
	}

	GlobalVariable -> Global, Variable
	{
		{
			v: scoper::GlobalVariable #\,
			cache: Cache &
		}->	Variable(v, cache);
	}

	MemberVariable -> Member, Variable
	{
		{
			v: scoper::MemberVariable #\,
			cache: Cache &
		}->	Member(v),
			Variable(v, cache);
	}

	LocalVariable -> Variable
	{
		Position: UM;

		{
			local: scoper::LocalVariable #\,
			cache: Cache &
		}->	Variable(local, cache)
		:	Position(local->Position);
	}
}