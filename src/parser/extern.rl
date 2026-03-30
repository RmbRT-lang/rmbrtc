::rlc::parser Extern {
	Name: Identifier;
	LinkName: Identifier;

	Rest: TokenSpan;
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