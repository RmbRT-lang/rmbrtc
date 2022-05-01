INCLUDE "global.rl"
INCLUDE "member.rl"
INCLUDE "variable.rl"
INCLUDE "name.rl"
INCLUDE "templatedecl.rl"
INCLUDE "statement.rl"

(//
An anonymous function object that models a callable function.
/)
::rlc::ast [Stage:TYPE] Functoid VIRTUAL -> CodeObject
{
	Arguments: [Stage]TypeOrArgument-std::DynVec;
	Return: [Stage]MaybeAutoType-std::Dyn;
	Body: [Stage]Statement - std::Dyn;
	IsInline: BOOL;
	IsCoroutine: BOOL;

	STATIC short_hand_body(e: [Stage]Expression-std::Dyn) [Stage]Statement-std::Dyn
	{
		std::heap::[[Stage]ReturnStatement]new(e);
	}
}

(// A named functoid referrable to by name. /)
::rlc::ast [Stage:TYPE] Function VIRTUAL -> [Stage]MergeableScopeItem
{
	Default: [Stage]Functoid-std::Shared;

	ENUM SpecialVariant {
		null
	}

	SpecialVariants: std::[SpecialVariant; [Stage]Functoid-std::Shared]NatMap;
	(// The function's variant implementations. /)
	Variants: std::[Stage-Name; [Stage]Functoid-std::Shared]NatMap;

	PRIVATE FINAL merge_impl(rhs: [Stage]MergeableScopeItem &&) VOID
	{
		from: ?& := <<[Stage]Function &>>(rhs);
		IF(from.Default)
		{
			IF(Default)
				THROW <[Stage]MergeError>(THIS, from);
			Default := from.Default;
		}

		FOR(var ::= from.Variants.start(); var; ++var)
		{
			IF(prev ::= Variants.find(var!.(0)))
				IF(prev! != var!.(1)!)
					THROW <[Stage]VariantMergeError>(THIS, var!.(0), *prev, var!.(0));
			Variants.insert(var!.(0), var!.(1));
		}
	}
}

/// Global function.
::rlc::ast [Stage:TYPE] GlobalFunction -> [Stage]Global, [Stage]Function { }

::rlc ENUM Abstractness
{
	none,
	virtual,
	abstract,
	override,
	final
}

/// All functions that can be abstracted: functions, operators, converters.
::rlc::ast [Stage:TYPE] Abstractable VIRTUAL -> [Stage]Member
{
	Abstractness: rlc::Abstractness;

	{}: Abstractness(:none);
}

(// Type conversion operator. /)
::rlc::ast [Stage:TYPE] Converter -> [Stage]Abstractable, [Stage]Functoid
{
	# type() INLINE [Stage]Type #\ := <<[Stage]Type #\>>([Stage]Functoid::Return!);
}

::rlc::ast [Stage:TYPE] MemberFunction -> [Stage]Abstractable, [Stage]Function
{
}

/// Custom operator implementation.
::rlc::ast [Stage:TYPE] Operator -> [Stage]Abstractable, [Stage]Functoid
{
	Op: rlc::Operator;
}

::rlc::ast [Stage:TYPE] Factory -> [Stage]Member, [Stage]Functoid
{
}