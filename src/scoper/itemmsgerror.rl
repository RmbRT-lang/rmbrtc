INCLUDE "error.rl"
INCLUDE "scopeitem.rl"
INCLUDE "fileregistry.rl"

::rlc::scoper ItemMsgError -> Error
{
	Msg: CHAR #\;
	{
		item: scoper::ScopeItem #\,
		registry: FileRegistry #&,
		msg: CHAR #\
	}
	->	Error(item->position(registry))
	:	Msg(msg);

	# print_msg(o: std::io::OStream &) VOID
	{
		o.write(Msg);
	}
}