::rlc::values
{
	// Keep below 32 variants, or adjust PackedStorageLink bit distribution.
	UNION Storage {
		IntegerConstant: U8;
		ExpressionLink: U4; // Unparsed expression
	}

	PackedStorageLink {
		Data: U2; // 11 bits for ID, 5 bits for type tag of storage union.

		{tag: ENUM Storage, id: U2}: Data := <U2>(tag) << 11 | id;

		# type() ENUM Storage -- := >(Data >> 11);
		# id() U2 := Data & (1<<11-1);
	}

	UNION ByteCode {
	}

	ByteCodeSpan {
		Start: U4;
		End: U4;
	}



	TYPE InterleavedByteCodes := TAGGED types::ByteCode[128];
	MAX_REQUESTS: U4 # := ###InterleavedByteCodes;

	RequestContext {
		Ns: parser::NamespaceID;
		Ms: parser::MemberScopeID;
		StorageStart: U4;
	}

	// Up to ###InterleavedByteCodes requests.
	RequestBatch
	{
		Code: InterleavedByteCodes[#]; // Bytecode sequences of all requests, interleaved and concatenated.
		Contexts: RequestContext[###InterleavedByteCodes];
		Storage: types::Storage[#];
		Count: U2; // number of requests.
		Positions: src::Position[###InterleavedByteCodes][#];
		RequestsByStartingByteCode: ByteCodeSpan[#][TABLE ENUM types::ByteCode]; // Per starting bytecode: bucket of bytecode sequences.
	}
}