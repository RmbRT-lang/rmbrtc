INCLUDE 'std/io/stream'
INCLUDE 'std/io/streamutil'
INCLUDE 'std/dyn'
INCLUDE 'std/err/unimplemented'

::cli
{
	ENUM Context
	{
		normal,
		error,
		warn,
		info
	}

	::style
	{
		reset: CHAR#* := "\e[0m";
		::bold 
		{
			on: CHAR#* := "\e[1m";
			off: CHAR#* := "\e[22m";
		}

		::dim
		{
			on: CHAR#* := "\e[2m";
			off: CHAR#* := "\e[22m";
		}

		::colour
		{
			default: CHAR#* := "\e[39m";
			red: CHAR#* := "\e[91m";
			yellow: CHAR#* := "\e[93m";
			cyan: CHAR#* := "\e[96m";
		}
	}


	Console
	{
		WithColours: BOOL;
		Context: cli::Context;

		PRIVATE Out: std::io::OStream *;

		{}: Context := :normal;
		{o: std::io::OStream \}: Out(o), WithColours(TRUE), Context := :normal;
		:plain{o: std::io::OStream \}:
			Out(o),
			Context := :normal;

		PRIVATE context(ctx: cli::Context) VOID
		{
			IF(Context == ctx) RETURN;
			Context := ctx;

			IF(!WithColours) RETURN;
			
			std::io::write(Out, style::reset);
			SWITCH(ctx)
			{
			DEFAULT: THROW <std::err::Unimplemented>(<CHAR#\>(ctx));
			:normal: {;}
			:error: std::io::write(Out, style::colour::red);
			:warn: std::io::write(Out, style::colour::yellow);
			:info: std::io::write(Out, style::colour::cyan);
			}
		}

		ENUM Style {normal, bold, dim}
		
		Printable
		{
			Style: Console::Style;
			Input: std::io::detail::StreamInput;

			{i: std::io::detail::StreamInput} INLINE: Style(:normal), Input(i);
			:e{i: std::io::detail::StreamInput} INLINE: Style(:bold), Input(i);
			:emph{i: std::io::detail::StreamInput} INLINE: Style(:bold), Input(i);
			:w{i: std::io::detail::StreamInput} INLINE: Style(:dim), Input(i);
			:weak{i: std::io::detail::StreamInput} INLINE: Style(:dim), Input(i);
		}

		PRIVATE print_printable(p: Printable) VOID
		{
			off: CHAR #* := NULL;
			IF(WithColours)
				SWITCH(p.Style)
				{
				:normal: {;}
				:bold:
				{
					std::io::write(Out, style::bold::on);
					off := style::bold::off;
				}
				:dim:
				{
					std::io::write(Out, style::dim::on);
					off := style::dim::off;
				}
				}

			std::io::write(Out, p.Input);

			IF(off)
				std::io::write(Out, off);
		}

		[Msg...: TYPE]
		as(ctx: cli::Context, msg: Msg!&&...) Console!&
		{
			IF(Out)
			{
				context(ctx);
				print_printable(<Printable>(<Msg!&&>(msg)))...;
			}
			= THIS;
		}

		[Msg...: TYPE] THIS(msg: Msg!&&...) & INLINE
			::= as(:normal, <Msg!&&>(msg)...);
		[Msg...: TYPE] error(msg: Msg!&&...) & INLINE
			::= as(:error, <Msg!&&>(msg)...);
		[Msg...: TYPE] warn(msg: Msg!&&...) & INLINE
			::= as(:warn, <Msg!&&>(msg)...);
		[Msg...: TYPE] info(msg: Msg!&&...) & INLINE
			::= as(:info, <Msg!&&>(msg)...);
	}

	main: Console;
}