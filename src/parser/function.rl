::rlc::parser
{
	ENUM BodyType { // keep order in sync with tok::Punctuation
		none, // semicolon
		shorthand, // colonEqual
		block // braceOpen
	}

	UnparsedSignatureRest {
		Type: TokenSpan;
	}
	ParsedSignatureRest {
		Type: TokenSpan;
		Inline: BOOL;
	}
	// Return type and stuff like the inline attribute.
	UNION SignatureRest {
		Preparse: UnparsedSignatureRest;
		Postparse: ParsedSignatureRest;
	}

	Function {
		Name: Identifier;
		File: src::File;
		Templates: parser::TokenSpan;

		Args: TokenSpan;
		Return: SignatureRest;

		BodyType: parser::BodyType; Body: TokenSpan;

		{BARE};
	}

	ENUM Abstractness {
		none,
		final,
		override,
		virtual,
		abstract
	}
	MemberFunction {
		Abstractness: parser::Abstractness;
		Fn: Function;

		{BARE};
	}
}