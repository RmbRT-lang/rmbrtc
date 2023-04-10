INCLUDE 'std/nodestruct'

::rlc::instantiator [T:TYPE] Resolveable
{
	ENUM StateE { undetermined, resolving, failed, resolved }
	UNION ValueU {
		Resolved: T;
		Error: std::Error - std::Shared;
	}
	State: StateE;
	Value: ValueU;

	{} := BARE;
	{BARE}: State := :undetermined;
	{&&mv}: State := mv.State
	{
		IF(State == :resolved)
			Value.Resolved.{&&mv.Value.Resolved};
		ELSE IF(State == :failed)
			Value.Error.{&&mv.Value.Error};
	}


	#? *THIS T#?&
	{
		SWITCH(State)
		{
		:resolved: = Value.Resolved;
		:failed: THROW Value.Error;
		:resolving, :undetermined: THROW "unresolved";
		}
	}

	#? THIS! T#?& INLINE := *THIS;

	# determined() BOOL INLINE := State != :undetermined && State != :resolving;
	# resolved() BOOL INLINE := State == :resolved;
	# failed() BOOL INLINE := State == :failed;
	start_resolving(pos: ast::CodeObject #&) VOID
	{
		ASSERT(!determined());

		SWITCH(State)
		{
		:undetermined: State := :resolving;
		:resolving: fail(<ReasonError>(pos.Position, "cyclic dependency"));
		}
	}

	[Args...:TYPE] resolve(args: Args!&&...) VOID
	{
		ASSERT(State == :resolving);
		Value.Resolved.{<Args!&&>(args)...};
		State := :resolved;
	}

	[Err: TYPE] fail(mv: Err!&&) VOID
	{
		ASSERT(State == :resolving);
		Value.Error.{:dup(&&mv)};
		State := :failed;
		THROW Value.Error;
	}

	fail_share(err: std::Error-std::Shared) VOID
	{
		ASSERT(State == :resolving);
		Value.Error.{&&err};
		State := :failed;
		THROW Value.Error;
	}

	DESTRUCTOR
	{
		IF(State == :resolved) Value.Resolved.~;
		ELSE IF(State == :failed) Value.Error.~;
	}
}