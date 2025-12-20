::rlc::codegen::x86::o0 {
	// Also used as ENUM, but we can also use the union for cool stuff maybe.
	UNION OperationInput {
	?	Constant: U8;
	?	Temporary: U4;
	?	ExpiringTemporary: U4;
	*	Nothing;
	}

	// We need to classify the registers by usage classes. For example ROR/ROL can only use CL as the shift amount, or an immediate. This means when allocating a value, it needs to be tied to the operations it wants to use, and the operations need to allocate registers according to the constraint they impose on register choice.


	// Since we have feedback cycles between IR and codegen (alignment requirements for example, and info on how many values we can hold at once (the IR does not know whether an operation needs to do weird shuffling and evictions or not for certain operations), it might be good to have a general IR, then a machine-specific IR, and then the code generation. The general IR would receive feedback to create the machine-specific IR. The machine-specific IR is then optimised for outputting code quickly and in parallel / SIMD. Especially in a SIMD block, we need to make sure we do not overcommit on registers, and chunk our workload appropriately. The general IR only serves the purpose of extracting common logic out of the backend-specific IRs (such as type-checking).
	// But since we do not know what parts are generic until we wrote at least one or two backends, it makes most sense to just build the x86 backend fully featured, and then afterwards, extract some of it into a general form.
	ENUM InputValueConstraint {
		imm8,
		imm32,
		imm64,
		mem,
		a, // unsigned multiply or short signed multiply form.
		c, // all variable shifts
		d,
		x32req,
		x64reg
	}

	// Possible constraint solver: physics constaint solver. Each possible choice pulls with a certain strength. Pulling something out of a satisfied constraint costs something, maybe? Spills push. We want to minimise spills while maximising usage of shorter or faster forms of the same operation. But if a faster form requires spilling or migrating from an unnegotiable constraint, it may not be worth it. Basically a coil spring simulation with some coils that push and some that pull, and some fixed elements. And then we also want to separately optimise for latencies and throughput. That's something the IR cannot really do. It can give some initial estimate, though. But then, is that really worth anything, if the specific backends can do it much better, anyway? At most, it would be a convenience when having many backends. But that would only pay off after 3 backends, probably. Which we are probably not going to build. So it's not even worth it. We just build x86 and maybe ARM. And RISA.


	// Possibility set of an input to an instruction.
	// Priority list: a value is considered to be of the category that is highest up in the list that it fulfills. So, input `a` is considered `a` before it is considered x32reg. That way, we can separately track latency / throughput stuff for specific sub-cases.
	ENUM InputChoices {
		imm8,
		imm32,
		imm64,
		mem,
		a,
		c, // cl for all shift amounts, and stuff like jcxz.
		x32reg,
		x64reg
	}

	// For dependency chains, so we know what depends on what.
	ENUM Dependencies{
		flags,
		a0,
		a1,
		a2,
		a,
		c,
		d,
		memory
	}

	StructuredInstruction {
		InputChoices: U2[3]; // Up to 3 inputs.
		Outputs: U1;
		Dependencies: U1;
	}
	UNION Instruction {
		Structured: StructuredInstruction;
		Word: U8;
	}

	// All the outputs that get written to.
	ENUM Outputs {
		a0, // The first input value is overwritten.

		// for any instruction that has fixed outputs.
		a,
		c,
		d,
		// Whether it sets flags.
		flags
	}

	// What about when input must be = output?
	// - for RMW memory ops: output is actually none, because it cannot be accessed without another load.
	// - for accumulate register ops: (o0 = a0: we might have to see whether we have any constraints on the usage of the value, and work backwards. Ideally just an accumulated bitmask (AND)).
	ENUM OutputValueConstraint {
		mem,
		aligned_mem, // This needs to be known by the IR.

		a0, // output must be input. We would need special handling of this, because it means different things each time.
		a, // unsigned multiply or short signed multiply form.
		c, // all variable shifts
		d,
		eax_edx, // values that are in eax:edx, although afaik these are only possible as outputs.
		x32req,
		x64reg,
		xmm
	}
	// We want to analyse entire chains of instructions, probably, so we want to be able to somehow combine input and output constraints. Maybe we can separately accumulate the input masks and output masks? If an accumulated mask is 0, we need to shuffle. If it is not 0, the entire chain shares a constraint and can be used together. Although if a chain of operations outputs to eax_edx each time, we would then have to reconsider what to do with the inputs. Maybe we should separate fixed inputs/outputs into a separate mask. Then we can track choices and clobbers separately, and then offer a0 as a clobber.

	(/ Workflow: we get an IR opcode, classify it according to its arguments, and then lookup the instruction shape required for that classification. Each instruction can then offer bytecode for multiple shapes. For example, using r8-15 uses different shapes than rax-rdx. This will become quite the large table, though. Maybe we should add one more step where we classify the instruction into a class of common shapes (add and sub have the same shape for all arguments). We should probably automate this. /)

	// If we want different forms of each instruction, we want to look 
	ENUM InstructionShape {
		no_args,
		immediate
	}

	OperationDesc {
		Inputs: OperationInput[3];
	}

	ENUM Operation {
		add,
		sub
	}

	// TODO: we would actually want to have some kind of enum table construct...
	// EnumTable( :field1(values...), :field2(values...)),
	// and it arranges the entries properly in the constructor, and we can index into it via enum as index. We could actually have this as a counterpart to SWITCH: TABLE. It's a fundamental thing you always want to do, especially for performance.
	// TABLE(enum, Type)? Or TABLE Type[Enum], or Type[TABLE Enum]. Or, we add special constructors for arrays of any kind. But then we lose the :Field index, as it no longer knows the enum to convert the field name to. So we do need a special enum table type, but it can downcast to arrays, and arrays should upcast to tables.
	opTable: INT[TABLE ENUM Operation](
		:add(5),
		:sub(5),
		:c(5),
		:d(6)
	);
}
::rlc::codegen::x86::o0::gen {
	Bytecode {
		Bytes: U1[16];
		Success: BOOL;
		Length: U1;
	}

	RegRegInstruction {
		Variants: Bytecode[TABLE Register][TABLE Register];
	}
	

	EXTERN system(CHAR#[]) INT;

	generate_reg_reg_instruction(name: CHAR[#]) RegRegInstruction {
		os::WriteFile("/tmp/.nasm-input.asm", opcode);
		FOR(###Register)
			system("nasm /tmp/.nasm-input.asm -o /tmp/.nasm-output.asm");
	}
	TEST "Generate opcodes" {
		generate_reg_reg_instruction("mov");
		generate_reg_reg_instruction("add");
		generate_reg_reg_instruction("sub");
		generate_reg_reg_instruction("shl");
		generate_reg_reg_instruction("rol");
		generate_reg_reg_instruction("shr");
		generate_reg_reg_instruction("ror");
	}
}