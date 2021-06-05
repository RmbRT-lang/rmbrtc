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
	{t: Type \}: V(t);
	{t: Type::Auto \}: V(t);

	# is_type() INLINE BOOL := V.is_first();
	# type() INLINE Type \ := V.first();
	# is_auto() INLINE BOOL := V.is_second();
	# auto() Type::Auto \ := V.second();

	# <BOOL> INLINE := V;

	[T:TYPE] THIS:=(v: T!&&) VariableType &
		:= std::help::custom_assign(THIS, <T!&&>(v));
}

::rlc::scoper Variable -> VIRTUAL ScopeItem
{
	Type: VariableType;
	HasInitialiser: BOOL;
	InitValues: std::[std::[Expression]Dynamic]Vector;

	{
		parsed: parser::Variable #\,
		file: src::File#&}:
		HasInitialiser(parsed->HasInitialiser)
	{
		IF(parsed->Type.is_type())
			Type := scoper::Type::create(parsed->Type.type(), file);
		ELSE
			Type := std::[scoper::Type::Auto]new(*parsed->Type.auto());

		FOR(i ::= 0; i < ##parsed->InitValues; i++)
			InitValues += :gc(Expression::create(parsed->InitValues[i], file));
	}
}

::rlc::scoper GlobalVariable -> Global, Variable
{
	# FINAL type() Global::Type := :variable;
	
	{
		parsed: parser::GlobalVariable #\,
		file: src::File#&,
		group: detail::ScopeItemGroup \
	}:	ScopeItem(group, parsed, file),
		Variable(parsed, file);
}

::rlc::scoper MemberVariable -> Member, Variable
{
	# FINAL type() Member::Type := :variable;

	{
		parsed: parser::MemberVariable #\,
		file: src::File#&,
		group: detail::ScopeItemGroup \
	}:	ScopeItem(group, parsed, file),
		Member(parsed),
		Variable(parsed, file);
}

::rlc::scoper LocalVariable -> VIRTUAL ScopeItem, Variable
{
	Position: UM;

	# FINAL category() ScopeItem::Category := ScopeItem::Category::local;

	{
		parsed: parser::LocalVariable #\,
		file: src::File#&,
		group: detail::ScopeItemGroup \
	}:	ScopeItem(group, parsed, file),
		Variable(parsed, file);

	set_position(position: UM) VOID
	{
		Position := position;
		FOR(it ::= InitValues.start(); it; ++it)
			(*it)->Position := position;
	}
}