INCLUDE "type.rl"
INCLUDE "expression.rl"

INCLUDE "../util/dynunion.rl"

::rlc::scoper TypeOrExpr
{
	PRIVATE V: util::[Expression, Type]DynUnion;

	{};
	{v: Expression \}: V(v);
	{v: Type \}: V(v);
	
	# is_type() INLINE BOOL := V.is_second();
	# type() Type \ := V.second();
	# is_expression() INLINE BOOL := V.is_first();
	# expression() INLINE bool := V.first();

	# <BOOL> INLINE := V;
	# !THIS INLINE BOOL := !V;

	[T:TYPE] THIS:=(v: T!&&) TypeOrExpr &
		:= std::help::custom_assign(THIS, <T!&&>(v));
}