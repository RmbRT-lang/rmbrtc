EXTERN exit(INT) VOID;

::term [Args...] error(at: WHERE, args: Args! &&...) VOID
{
	IF!(at)
		os::term::PrintLine_v(
			:style(:bold, :red), "error: ",
			:style(:normal, :same), <Args!&&>(args)...);
	ELSE IF(at.(1))
		os::term::PrintLine_v(
			:style(:normal, :default), std::str::c(at.(0)[]), ":", std::io::format::dec(at.(1)), ":", std::io::format::dec(at.(2)), ": ",
			:style(:bold, :red), "error: ",
			:style(:normal, :same), <Args!&&>(args)...);
	ELSE
		os::term::PrintLine_v(
			:style(:normal, :default), std::str::c(at.(0)[]), ": ",
			:style(:bold, :red), "error: ",
			:style(:normal, :same), <Args!&&>(args)...);
	exit(1);
}

::term [Args...] warning(at: WHERE, args: Args! &&...) VOID
{
	IF!(at)
		os::term::PrintLine_v(
			:style(:bold, :yellow), "warning: ",
			:style(:normal, :same), <Args!&&>(args)...);
	ELSE IF(at.(1))
		os::term::PrintLine_v(
			:style(:normal, :default), std::str::c(at.(0)[]), ":", std::io::format::dec(at.(1)), ":", std::io::format::dec(at.(2)), ": ",
			:style(:bold, :yellow), "warning: ",
			:style(:normal, :same), <Args!&&>(args)...);
	ELSE
		os::term::PrintLine_v(
			:style(:normal, :default), std::str::c(at.(0)[]), ": ",
			:style(:bold, :yellow), "warning: ",
			:style(:normal, :same), <Args!&&>(args)...);
}


::term [Args...] info(at: WHERE, args: Args! &&...) VOID
{
	IF!(at)
		os::term::PrintLine_v(
			:style(:bold, :cyan), "info: ",
			:style(:normal, :same), <Args!&&>(args)...);
	ELSE IF(at.(1))
		os::term::PrintLine_v(
			:style(:normal, :default), std::str::c(at.(0)[]), ":", std::io::format::dec(at.(1)), ":", std::io::format::dec(at.(2)), ": ",
			:style(:bold, :cyan), "info: ",
			:style(:normal, :same), <Args!&&>(args)...);
	ELSE
		os::term::PrintLine_v(
			:style(:normal, :default), std::str::c(at.(0)[]), ": ",
			:style(:bold, :cyan), "info: ",
			:style(:normal, :same), <Args!&&>(args)...);
}
