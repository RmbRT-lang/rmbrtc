INCLUDE 'std/help'

::rlc::util [A:TYPE; B:TYPE] DynUnion
{
PRIVATE:
	UNION Union
	{
		Check: VOID # *; // For NULL-checking.
		First: A! *;
		Second: B! *;
	}

	Ptr: Union;
	IsB: BOOL;
PUBLIC:
	{}: IsB(FALSE)
	{
		Ptr.First := NULL;
	}

	{p: A! *}:
		IsB(FALSE)
	{
		Ptr.First := p;
	}
	{p: B! *}:
		IsB(TRUE)
	{
		Ptr.Second := p;
	}

	{move: [A!;B!]DynUnion &&}:
		Ptr(move.Ptr),
		IsB(move.IsB)
	{
		move.{};
	}

	DESTRUCTOR
	{
		IF(is_first())
			std::delete(first());
		ELSE IF(is_second())
			std::delete(second());
	}

	# is_first() INLINE BOOL := !IsB && Ptr.First;
	# is_second() INLINE BOOL := IsB && Ptr.Second;
	# is_empty() INLINE BOOL := !Ptr.Check;

	# !THIS INLINE BOOL := !Ptr.Check;
	# <BOOL> INLINE := Ptr.Check;

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

	THIS:=(move: [A!;B!]DynUnion &&) [A!;B!]DynUnion &
		:= std::help::move_assign(THIS, move);
	THIS:=(p: A! *) [A!;B!]DynUnion &
		:= std::help::custom_assign(THIS, p);
	THIS:=(p: B! *) [A!;B!]DynUnion &
		:= std::help::custom_assign(THIS, p);
}