::rlc::parser SymbolConstant
{
	ENUM SpecialName {
		less,
		lessGreater,
		greater,
		exclamationMark,
		questionMark
	}

	UNION NameU {
		Identifier: rlc::Identifier;
		Special: SpecialName;
	}
	Name: TAGGED NameU;

	Template: TokenSpan;

	{BARE};
}