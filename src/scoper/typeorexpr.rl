INCLUDE "type.rl"
INCLUDE "expression.rl"

INCLUDE "../util/dynunion.rl"

::rlc::scoper TypeOrExpr
{
	PRIVATE V: util::[Expression, Type]DynUnion;

	{};
	{v: Expression \}: V(v);
	{v: Type \}: V(v);
	
	# is_type() INLINE bool := V.is_second();
	# type() Type \ := V.second();
	# is_expression() INLINE bool := V.is_first();
	# expression() INLINE bool := V.first();

	# <bool> INLINE := V;
	# !THIS INLINE bool := !V;

	[T:TYPE] THIS:=(v: T!&&) TypeOrExpr &
		:= std::help::custom_assign(THIS, <T!&&>(v));
}