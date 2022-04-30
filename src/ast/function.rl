INCLUDE "global.rl"
INCLUDE "member.rl"
INCLUDE "variable.rl"
INCLUDE "templatedecl.rl"
INCLUDE "statement.rl"

(//
An anonymous function object that models a callable function.
/)
::rlc::ast [Stage:TYPE] Functoid VIRTUAL -> CodeObject
{
	Arguments: [Stage]TypeOrArgument-std::DynVector;
	Return: [Stage]MaybeAutoType-std::Dyn;
	Body: [Stage]Statement - std::Dyn;
	IsInline: BOOL;
	IsCoroutine: BOOL;

	STATIC short_hand_body(e: Expression-std::Dyn) Statement-std::Dyn
	{
		std::[ReturnStatement]new(e);
	}
}

(// A named functoid referrable to by name. /)
::rlc::ast [Stage:TYPE] Function VIRTUAL -> [Stage]MergeableScopeItem
{
	Default: [Stage]Functoid-std::Shared;

	ENUM SpecialVariant {
		null,
		noinit
	}

	SpecialVariants: std::[SpecialVariant; [Stage]Functoid-std::Shared]NatMap;
	(// The function's variant implementations. /)
	Variants: std::[Stage::Name; [Stage]Functoid-std::Shared]NatMap;

	PRIVATE FINAL merge_impl(rhs: [Stage]MergeableScopeItem #&) VOID
	{
		from: ?& := <<[Stage]Function &>>(rhs);
		IF(from.Default)
		{
			IF(Default)
				THROW <MergeError>(THIS, from);
			Default := from.Default;
		}

		FOR(var ::= from.Variants.start(); var; ++var)
		{
			IF(prev ::= Variants.find(var!.(0)))
				IF(prev! != var!.(1)!)
					THROW <VariantMergeError>(THIS, var!.(0), *prev, var!.(0));
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
::rlc::ast [Stage:TYPE] Abstractable VIRTUAL -> Member
{
	Abstractness: rlc::Abstractness;
}

(// Type conversion operator. /)
::rlc::ast [Stage:TYPE] Converter -> [Stage]Abstractable, [Stage]Functoid
{
	# type() INLINE Type #\ := Functoid::Return.type();
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