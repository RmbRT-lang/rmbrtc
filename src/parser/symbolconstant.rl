::rlc::parser ENUM SpecialName {
	less,
	lessGreater,
	greater,
	exclamationMark,
	questionMark
}

::rlc::parser SymbolConstant
{
	UNION NameU {
		Identifier: rlc::Identifier;
		Special: SpecialName;
	}
	Name: TAGGED NameU;

	Template: TokenSpan;

	{BARE};
}

::rlc::parser DefinitionSymbolConstant
{
	UNION DNameU {
		Identifier: rlc::FileDeclIdentifier;
		Special: SpecialName;
	}
	Name: TAGGED DNameU;

	Template: TokenSpan;

	{BARE};
}