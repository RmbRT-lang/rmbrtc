::rlc::parser ExternFunction {
	Name: Identifier;
	LinkName: Identifier;

	Args: TokenSpan;
	Rest: SignatureRest;
}

::rlc::parser ExternVariable {
	Name: Identifier;
	LinkName: Identifier;

	Type: TypeU;
}

::rlc::parser ExportFunction {
	LinkName: Identifier;
	Fn: Function;
	{BARE};
}

::rlc::parser ExportVariable {
	LinkName: Identifier;
	Var: GlobalVariable;
	{BARE};
}