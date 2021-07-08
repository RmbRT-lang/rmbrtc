INCLUDE "../parser/variable.rl"

INCLUDE "global.rl"
INCLUDE "member.rl"
INCLUDE "scopeitem.rl"

INCLUDE "type.rl"
INCLUDE "expression.rl"
INCLUDE "../util/dynunion.rl"

::rlc::scoper VariableType
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

::rlc::scoper Variable VIRTUAL -> ScopeItem
{
	# FINAL type() ScopeItem::Type := :variable;

	Type: VariableType;
	HasInitialiser: BOOL;
	InitValues: std::[std::[Expression]Dynamic]Vector;

	{
		group: detail::ScopeItemGroup \,
		parsed: parser::Variable #\,
		file: src::File#&
	}:	ScopeItem(group, parsed, file),
		HasInitialiser(parsed->HasInitialiser)
	{
		IF(parsed->Type.is_type())
			Type := :gc(scoper::Type::create(parsed->Type.type(), file));
		ELSE
			Type := :gc(std::[scoper::Type::Auto]new(*parsed->Type.auto()));

		FOR(i ::= 0; i < ##parsed->InitValues; i++)
			InitValues += :gc(Expression::create(parsed->InitValues[i], file));
	}
}

::rlc::scoper GlobalVariable -> Global, Variable
{
	{
		parsed: parser::GlobalVariable #\,
		file: src::File#&,
		group: detail::ScopeItemGroup \
	}:	Variable(group, parsed, file);
}

::rlc::scoper MemberVariable -> Member, Variable
{
	{
		parsed: parser::MemberVariable #\,
		file: src::File#&,
		group: detail::ScopeItemGroup \
	}:	Member(parsed),
		Variable(group, parsed, file);
}

::rlc::scoper LocalVariable -> Variable
{
	Position: UM;

	{
		parsed: parser::LocalVariable #\,
		file: src::File#&,
		group: detail::ScopeItemGroup \
	}:	Variable(group, parsed, file);

	set_position(position: UM) VOID
	{
		Position := position;
		FOR(it ::= Variable::InitValues.start(); it; ++it)
			(*it)->Position := position;
	}
}