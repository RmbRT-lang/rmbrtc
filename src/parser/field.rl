::rlc::parser
{
	Field
	{
		Name: Identifier; // for easier inspection?
		Location: src::Position;

		Isolated: BOOL;
		Index: U2; // for memory layout.
		Alignment: ExpressionID;

		Type: TypeU;

		{BARE};
	}
}