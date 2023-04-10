::rlc::ast [Stage: TYPE] Instantiable VIRTUAL {
	{BARE}: ParentInstantiable := NULL;
	:childOf{
		parent: THIS *
	}: ParentInstantiable := parent;
	:inRoot{}: ParentInstantiable := NULL;

	ParentInstantiable: THIS *;
}