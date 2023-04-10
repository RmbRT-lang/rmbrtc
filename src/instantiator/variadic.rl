::rlc::instantiator VariadicExpansionTracker
{
	VariadicExpand: VariadicExpander -std::OptRef;
	register_variadic_expander(
		new: VariadicExpander \
	) VariadicExpander-std::OptRef
	{
		old ::= VariadicExpand;
		VariadicExpand := new;
		= old;
	}
	witness_variadic(referencePosition: src::Position, capacity: UINT) VOID
	{
		IF(!VariadicExpand)
			THROW <rlc::ReasonError>(referencePosition,
				"variadic value is not expanded");
		VariadicExpand->witness_capacity(referencePosition, capacity);
	}
	# variadic_index() UINT := VariadicExpand!;
}

/// Tracks occurrences of variadic templates, and acts as an iterator.
::rlc::instantiator VariadicExpander
{
	{expansionPos: src::Position, mgr: VariadicExpansionTracker \}:
		Mgr := mgr,
		Location := expansionPos,
		Prev := mgr->register_variadic_expander(&THIS);


	DESTRUCTOR { IF(Mgr) Mgr->VariadicExpand := Prev; }

	++THIS VOID
	{
		IF(!Capacity)
			THROW <rlc::ReasonError>(Location,
				"'...' does not refer to any variadic templates");
		ASSERT(Index < Capacity!);
		++Index;
	}

	witness_capacity(referencePosition: src::Position, capacity: UINT) VOID
	{
		IF(!Capacity)
		{
			Capacity := :a(capacity);
			FirstWitness := :a(referencePosition);
		} ELSE IF(Capacity! != capacity)
		{
			THROW <rlc::ReasonError>(referencePosition,
				"variadic's arity mismatches previous variadic's");
		}
	}

	# THIS! UINT INLINE := Index;
	# <BOOL> := Capacity ?? Index < Capacity! : TRUE;
	# capacity() U2-std::Opt := Capacity;
PRIVATE:
	Mgr: VariadicExpansionTracker *;
	Index: U2;
	Capacity: U2 -std::Opt;
	Location: src::Position;
	FirstWitness: src::Position-std::Opt;

	Prev: THIS -std::OptRef;

	{#&}; {&&};
}