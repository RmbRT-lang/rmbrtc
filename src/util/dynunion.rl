INCLUDE 'std/help'

::rlc::util [A:TYPE, B:TYPE] DynUnion
{
PRIVATE:
	UNION Union
	{
		Check: VOID # *; // For NULL-checking.
		First: A! *;
		Second: B! *;
	}

	Ptr: Union;
	IsB: bool;
PUBLIC:
	CONSTRUCTOR(): IsB(FALSE)
	{
		Ptr.First := NULL;
	}

	CONSTRUCTOR(p: A! *):
		IsB(FALSE)
	{
		Ptr.First := p;
	}
	CONSTRUCTOR(p: B! *):
		IsB(TRUE)
	{
		Ptr.Second := p;
	}

	CONSTRUCTOR(move: [A!,B!]DynUnion &&):
		Ptr(move.Ptr),
		IsB(move.IsB)
	{
		move.CONSTRUCTOR();
	}

	DESTRUCTOR
	{
		IF(is_first())
			::delete(first());
		ELSE IF(is_second())
			::delete(second());
	}

	# is_first() INLINE bool := !IsB && Ptr.First;
	# is_second() INLINE bool := IsB && Ptr.Second;
	# is_empty() INLINE bool := !Ptr.Check;

	# LOG_NOT() INLINE bool := !Ptr.Check;
	# CONVERT(bool) NOTYPE! := Ptr.Check;

	# first() A! \
	{
		IF(!is_first()) THROW;
		RETURN Ptr.First;
	}

	# second() B! \
	{
		IF(!is_second()) THROW;
		RETURN Ptr.Second;
	}

	ASSIGN(move: [A!,B!]DynUnion &&) [A!,B!]DynUnion &
		:= std::help::move_assign(*THIS, move);
	ASSIGN(p: A! *) [A!,B!]DynUnion &
		:= std::help::custom_assign(*THIS, p);
	ASSIGN(p: B! *) [A!,B!]DynUnion &
		:= std::help::custom_assign(*THIS, p);
}