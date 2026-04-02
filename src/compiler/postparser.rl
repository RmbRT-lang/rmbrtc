::rlc::compiler CodePostParser
{
	// The global rootscope. This is the only real output of the preparser.
	RootScope: scoper::Namespace \;

	// Gets reset after every file.
	PRIVATE MemberScopes: parser::Members \ -std::Vec; // we might also want to be registering other things here, such as a list of all functions, or all return types or something. And we might want to have a union type that we can patch in the post-pass, so that we do not need to move data around.


	post_parse_namespace_types(ns: scoper::Namespace \) VOID
	{
		FOR(ns->Entries!) {
			idx ::= IT.(0);
			entry ::= IT.(1).get();

			mem ::= entry->NVMem;
			IF(t ::= entry->NVType) SWITCH(t)
			{
			:Namespace:
				post_parse_namespace_types(<scoper::Namespace-Handle>(mem).get());
			:Class:
				post_parse_class_types(<parser::Class-Handle>(mem).get());
			:Rawtype:
				post_parse_rawtype_types(<parser::Rawtype-Handle>(mem).get());
			:Typedef:
				post_parse_typedef(<parser::Typedef-Handle>(mem).get());
			:Mask:
				post_parse_mask_types(<parser::Mask-Handle>(mem).get());
			:Union:
				post_parse_union_types(<parser::Union-Handle>(mem).get());
			:Enum: { ; }
			}

			mem ::= entry->VMem;
			IF(t ::= entry->VType) SWITCH(t)
			{
			:Function:
				post_parse_function_types(<parser::Function-Handle>(mem).get());
			:ExportFunction:
				post_parse_export_function_types(<parser::ExportFunction-Handle>(mem).get());
			:ExternFuncation:
				post_parse_extern_function_types(<parser::ExternFunction-Handle>(mem).get());
			:Variable:
				post_parse_global_variable_type(<parser::GlobalVariable-Handle>(mem).get());
			:ExportVariable:
				post_parse_export_variable_type(<parser::ExportVariable-Handle>(mem).get());
			:ExternVariable:
				post_parse_extern_variable_type(<parser::ExternVariable-Handle>(mem).get());
			}
		}
	}
}