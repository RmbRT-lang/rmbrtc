INCLUDE "global.rl"
INCLUDE "member.rl"
INCLUDE "variable.rl"
INCLUDE "name.rl"
INCLUDE "templatedecl.rl"
INCLUDE "statement.rl"


::rlc::ast [Stage:TYPE] FnSignature VIRTUAL
{
	Arguments: [Stage]TypeOrArgument-std::DynVec;
	IsCoroutine: BOOL;
}

::rlc::ast [Stage:TYPE] UnresolvedSig -> [Stage]FnSignature
{
	Return: type::[Stage]Auto;
}

::rlc::ast [Stage:TYPE] ResolvedSig -> [Stage]FnSignature
{
	Return: [Stage]Type-std::Dyn;

	{};
	{
		args: [Stage]TypeOrArgument-std::DynVec&&,
		isCoroutine: BOOL,
		return: [Stage]Type-std::Dyn
	} -> (&&args, isCoroutine): Return := &&return;
}

/// An anonymous function object.
::rlc::ast [Stage:TYPE] Functoid VIRTUAL -> CodeObject
{
	Signature: [Stage]FnSignature - std::Dyn;
	Body: [Stage]Statement - std::Dyn;
	IsInline: BOOL;

	STATIC short_hand_body(e: [Stage]Expression-std::Dyn) [Stage]Statement-std::Dyn
	{
		std::heap::[[Stage]ReturnStatement]new(e);
	}
}

::rlc::ast [Stage: TYPE] VariantMergeError {
	Function: ast::[Stage]Function \;
	Name: Stage::Name;
	Old: [Stage]Variant \;
	New: [Stage]Variant \;
}

(// A named function with potential callable variants. /)
::rlc::ast [Stage:TYPE] Function VIRTUAL -> [Stage]MergeableScopeItem
{
	Default: [Stage]DefaultVariant-std::Shared;

	ENUM SpecialVariant {
		null
	}

	SpecialVariants: std::[SpecialVariant; ast::[Stage]SpecialVariant-std::Shared]NatMap;
	(// The function's variant implementations. /)
	Variants: std::[Stage-Name; [Stage]Variant-std::Shared]NatMap;

	PRIVATE FINAL merge_impl(rhs: [Stage]MergeableScopeItem &&) VOID
	{
		from: ?& := <<[Stage]Function &>>(rhs);
		IF(from.Default)
		{
			IF(Default)
				THROW <[Stage]MergeError>(&THIS, &from);
			Default := from.Default;
		}

		FOR(var ::= from.Variants.start(); var; ++var)
		{
			IF(prev ::= Variants.find(var!.(0)))
				IF((*prev)! != var!.(1)!)
					THROW <[Stage]VariantMergeError>(
						&THIS, var!.(0),
						*prev, var!.(1));
			Variants.insert(var!.(0), var!.(1));
		}
	}
}

/// Global function.
::rlc::ast [Stage:TYPE] GlobalFunction -> [Stage]Global, [Stage]Function { }

/// A reference to an external function. Cannot have variants.
::rlc::ast [Stage:TYPE] ExternFunction ->
	[Stage]Global,
	[Stage]ScopeItem,
	[Stage]ExternSymbol
{
	Signature: [Stage]ResolvedSig;

	{
		name: Stage::Name,
		signature: [Stage]ResolvedSig &&,
		linkName: Stage-Name - std::Opt
	} -> (), (&&name), (&&linkName):
		Signature(&&signature);
}

::rlc::ast [Stage:TYPE] DefaultVariant -> [Stage]Functoid { }
::rlc::ast [Stage:TYPE] SpecialVariant -> [Stage]Functoid {
	Variant: [Stage]Function::SpecialVariant;
}
::rlc::ast [Stage:TYPE] Variant -> [Stage]Functoid {
	Name: ast::[Stage]Name;
}

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
	# type() [Stage]Type #\ INLINE := <<[Stage]Type #\>>([Stage]Functoid::Return!);
}

::rlc::ast [Stage:TYPE] MemberFunction -> [Stage]Abstractable, [Stage]Function
{
}

/// Custom operator implementation.
::rlc::ast [Stage:TYPE] Operator -> [Stage]Abstractable, [Stage]Functoid
{
	Op: rlc::Operator;
	{}: Op(NOINIT);
}

::rlc::ast [Stage:TYPE] Factory -> [Stage]Member, [Stage]Functoid
{
}