INCLUDE "expression.rl"
INCLUDE "statement.rl"

INCLUDE "../util/dynunion.rl"

::rlc::resolver	ExprOrStmt
{
	PRIVATE V: util::[Expression; Statement]DynUnion;

	{};
	{:gc, v: Expression \}: V(:gc(v));
	{:gc, v: Statement \}: V(:gc(v));

	# is_expression() INLINE BOOL := V.is_first();
	# expression() INLINE Expression \ := V.first();
	# is_statement() INLINE BOOL := V.is_second();
	# statement() INLINE Statement \ := V.second();

	# <BOOL> INLINE := V;

	[T:TYPE] THIS:=(v: T!&&) ExprOrStmt &
		:= std::help::custom_assign(THIS, <T!&&>(v));
}