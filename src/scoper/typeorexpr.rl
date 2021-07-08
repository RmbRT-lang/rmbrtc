INCLUDE "type.rl"
INCLUDE "expression.rl"

INCLUDE "../util/dynunion.rl"

::rlc::scoper TypeOrExpr
{
	PRIVATE V: util::[Expression; Type]DynUnion;

	{};
	{:gc, v: Expression \}: V(:gc(v));
	{:gc, v: Type \}: V(:gc(v));
	
	# is_type() INLINE BOOL := V.is_second();
	# type() Type \ := V.second();
	# is_expression() INLINE BOOL := V.is_first();
	# expression() INLINE Expression \ := V.first();

	# <BOOL> INLINE := V;
	# !THIS INLINE BOOL := !V;

	[T:TYPE] THIS:=(v: T!&&) TypeOrExpr &
		:= std::help::custom_assign(THIS, <T!&&>(v));
}