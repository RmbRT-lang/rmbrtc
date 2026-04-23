::rlc::parser
{
	Field
	{
		Name: Identifier; // for easier inspection?
		Location: src::Position;

		Isolated: BOOL;
		Index: U2; // for memory layout.
		Alignment: TokenSpan;

		Type: TypeU;

		{BARE};
	}
}