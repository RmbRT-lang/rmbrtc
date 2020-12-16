INCLUDE "../parser/statement.rl"

INCLUDE "variable.rl"
INCLUDE "expression.rl"
INCLUDE "types.rl"
INCLUDE "scope.rl"
INCLUDE "controllabel.rl"

INCLUDE "../util/dynunion.rl"

::rlc::scoper
{
	TYPE StatementType := parser::StatementType;

	Statement VIRTUAL -> ScopeOwner
	{
		# FINAL owner_type() OwnerType := OwnerType::statement;

		# ABSTRACT type() StatementType;
		# ABSTRACT variables() UM;

		Position: UM;
		ParentScope: Scope \;

		{
			position: UM,
			parentScope: Scope \}:
			Position(position),
			ParentScope(parentScope);

		STATIC create(
			position: UM,
			parsed: parser::Statement #\,
			file: src::File#&,
			parentScope: Scope \
		) Statement \ := detail::create_statement(
			position,
			parsed,
			file,
			parentScope);
	}
}