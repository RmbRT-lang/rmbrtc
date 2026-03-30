::rlc::parser
{
	ENUM BodyType { // keep order in sync with tok::Punctuation
		none, // semicolon
		shorthand, // colonEqual
		block // braceOpen
	}

	Function {
		Name: Identifier;
		File: src::File;
		Templates: parser::TokenSpan;

		Args: TokenSpan;
		Return: TokenSpan;
		BodyType: parser::BodyType;
		Body: TokenSpan;

		{BARE};
	}
}