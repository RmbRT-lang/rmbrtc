INCLUDE "c/gen.rl"

::rlc::codegen
{
	(/
	UNION Generators {
		C: c::Generator;
		Interp: interp::Generator;
		//X86Dumb: x86::dumb::Generator;
	}/)

	comptime: interp::Interpreter;
	runtime: c::Generator;
}