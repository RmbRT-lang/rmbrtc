// The abstract IR. Contains both the AST as well as
::rlc::ir
{
	ENUM Operation {
		add,
		sub,
		mul,
		div_mod,
		div,
		mod,
		assign,
		shl,
		shr,
		rotl,
		rotr,
		prepare_call,
		arg,
		call_static,
		call_ptr,
		member_call_static,
		member_call_ptr,
		subscript,

		lookup_field,
		lookup_namespace_relative,
		lookup_namespace_global,
		lookup_type_in_namespace,
		lookup_value_in_namespace,
		lookup_value_relative,
		lookup_value_global,
		lookup_type_relative,
		lookup_type_global,

		nullable_pointer_type,
		nonnull_pointer_type,
		array_type,
		table_type,

		constructor,
		dynamic_cast,
		factory
	}

	OpArity: U1[TABLE Operation] (
		:add(2),
		:sub(2),
		:mul(2),
		:div_mod(2),
		:div(2),
		:mod(2),
		:assign(2),
		:shl(2),
		:shr(2),
		:rotl(2),
		:rotr(2),
		:prepare_call(1),
		:arg(1),
		:call_static(1),
		:call_ptr(1),
		:member_call_static(2),
		:member_call_ptr(2),
		:subscript(2),

		:lookup_field(2),
		:lookup_namespace_relative(1),
		:lookup_namespace_global(1),
		:lookup_type_in_namespace(2),
		:lookup_value_in_namespace(2),
		:lookup_value_relative(1),
		:lookup_value_global(1),
		:lookup_type_relative(1),
		:lookup_type_global(1),

		:nullable_pointer_type(1),
		:nonnull_pointer_type(1),
		:array_type(2),
		:table_type(2),

		:constructor(2),
		:dynamic_cast(2),
		:factory(2)
	);

	StructOperand { Type: U4; Size: U4; }

	// A span of operands.
	ImmTuple {
		Fields: U2;
		Start: U4;
	}

	// Should try to stay within 8 bytes.
	UNION Operand {
	*	uninitialised;
		illegal;
		unpatchedPlaceholder;

		number: U8;

		/// Fully analysed values: IDs / handles to various things.
		imm_local: U4;
		imm_local_addr: U4;
		imm_local_last_use: U4;
		imm_parameter: U4;
		imm_parameter_addr: U4;
		imm_parameter_last_use: U4;

		/// For example for instantiating a template? But we do not have types as values. However, when we do SIZEOF(T[3]) or something, we do need some kind of thing for that. The execution model should be that we first typecheck everything, and that produces the actual overload resolutions and which operations to even perform. Which means the typechecker operates on types and operations, while the executor operates on values and operations. The typechecker needs to fully execute before we run the executor or code generator, probably. Especially for stuff like multi returns / OR-types, we need to know the full possibility set before we get actual actionable operations.
		imm_type: U4;
		imm_template_type: U4;
		imm_template_value: U4;
		imm_identifier: U4;
		imm_namespaceable: U4;
		imm_struct_constant; // type + a memory block
		imm_tuple: ImmTuple;

		temp_value: U4; // runtime value that is not a named local nor a compile time constant.
		temp_value_last_use: U4;

		result0: U4; // Outputs of previous instructions.
		result1: U4;
		type0: U4; // Result type of instruction output.
		type1: U4;
	}

	// N separate instruction streams. Probably not SIMD, but at least interleaved branchless execution for amortisation.
	// Operands are separate from operations for compactness.
	// Keep tuple types etc. in a temporary storage, not in global persisted storage.
	[#N] Instructions
	{
		Link
		{
			Op: @(SIMD) U4[N];
			Args: @(SIMD) U1[N];
			ArgsStart: @(SIMD) U4[N];
		}

		Operations: Operation[#][N];
		Operands: TAGGED Operand[#][N];
		Reorder: Link[#][N]; // Changes the order of instructions or eliminates them.
	}
}