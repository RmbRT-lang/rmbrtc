
::rlc::instantiator
{
	Symbol
	{
		{ _ } { DIE; }
		ENUM T {
			type,
			variable,
			function,
			functoid
		}
		//Templates: ast::[Config]TemplateArg - std::ValVec;
	}

	ValueSymbol
	{
		Item: Instance #\;

		:transform{
			prev: resolver::Symbol #&,
			ctx: Context #&
		}
		{
			item ::= prev.Item!;
		}
	}

	TypeSymbol
	{
		Item: Instance #\;

		:transform{
			prev: resolver::Symbol #&,
			ctx: Context #&
		}
		{
			item ::= prev.Item!;
		}
	}

	resolve_value_symbol(
		symbol: resolver::Symbol #&,
		ctx: Context #&
	) ValueSymbol
	{
		DIE "resolve_value_symbol";
	}
}