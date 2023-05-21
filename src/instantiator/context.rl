INCLUDE "instance.rl"

/// Context visiting the AST during the instantiation of the program.
::rlc::instantiator Context VIRTUAL
{
	Parent: THIS #*;
	Cache: instantiator::Cache \;
	Generator: instantiator::Generator *;

	:childOf{
		ctx: Context #\
	}:
		Parent := ctx,
		Cache := ctx->Cache,
		Generator := ctx->Generator;

	:root{
		cache: instantiator::Cache \,
		generator: instantiator::Generator *
	}:
		Cache := cache,
		Generator := generator;

	{...};

	# VIRTUAL this_type() InstanceType
	{ IF(Parent) = Parent->this_type(); THROW; }

	# VIRTUAL this_constness() ast::type::Constness
		:= Parent ?? Parent->this_constness() : :none;

	# VIRTUAL variadic_index(expansion: src::Position #&) VOID {}

	[T:TYPE] # nearest() T #*
	{
		IF(ret ::= <<T #*>>(&THIS)) = ret;
		IF(!Parent) = NULL;
		= Parent->[T]nearest();
	}

	# transform_control_label_name(p: scoper::Config::ControlLabelName #&) :nothing INLINE := :nothing;
}

::rlc::instantiator RootContext -> Context
{
	:root{
		cache: instantiator::Cache \,
		generator: instantiator::Generator *
	} -> (:root, cache, generator);
}

/// Keeps track of the THIS type.
::rlc::instantiator ClassContext -> Context
{
	:childOf{
		parent: Context #\, class: InstanceID #\
	} -> (:childOf, parent):
		ClassID := class;

	/// Inner-most parent class we're currently in.
	ClassID: InstanceID #\;

	# FINAL this_type() InstanceType := ClassID;
}

/// The current statement. May or may not be inside a function (such as inside a statement expression in global scope).
::rlc::instantiator StatementContext -> Context
{
	:childOf{
		parent: Context #\,
		stmt: ast::[Config]Statement \
	} -> (:childOf, parent):
		Statement := stmt;

	Statement: ast::[Config]Statement \;
}

/// The current expression. May or may not be inside a function (such as in global scope).
::rlc::instantiator ExpressionContext -> Context
{
	:childOf{
		p: Context #\, e: ast::[Config]Expression #\
	} -> (:childOf, p): Expression := e;
	Expression: ast::[Config]Expression #\;
}

::rlc::instantiator VariadicContext -> Context, VariadicExpansionTracker
{
	:childOf{p: Context #\} -> (:childOf, p), ();
}