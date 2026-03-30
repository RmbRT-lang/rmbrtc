::rlc::parser
{
	Field
	{
		Name: Identifier; // for easier inspection?
		File: src::File; // ?

		Isolated: BOOL;
		Index: U2; // for memory layout.

		Type: TokenSpan;

		{BARE};
	}
}