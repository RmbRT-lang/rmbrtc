::rlc::ir
{
	[U; T]slice_after(p: T! *, count: U4) U![#] -- := <U! *>(&p[1])[FOR count];
	[U; T]slice_after_slice(p: T![#], count: U4) U![#] -- := <U! *>(&p[##p])[FOR count];

	TypeHandle
	{
		Handle: U8;

		# decode() Type --;
	}

	ENUM SpecialSymbol
	{
		questionMark,
		exclamationMark,
		less,
		greater,
		lessGreater
	}

	[This; T]DynArray
	{
		Start: U2;
		Entries: U2;

		{this: This #&, data: T *, count: U2} --:
			Start := <UM>(data) - (<UM>(&this) + SIZEOF(This)),
			Entries := count;

		#? THIS(this: This #?&) T#?[#] --
			:= <T #? *>(<UM>(&this) + SIZEOF(This) + Start)[FOR Entries];
		## THIS U4 -- := Entries;
	}

	[THIS; T]AssocDynArray
	{
		Start: U2;

		{this: This #&, data: T *} --:
			Start := <UM>(data) - (<UM>(&this) + SIZEOF(This));

		#? THIS(this: This #?&) T#?[] --
			:= <T #? *>(<UM>(&this) + SIZEOF(This) + Start)[];
	}

	FnSignature {
		Ret: TypeHandle;
		Args: U2;

		# size() U4 -- := SIZEOF(THIS) + ArgCount * SIZEOF(TypeHandle);
		# args() TypeHandle#[#] -- := <TypeHandle *>(&(&THIS)[1])[FOR ArgCount];
	}

	TplClass {
		Class: ir::Class-Handle;
		TemplateArgs: U4-IrArg; // TODO: We want to evaluate this and replace it with an actual deduplicated constant, probably. We can use additional un-hashed data to refer to a mapping: at the end of the TplClass as it appears in the AST, we append a field that contains an index into a context-dependent array. The array is then repopulated for each context, and contains the fully resolved type's ID. Does this have any advantages over a generic mapping? We also want to have constant-evaluated expressions mapped that way, probably.
	}

	// TODO: we probably want to merge the types and values from ir.rl.
	UNION CoreType
	{
		void;
		raw;

		u1;
		u2;
		u4;
		u8;
		um;
		s1;
		s2;
		s4;
		s8;
		sm;
		i1;
		i2;
		i4;
		i8;
		char;
		bool;

		IrOutput: U4;
		TemplateDependentIrOutput: U4; // We want to differentiate between things that could be resolved before full instantiation and things that are only at instantiation time.

		TemplateType: U4; // template argument index

		Class: ir::Class-Handle;
		TplClass: TplClass-Handle;

		FnSignature: MemID;
		TplFnSignature: TplFnSignature-Handle;

		Union: MemID;
		TplUnion: TplUnion-Handle;

		Rawtype: MemID;
		TplRawtype: TplRawType-Handle;

		IdSymbolConstant: Identifier;
		NumberSymbolConstant: S8;
		SpecialSymbolConstant: SpecialSymbol;
		TypeTemplatedIdSymbolConstant: {Identifier, Type-Handle};
		NumTemplatedIdSymbolConstant: {Identifier, Type-Handle};
	}

	ENUM Lifetime {
	*	instance, // an instance, not a reference.
	?	localReference, // Local variable, cannot be returned
	?	globalReference, // global variable
	?	expiringReference, // && reference, temporary value
	?	argReference, // function parameter reference, safe to return, turns into expiring reference when returning.
	?	thisReference // Reference to member of THIS. Could also point to things other than THIS maybe. Basically for container lifetime stuff. Tagging a pointer or reference with THIS lets us reason about memory much better at the type level without requiring an understanding of allocators.
	}

	// Dynamically sized type.
	Type
	{
		Core: TAGGED CoreType;
		Lifetime: ir::Lifetime;
		Modifiers: U1;
	}

	UNION Indirection
	{
		None;
		NonNullPtr;
		Ptr;
		ArrayResolved: U4;
		ArrayUnresolved: U4;
		UnsizedSlice;
		SizedSlice;
	}

	Modifier
	{
		Qualifier;
		Indirection;
	}
}