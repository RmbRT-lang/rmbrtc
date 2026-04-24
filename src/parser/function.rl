INCLUDE "../mempool.rl"
INCLUDE "../identifierPool.rl"
INCLUDE "ids.rl"
::rlc::parser
{
	TYPE TypeHandle := :?;

	ENUM BodyType { // keep order in sync with tok::Punctuation
		none, // semicolon
		shorthand, // colonEqual
		block // braceOpen
	}

	ParsedSignatureRest {
		Type: :?;
		Inline: BOOL;
	}
	// Return type and stuff like the inline attribute.
	UNION SignatureRest {
		Preparse: RestID;
		Postparse: ParsedSignatureRest;
	}

	ParsedArguments {
		TypeHandle;
		Count: U2;
		Names: Identifier-Handle;
	}
	UNION Arguments {
		Preparse: ArgsID;
		Postparse: ParsedArguments;
	}

	UNION Templates {
		Preparse: parser::TokenSpan;
		Postparse: :TemplateCtx;
	}

	Function {
		Name: Identifier;
		File: src::File;
		Templates: parser::Templates;

		Args: Arguments;
		Return: SignatureRest;

		BodyType: parser::BodyType; Body: BodyID;

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