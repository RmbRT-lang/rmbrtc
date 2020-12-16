INCLUDE "../tokeniser/token.rl"
INCLUDE "../src/file.rl"

INCLUDE 'std/string'
INCLUDE 'std/unicode'

::rlc ENUM Endian { little, big, native }

::rlc::scoper ENUM TextType
{
	stringApostrophe,
	stringQuote,
	stringBacktick,
	stringTick
}

::rlc::scoper Text
{
	SymbolSize: std::U8;
	Endian: rlc::Endian;
	Type: TextType;
	Codes: std::Char-std::Vector;

	{token: tok::Token #&, file: src::File #&}
	{
		IF(token.Type == tok::Type::stringApostrophe)
			Type := TextType::stringApostrophe;
		ELSE IF(token.Type == tok::Type::stringQuote)
			Type := TextType::stringQuote;
		ELSE IF(token.Type == tok::Type::stringBacktick)
			Type := TextType::stringBacktick;
		ELSE IF(token.Type == tok::Type::stringTick)
			Type := TextType::stringTick;
		ELSE THROW;

		lit ::= file.content(token.Content);

		IF(std::str::starts_with(lit, "32"))
		{
			SymbolSize := 4;
			lit := lit.drop_start(2);
		} ELSE IF(std::str::starts_with(lit, "16"))
		{
			SymbolSize := 2;
			lit := lit.drop_start(2);
		} ELSE IF(std::str::starts_with(lit, "8"))
		{
			SymbolSize := 1;
			lit := lit.drop_start(1);
		} ELSE
			SymbolSize := 1;

		SWITCH(lit[0])
		{
		CASE 'l', 'L': { Endian := rlc::Endian::little; lit := lit.drop_start(1); BREAK; }
		CASE 'b', 'B': { Endian := rlc::Endian::big; lit := lit.drop_start(1); BREAK; }
		DEFAULT: { Endian := rlc::Endian::native; BREAK; }
		}

		// Skip leading and trailing string delimeter character.
		{
			delim ::= std::code::utf8::size(lit[0]);
			lit := lit.range(delim, lit.Size-2*delim);
		}

		FOR(i ::= 0; i < lit.Size;)
		{
			size: UM;
			code ::= std::code::utf8::point(&lit[i], &size);
			Codes.push_back(code);
			i += size;
		}
	}

	# utf8() std::Utf8
	{
		ret: std::Utf8;
		ch: std::C8[4];
		FOR(i ::= 0; i < Codes.size(); i++)
			ret.append(std::[char#]Buffer(
				&ch[0],
				std::code::utf8::encode(Codes[i], &ch[0])));
		RETURN ret;
	}

	# c_str() std::Utf8 := std::String(utf8(), :cstring);
}