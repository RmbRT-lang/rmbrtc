INCLUDE "../parser/variable.rl"

INCLUDE "global.rl"
INCLUDE "member.rl"
INCLUDE "scopeitem.rl"

INCLUDE "type.rl"
INCLUDE "expression.rl"
INCLUDE "../util/dynunion.rl"

::rlc::scoper VariableType
{
	PRIVATE V: util::[Type, Type::Auto]DynUnion;
	CONSTRUCTOR();
	CONSTRUCTOR(t: Type \): V(t);
	CONSTRUCTOR(t: Type::Auto \): V(t);

	# is_type() INLINE bool := V.is_first();
	# type() INLINE Type \ := V.first();
	# is_auto() INLINE bool := V.is_second();
	# auto() Type::Auto \ := V.second();

	# CONVERT(bool) INLINE NOTYPE! := V;

	[T:TYPE] ASSIGN(v: T!&&) VariableType &
		:= std::help::custom_assign(*THIS, __cpp_std::[T!]forward(v));
}

::rlc::scoper Variable -> VIRTUAL ScopeItem
{
	Type: VariableType;
	HasInitialiser: bool;
	InitValues: std::[std::[Expression]Dynamic]Vector;

	CONSTRUCTOR(
		parsed: parser::Variable #\,
		file: src::File#&):
		HasInitialiser(parsed->HasInitialiser)
	{
		IF(parsed->Type.is_type())
			Type := scoper::Type::create(parsed->Type.type(), file);
		ELSE
			Type := ::[scoper::Type::Auto]new(*parsed->Type.auto());

		FOR(i ::= 0; i < parsed->InitValues.size(); i++)
			InitValues.push_back(Expression::create(parsed->InitValues[i], file));
	}
}

::rlc::scoper GlobalVariable -> Global, Variable
{
	# FINAL type() Global::Type := Global::Type::variable;
	
	CONSTRUCTOR(
		parsed: parser::GlobalVariable #\,
		file: src::File#&,
		group: detail::ScopeItemGroup \
	):	ScopeItem(group, parsed, file),
		Variable(parsed, file);
}

::rlc::scoper MemberVariable -> Member, Variable
{
	# FINAL type() Member::Type := Member::Type::variable;

	CONSTRUCTOR(
		parsed: parser::MemberVariable #\,
		file: src::File#&,
		group: detail::ScopeItemGroup \
	):	ScopeItem(group, parsed, file),
		Member(parsed),
		Variable(parsed, file);
}

::rlc::scoper LocalVariable -> VIRTUAL ScopeItem, Variable
{
	Position: UM;

	# FINAL category() ScopeItem::Category := ScopeItem::Category::local;

	CONSTRUCTOR(
		parsed: parser::LocalVariable #\,
		file: src::File#&,
		group: detail::ScopeItemGroup \
	):	ScopeItem(group, parsed, file),
		Variable(parsed, file);
}