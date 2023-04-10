::rlc::util [T:TYPE] OptGuarded
{
	PRIVATE Phase: U1;
	PRIVATE V: T-std::NoDestruct;

	# exists() ? INLINE := Phase != 2;
	# accessible() ? INLINE := Phase == 0;
	# guarded() ? INLINE := Phase == 1;

	{BARE} := NULL;
	{NULL}: Phase := 2, V := NOINIT;

	#? *THIS T #? &
	{
		ASSERT(accessible());
		= *V;
	}

	[Args...:TYPE] create_guarded(args: Args!&&...) T& INLINE
	{
		ASSERT(!exists());
		Phase := 1;
		V.{<Args!&&>(args)...};
		= *V;
	}

	guard() T& INLINE {
		ASSERT(accessible());
		++Phase;
		= *V;
	}

	release() VOID
	{
		ASSERT(Phase == 1);
		Phase := 0;
	}
}