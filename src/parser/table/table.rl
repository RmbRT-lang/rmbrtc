::rlc::parser::table
{
	TYPE Addr := U4;

	// Memory arena that contains lots of tables in one fixed batch of memory.
	Arena {
		Size: U4;
		States: U2;

		#? state(i: U2) State #? * --
			:= <State#? *>(<UM>(&THIS) + SIZEOF(THIS) + i * SIZEOF(State));

		[T]
		#? get(a: Addr) T #? * --
			:= <T#? *>(<UM>(&THIS) + SIZEOF(THIS) + a * 4);
	}

	State {
		PrimaryTables: @(CACHELINE) Addr[###ENUM tok::Type];
	}

	// Long-term, we will load tables using VPGATHERDD. While it does not beat scalar on throughput, the sheer number of values we can concurrently operate on subsequently is massive. With YMM tech, we get up to 8 sets of values at once per register, and can probably fit 2-4 executions into the register set. This should allow us to parse 16-32 files per core simultaneously on YMM machines, and 8-16 on XMM machines.
	// When we then also multithread the compiler, we should end up with 32-64 concurrent compilations on XMM (quadcore), and 128-256 on YMM (8 core) machines, or maybe half of that with hyperthreading or stuff like e-cores.
	// For portability, we will first implement it in a scalar path. It seems that with SIMD, the fewer immediate values and temporary registers we need, the more parallelism we can achieve.

	// However, we should first implement the scalar parser as a reference (for debugging, etc.) and then transform it.

	State {
		Accepts: U2; // flags of token types.
		PrimaryTable: ;
	}


	// Parser should be described as a DSL.
	// - Can set up switches with tokens types / subtypes.
	// - Can tell to append a byte to the constructed AST node.
	// - Can push a context, can pop a context.
	// - Can execute a function.

	// Trouble: parsing is a very small workload. even at 20 tokens per line & 40 cycles per token, at 100K lines, we would only be at 40ms or something for parsing. The intensive operation is analysing the source code, template instantiation, type checking, code generation, etc.. So heavy optimisation of the parser is probably wasted time and might just obfuscate it.
	// But what we could do is take inspiration from this and try to convey as much context to the later stages as possible. But not necessarily via code, but maybe via data. For example, having [T]Vec as type expression could be a variable-length descriptor. Looking up members on [T]Vec could then look up on Vec, while keeping the T as linearly encoded opaque context???

	// *** Another thing that we can do is skip bodies of globals (such as classes, etc., by matching braces and skipping everything in between), and then first build a complete registry of all globals. During that, we can accumulate all the skipped token spans based on scope type, and then have SIMD-ised versions that parse those in a second pass, or something. This allows us to then parse all classes at once, and all member functions at once, etc., with few branch misses. Also, since we can populate the scope tree before parsing any actual expressions, we no longer need a post-parse resolve step for identifiers. All identifiers can be resolved to a local, member, template, or global at parse time. This means we can also have a lean C-style parse that does not need to lose context (except for figuring out return types of functions maybe). But for all functions that do not have auto return types, we can create the signature first. Then we parse all function bodies. This should allow us to resolve all signatures of all things, except for templates. But in those cases, we can output code for the instantiator, so that instantiation is simply running over a bytecode sequence with an interpreter.

	// Going over tokens multiple times should be cheaper than regaining context in nested heterogeneous scopes and doing graph walking and all that. So we want to solve as many problems as possible in token space, not in graph space. And we also want to solve as many problems ahead of time as possible in general, such as already outputting stuff for the code generator during parsing, when appropriate, if it is already known what it would have to do with it, but would later on require regaining context.

	// We could have a table that stores one entry per identifier, and then each context could simply overwrite the entry with a new meaning. Since we can only have 64K identifiers, this is definitely affordable. Then looking up something does not even need a hash anymore. We can simply look into the big table. Entering a scope overwrites the entry and leaving the scope restores it. Though this will only work for locals, as scope-dependent lookups would clash with the global table. But this could be a good accelerator for looking up globals from within a class or namespace. Or maybe each namespace could have a 64K array of children. Then looking up an identifier in any namespace is just one array lookup. We could also use a sparse array with a compressed bitmask to reduce the memory footprint (as suggested for the ECS in that one thread on gamedev.net). At one bit bloom per name, we can have much fewer entries. Once everything is populated, lookups will be very fast and contain basically no branches or logic. This should make interleaved lookups very fast, which is a major challenge in other designs, and probably a big source of latency. Looking up a symbol would basically just be looking up an array index, either in the root namespace, or in the parent scope, or in the previously looked-up scope. So even nested lookups would be trivial to interleave. Since we pointer-chase anyway, this could be our best bet. It will thrash the cache, but that is hard to avoid anyway, and given how we have sparse accesses, this should help us minimise the actual cache pollution. Also, parsing all functions in parallel allows us to also look up all the references in all expressions in parallel. Which means a name lookup could be amortised to just a few cycles per nesting, instead of blocking for dozens of cycles. Using a bloom would reduce overall memory usage, but increase the number of touched cache lines by at worst a factor 2. If we have 1000 namespaces, then we would only have up to 64Mi entries in the array. And a namespace could also have a min/max value to limit the range. And this is also only if we actually use 64Ki identifiers. And that info is basically for free (since it is next to the table pointer) and just an index subtraction. Also, namespaces can have a table that contains the member lookup, and a table that does an outer lookup. That way, we can simply use a redundant copy of the outer table, and then we can look up any arbitrarily outer name in just one lookup. As long as we do not get lots of page faults, even L3 misses should not be a big issue, as we can sustain 8+ L3 misses. And that would only really occur in large programs. Small programs would have fewer identifiers and fewer namespaces, and fewer lookups in general. Also, we can execute name resolves from within the same namespace together. This means we basically only get up to 64K entries of attack surface for global names, plus the individual nested lookups. This should entirely fit in L1 or L2, with nested lookups fetchable into L3 or something. Then we can sustain basically one lookup per cycle or something. With fast lookups, we can generously use nesting and namespaces if we want, which also cuts down on the number of distinct identifiers.
	// We can use a similar system for types and templates and instantiation, maybe, and might no longer need the global hash table and mempool. If we accept cache misses, which wo do anyway with a hash table, then at least name-based lookups are super cheap. Deduplicating types like VOID ** might need a hash table, unless we actually just carry around the encoding of the type as its handle. We also need to have a look at function overload resolution. We might not even need to cache that. We do need to cache template instantiations, though. We could think about deduplicating large types in a hash table maybe (like passing huge tuples around that then clog up everything). But usually, a function does not have that many overloads to warrant a large cost for all uses. Especially if we are not heavy on OOP with our code. And a hash table only starts to pay off pretty late. Realistically, 100K lines or so would be the max anyway for a project. Maybe if a function has more than some number of overloads or something, it can migrate them all into a hash table. Or if a type descriptor is too large, it gets replaced by a mempool ID, while short descriptors get inlined. And the mempool ID can also be part of the inlined type. Then, large types remain easy to check for overloads, and large numbers of overloads also don't cause problems, but we only pay the added complexity cost in the worst case. Also, inlined types would mean we can substitute templates directly in the encoding by simply creating a copied encoding with replacements.
	// Also, big types are really only a thing for tuples, so we want to avoid having to describe the type of tuples altogether. For example array / table construction should not involve actual tuple types with dedicated type IDs. Those should be just a temporary array in a tempalloc. So, large tuples should never get treated as a value, and get inlined into variadic ctor calls. Variadic functions accepting many arguments should just get inlined without attempts to deduplicate them. Or rather: complex tuples should always appear as variadic arguments to implicit constructors, and never be stored as an actual value. They should not even receive a type ID. This way, resolution and type deduction should mostly use scratchpad space, and not even construct the actual type of tuple expressions unless the tuple is actually required as a singular value. Even passing a tuple to a function that takes a fixed tuple type should not need to construct the tuple type descriptor of the temporary. Instead, it should just piecewise construct the argument from the tuple expression's members. And even then, the problem is mostly that we want tuples to be easily encodable, traversable, comparable. --> blob









	PrimaryTable
	{
		Size: U2; // Big, in case we want to have many intrinsics.

		#? THIS[i: U2] Addr -- :=
			<State#? *>(<UM>(&THIS) + SIZEOF(THIS) + i * SIZEOF(State));

		Entry
		{
			ENUM Flag {
				x
			}
			Flags: U1;
			Next: U2;
		}
	}

	SecondaryTable {}
}