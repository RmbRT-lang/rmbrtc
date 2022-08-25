::rlc::scoper::literal
{
	string(t: tok::Token, file: src::File #&) std::Str
	{
		delim ::= help::delim(t.Type);
		str ::= file.content(t.Content).drop_start(##delim).drop_end(##delim);
		FOR(c ::= str.start())
			IF(c! == '\\')
				DIE "escapes in include paths are not yet implemented!";
		= <std::str::CV>(str++);
	}
	::help delim(t: tok::Type) std::str::CV
	{
		SWITCH(t)
		{
		:stringQuote: = "\"";
		:stringApostrophe: = "'";
		:stringTick: = "´";
		:stringBacktick: = "`";
		}
	}
}