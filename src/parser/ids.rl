
::rlc::parser {
	ArgsID { ID: U4; {}--; {...}--; {NULL}--; }
	BodyID { ID: U4; }
	SpecialCtorBodyID { ID: U4; }
	RestID { ID: U4; }
	ExpressionID { ID: U4; {}--; {...}--; {NULL}--; }
	TypeID { ID: U4; }



	NamespaceID {
		ID: U2;

		# get() scoper::Namespace \ -- := compiler::stage1::parse::namespace(THIS);
	}
	MemberScopeID {
		ID: U2;

		{...}--;
		{}-- (~0);
		{NULL}-- (~0);

		# <BOOL> -- := ID != <U2>(~0);

		# get_ok() parser::Members \ -- := compiler::stage1::parse::member_scope_ok(THIS);
		# get() parser::Members \ -- := compiler::stage1::parse::member_scope(THIS);
	}
}