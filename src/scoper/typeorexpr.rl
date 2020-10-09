INCLUDE "type.rl"
INCLUDE "expression.rl"

INCLUDE "../util/dynunion.rl"

::rlc::scoper TypeOrExpr
{
	PRIVATE V: util::[Expression, Type]DynUnion;

	CONSTRUCTOR();
	CONSTRUCTOR(v: Expression \): V(v);
	CONSTRUCTOR(v: Type \): V(v);
	
	# is_type() INLINE bool := V.is_second();
	# type() Type \ := V.second();
	# is_expression() INLINE bool := V.is_first();
	# expression() INLINE bool := V.first();

	# CONVERT(bool) INLINE NOTYPE! := V;
	# LOG_NOT() INLINE bool := !V;

	[T:TYPE] ASSIGN(v: T!&&) TypeOrExpr &
		:= std::help::custom_assign(*THIS, __cpp_std::[T!]forward(v));
}