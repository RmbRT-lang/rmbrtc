::rlc::instantiator OrType -> ast::[Config]Type
{
PRIVATE:
	/// Type -> Index.
	TypesMap: U2 - std::[ast::[Config]Type#-std::Ref]Map;
	Types: ast::[Config]Type-std::DynVec; /// The actual types of the or-type, unsorted.

PUBLIC:
	# index(t: ast::[Config]Type #&) U2 - std::Opt
	{
		IF(f ::= TypesMap.find(&t))
			= :a(f!);
		= NULL;
	}

	THIS += (t: ast::[Config]Type-std::Dyn) VOID
	{
		IF(or ::= <<OrType *>>(t))
			FOR(candidate ::= or->Types.start())
				insert_1(&&*candidate);
		ELSE
			insert_1(&&t);
	}

	#? start() ? := Types.start();

	PRIVATE insert_1(t: ast::[Config]Type-std::Dyn) VOID
	{
		entry_and_loc ::= TypesMap.find_loc(&t!);
		IF(entry_and_loc.(0))
			RETURN;

		TypesMap.insert_at(entry_and_loc.(1), t.ptr(), ##Types);
		Types += &&t;
	}
}