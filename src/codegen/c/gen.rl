::rlc::codegen::c
{
	UNION OperandPrint {
		Illegal;
	!?	Text: CHAR#[#];
	?	PrefixNumber: CHAR#[#];
	?	Number;
	?	Type;
	?	TemplateType;
	}
}

::rlc::codegen::c Generator
{
	Code: RAW[];
	CodeStart: RAW[];
	CodeEnd: RAW[];

	print_operand(o: TAGGED ir::Operand) VOID
	{
		STATIC table: TAGGED OperandPrint[TABLE ENUM ir::Operand](
			:uninitialised(:Illegal),
			:illegal(:Illegal),
			:unpatchedPlaceholder(:Illegal),
			:number(:Number),
			:imm_local(:PrefixNumber("LOCAL_")),
			:imm_local_addr(:PrefixNumber("&LOCAL_")),
			:imm_local_last_use(:PrefixNumber("LOCAL_")),
			:imm_parameter(:PrefixNumber("PARAM_")),
			:imm_parameter_addr(:PrefixNumber("&PARAM_")),
			:imm_parameter_last_use(:PrefixNumber("PARAM_")),
			:imm_type(:Type),
			:imm_template_type(:TemplateType),


			:result0(:PrefixNumber("R0_")),
			:result1(:PrefixNumber("R1_"))
		);

		lut ::= table[o.(0)];
		SWITCH(lut.(0))
		{
		:Illegal: DIE "Illegal IR instruction encountered";
		:Text: { append(lut.(1).Text); }
		:PrefixNumber: { append(lut.(1).PrefixNumber); append_number(o.(1).number); }
		:Number: { append_number(o.(1).number); }
		:Type: { append_type(o.(1).imm_type); }
		:TemplateType: { append_type(o.(1).imm_type); }
		}
	}

	append(text: CHAR#[#]) VOID --
	{
		FOR(text) Code[IOTA] := IT;
		Code += ##text;
	}

	append_number(number: U8) VOID --
	{
		Code += std::io::format::hex_into(<CHAR *>(Code!)[], number);
	}

	append_type(id: U4) VOID --
	{
		append(TypeNames[id]);
	}

	generate_function(inst: ir::Instruction[#]) VOID
	{
		FOR(inst)
		{
		}
	}
}