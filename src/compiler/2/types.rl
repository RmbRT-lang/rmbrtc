::rlc::types
{
	// Mutable Unique : can cache writes and reads, no invalidation of any registers upon write. We are the only reference in existence.
	// Const Unique: Multiple references could exist, but no mutable reference exists. We can cache reads, and no writes to anything invalidate them.
	// Shared Mutable: Multiple writers exist, OR readers also exist. We have to assume other writers will interfere.
	// Shared Const: We can only read, but we know a writer exists somewhere.
	// ThreadShared Mutable: We have write access, but there exists a reader or writer on another thread.
	// ThreadShared Const: We only have read access, but there exists a writer on another thread.

	ENUM Constness {
		Mutable,
		Const,
		MaybeConst // #? -- inherit the constness of the THIS object.
	}
	ENUM Sharedness {
		Unique, // C-style "restrict" behaviour
		Shared, // Multiple pointers point to the same memory, but only if they share the same region.
		ThreadShared, // Atomics, basically. Is this the right place for this?
		MaybeShared // $? -- inherit the sharedness of the THIS object.
	}
	ENUM AliasingConstraint {
		Locals,
		This,
		ThisOwned,
		Arguments,
		Globals
	}

	// CAUTION: adjust the region bit width in the PackedModifier.
	// *OwnedReference: means we point to memory that is not directly part of a variable, but owned by it. So like the memory buffer owned by a vector, not the container itself.
	// Keywords needed: UNKNOWN, LOCAL, GLOBAL, ARG, THIS, MEMBER, OWNED
	// ptr: T LOCAL * := &x;
	// ptr: T LOCAL(x) * := &x;
	// ptr: T OWNED(x) * := x->Data;
	(/
		Class {
			Member: Complex;
			Member2: Other;

			get() INT MEMBER(Member) * := &Member.Field;
			get2() INT THIS * := &Member.Field;

			get_owned() INT MEMBER OWNED(Member) * := Member.DataPtr;

			function() VOID
			{
				ptr: INT MEMBER(Member) * := get();
			}
		}

		function2() VOID
		{
			c: Class;
			ptr1: INT * := c.get();
			ptr2: INT LOCAL(c) * := c.get2();
			ptr3: INT LOCAL OWNED(c) * := c.get2();
			fn3(ptr2);
		}

		GlobalPtr: INT *;
		fn3(p: INT ARG *) VOID
		{
			GlobalPtr := p; // error: breaking the lifetime constraint of the argument region.
		}
	/)
	UNION Region {
	*	Instance; /// an instance, not a reference.
	?	UnknownReference; /// C-style "volatile" or non-"restrict" behaviour, forced invalidation of basically everything.
	?	ConstrainedUnknownReference: U1; // AliasingConstraint::FLAGS.
	?	LocalReference: U2; /// Local variable, cannot be returned
	?	LocalOwnedReference: U2;
	?	GlobalReference: U2; /// global variable
	?	GlobalOwnedReference: U2;
	?	ExpiringReference; /// && reference, temporary value
	?	ArgReference: U2; /// function parameter reference, safe to return, turns into expiring reference when returning.
	?	ArgOwnedReference: U2;
	?	ThisReference; /// Reference to member of THIS.
	?	ThisOwnedReference; /// Basically for container region stuff. Tagging a pointer or reference with THIS lets us reason about memory much better at the type level without requiring an understanding of allocators.
	?	FieldReference: U2; /// Only accessible within a class, decays into ThisReference when facing outside code.
	?	FieldOwnedReference: U2;
		// Thread-local storage as its own category?
	}

	PackedModifier {
		Bits: U1; // all bits in use.

		# constness() Constness -- := >(Bits & 3); // Bits 0-1
		set0_constness(v: Constness) VOID -- { Bits |= <U2>(v); }

		# sharedness() Sharedness -- := >(Bits >> 2 & 3); // Bit 2-3
		set0_sharedness(v: Sharedness) VOID -- { Bits |= <U2>(v) << 2; }

		# region() ENUM Region -- := >(Bits >> 4 & 15); // Bits 4-7
		set0_region(v: ENUM Region) VOID -- { Bits |= <U2>(v) << 4; }
	}

	// For final types, use a prefix tree? With an U2 id into the nodes.
	// But not all nodes appear as actually instantiated types in the final program, so they might not receive a final runtime type ID. --> We need a deduplicator like with global to file-local IDs.
	UNION ByteCode {
		MakeVoid;
		MakeNullType;
		MakeTuple: U2; // number of tuple elements.
		MakeFnSig: U2; // number of arguments.
		MakeTemplateSymbolType: Identifier; // Prefix: turn next type into template arg for symbol type.
		MakeSymbolType: Identifier;
		MakeThisType: BOOL; // Whether it is nodecay
		ExpandTemplateTypes: U2; // Idx of template pack, expand it. (Args...)

		MakeBuiltinType: tok::BuiltinType;

		// look up in parent.
		LookChildType: Identifier;
		LookChildValue: Identifier;
		LookChildScope: Identifier;

		// look up in root scope.
		LookRootType: Identifier;
		LookRootValue: Identifier;
		LookRootScope: Identifier;

		// look up relative to expression context.
		LookRelativeType: Identifier;
		LookRelativeValue: Identifier;
		LookRelativeScope: Identifier;

		InstantiateTemplate: U2; // Idx of template arguments to apply to the bytecode.
		PushAsTemplate; // Abort current type and push it onto template argument stack.
		PushTemplatePack: U2; // number of template parameters.
		PushAsVariadicTemplatePack;
		AddTemplatePacks: U2;
		AddTemplateArg; // Prefix op: add this to the template arguments of the next type leaf. Execute this at symbol end or before the next AddTemplateArg. We can actually apply templates automatically in LookChildType, maybe? Based on precedence rules.

		AddModifier: PackedModifier; // when adding any modifiers.
		SetRegionTarget: Region; // when adding a modifier with a region that is parameterised.

		MakeAutoArray;
		MakeArray;
		MakeTable;
		MakePointer;
		Dereference; // element of pointer or array, or result of *THIS/THIS-> operator.
		GetUnionTag; // Is a prefix operation!
		MakeTaggedUnion;
		AccessTupleField: U2; // .(Index)
		FieldAccess: U2; // .(:Field)
	}
}