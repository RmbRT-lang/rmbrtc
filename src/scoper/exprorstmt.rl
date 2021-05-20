INCLUDE "expression.rl"
INCLUDE "statement.rl"

INCLUDE "../util/dynunion.rl"

::rlc::scoper
{
	ExprOrStmt
	{
		PRIVATE V: util::[Expression; Statement]DynUnion;

		{};
		{v: Expression \}: V(v);
		{v: Statement \}: V(v);

		# is_expression() INLINE bool := V.is_first();
		# expression() INLINE Expression \ := V.first();
		# is_statement() INLINE bool := V.is_second();
		# statement() INLINE Statement \ := V.second();

		# <bool> INLINE := V;

		[T:TYPE] THIS:=(v: T!&&) ExprOrStmt &
			:= std::help::custom_assign(THIS, <T!&&>(v));
	}
}