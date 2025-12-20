::rlc::ir evaluate(op: Operation, args: Operands[#]) VOID
{
}

::rlc::ir::eval
{
	IntClassification
	{
		packed: U1;
		:nan {} --: packed := 0;
		:signed{size: U1} --: packed := size | 16;
		:unsigned{size: U1} --: packed := size;

		# nan() BOOL -- := !packed;
		# sign() BOOL -- := packed & 16;
		# size() BOOL -- := packed & 15;
	}

	classify_int: @(CACHELINE) IntClassification[TABLE ENUM Operand] (
		:uninitialised(:nan),
		:unpatchedPlaceholder(:nan),

		:imm_u1(:unsigned(1)),
		:imm_u2(:unsigned(2)),
		:imm_u4(:unsigned(4)),
		:imm_u8(:unsigned(8)),

		:imm_s1(:signed(1)),
		:imm_s2(:signed(2)),
		:imm_s4(:signed(4)),
		:imm_s8(:signed(8)),

		:imm_i1(:unsigned(1)),
		:imm_i2(:unsigned(2)),
		:imm_i4(:unsigned(4)),
		:imm_i8(:unsigned(8)),

		:imm_local(:nan),
		:imm_local_last_use(:nan)
	);

	int_from_classification: @(CACHELINE) ENUM Operand[25](
		:illegal,
		:imm_u1,
		:imm_u2,
		:imm_u3,
		:imm_u4,
		:imm_u5,
		:imm_u6,
		:imm_u7,
		:imm_u8,

		:illegal,
		:illegal,
		:illegal,
		:illegal,
		:illegal,
		:illegal,
		:illegal,
		:illegal,

		:imm_s1,
		:imm_s2,
		:imm_s3,
		:imm_s4,
		:imm_s5,
		:imm_s6,
		:imm_s7,
		:imm_s8);

	neg(args: TAGGED Operand#[#], ctx: Context &) VOID
	{
		ASSERT(##args == 1);
		arg ::= args[0];
		class ::= classify_int[arg.(0)];
		IF(class.nan()) { ctx.error("not an integer"); }

		neg ::= -arg.(1).imm_i8;
	}

	add(args: TAGGED Operand#[#], ctx: Context &) VOID
	{
		ASSERT(##args == 2);
		SWITCH(args[0].(0))
		{
		:imm_u1, :imm_u2, :imm_u4, :imm_u8,
		:imm_s1, :imm_s2, :imm_s4, :imm_s8,
		:imm_i1, :imm_i2, :imm_i4, :imm_i8:
		{
			SWITCH(args[1].(0))
			{
			:imm_u1, :imm_u2, :imm_u4, :imm_u8,
			:imm_s1, :imm_s2, :imm_s4, :imm_s8,
			:imm_i1, :imm_i2, :imm_i4, :imm_i8:
			{
				cl ::= int_character[args[0].(0)];
				cr ::= int_character[args[1].(0)];
				result ::= args[0].(1).imm_u8 + args[1].(1).imm_u8;
			}
			}
		}
		}
	}
}