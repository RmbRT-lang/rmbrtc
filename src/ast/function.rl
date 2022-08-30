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

	<<<
		p: [Stage::Prev+]FnSignature #\,
		f: Stage::PrevFile+,
		s: Stage &
	>>> THIS-std::Dyn
	{
		TYPE SWITCH(p)
		{
		[Stage::Prev+]UnresolvedSig:
			= :dup(<[Stage]UnresolvedSig>(:transform(
				<<[Stage::Prev+]UnresolvedSig #&>>(*p), f, s)));
		[Stage::Prev+]ResolvedSig:
			= :dup(<[Stage]ResolvedSig>(:transform(
				<<[Stage::Prev+]ResolvedSig #&>>(*p), f, s)));
		}
	}

	{...};

	:transform {
		p: [Stage::Prev+]FnSignature #&,
		f: Stage::PrevFile+,
		s: Stage &
	}:
		Arguments := :reserve(##p.Arguments),
		IsCoroutine := p.IsCoroutine
	{
		FOR(a ::= p.Arguments.start())
			Arguments += <<<[Stage]TypeOrArgument>>>(a!, f, s);
	}
}

::rlc::ast [Stage:TYPE] UnresolvedSig -> [Stage]FnSignature
{
	Return: type::[Stage]Auto;

	:transform {
		p: [Stage::Prev+]UnresolvedSig #&,
		f: Stage::PrevFile+,
		s: Stage &
	} -> (:transform, p, f, s):
		Return := :transform(p.Return);
}

::rlc::ast [Stage:TYPE] ResolvedSig -> [Stage]FnSignature
{
	Return: [Stage]Type-std::Dyn;

	{
		args: [Stage]TypeOrArgument-std::DynVec&&,
		isCoroutine: BOOL,
		return: [Stage]Type-std::Dyn
	} -> (&&args, isCoroutine): Return := &&return;

	:transform{
		p: [Stage::Prev+]ResolvedSig #&,
		f: Stage::PrevFile+,
		s: Stage &
	} -> (:transform, p, f, s):
		Return := <<<[Stage]Type>>>(p.Return!, f, s);
}

/// An anonymous function object.
::rlc::ast [Stage:TYPE] Functoid VIRTUAL -> [Stage]Templateable, CodeObject
{
	Signature: [Stage]FnSignature - std::Dyn;
	Body: [Stage]ExprOrStatement - std::Dyn;
	IsInline: BOOL;

	:transform{
		p: [Stage::Prev+]Functoid #&,
		f: Stage::PrevFile+,
		s: Stage &
	} -> (:transform, p, f, s), (p):
		Signature := <<<[Stage]FnSignature>>>(p.Signature!, f, s),
		IsInline := p.IsInline
	{
		IF(p.Body)
			Body := <<<[Stage]ExprOrStatement>>>(p.Body!, f, s);
	}

	STATIC short_hand_body(e: [Stage]Expression-std::Dyn) [Stage]Statement-std::Dyn
		:= :dup(<[Stage]ReturnStatement>(:exp(&&e)));
}

::rlc::ast [Stage: TYPE] VariantMergeError {
	Function: ast::[Stage]Function \;
	Name: Stage::Name;
	Old: [Stage]Variant \;
	New: [Stage]Variant \;
}

::rlc::ast::function ENUM SpecialVariant {
		null
}

(// A named function with potential callable variants. /)
::rlc::ast [Stage:TYPE] Function VIRTUAL -> [Stage]MergeableScopeItem
{
	Default: [Stage]DefaultVariant-std::Shared;

	SpecialVariants: std::[function::SpecialVariant; ast::[Stage]SpecialVariant-std::Shared]NatMap;
	(// The function's variant implementations. /)
	Variants: std::[Stage-Name; [Stage]Variant-std::Shared]NatMap;

	:transform {
		p: [Stage::Prev+]Function #&,
		f: Stage::PrevFile+,
		s: Stage &
	} -> (:transform, p, f, s)
	{
		IF(p.Default)
			Default := :a(:transform(*p.Default!, f, s));
		FOR(var ::= p.SpecialVariants.start())
			SpecialVariants.insert(var!.(0), :a(:transform(*var!.(1)!, f, s)));
		FOR(var ::= p.Variants.start())
			Variants.insert(
				s.transform_name(var!.(0), f),
				:a(:transform(*var!.(1)!, f, s)));
	}

	set_templates_after_parsing(tpl: [Stage]TemplateDecl &&) VOID
	{
		IF(Default)
			Default->Templates := &&tpl;
		ELSE IF(##SpecialVariants)
			SpecialVariants.start()->(1)->Templates := &&tpl;
		ELSE
			Variants.start()->(1)->Templates := &&tpl;
	}

	PRIVATE FINAL merge_impl(rhs: [Stage]MergeableScopeItem &&) VOID
	{
		from: ?& := <<[Stage]Function &>>(rhs);
		IF(from.Default)
		{
			IF(Default)
				THROW <[Stage]MergeError>(&THIS, &from);
			Default := from.Default;
		}

		FOR(var ::= from.Variants.start())
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
::rlc::ast [Stage:TYPE] GlobalFunction -> [Stage]Global, [Stage]Function {
	:transform{
		p: [Stage::Prev+]GlobalFunction #&,
		f: Stage::PrevFile+,
		s: Stage &
	} -> (), (:transform, p, f, s);
}

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
		linkName: Stage::StringLiteral+ - std::Opt
	} -> (), (&&name), (&&linkName):
		Signature(&&signature);

	:transform{
		p: [Stage::Prev+]ExternFunction #&,
		f: Stage::PrevFile+,
		s: Stage &
	} -> (), (:transform, p, f, s), (:transform, p, f, s):
		Signature(:transform(p.Signature, f, s));
}

::rlc::ast [Stage:TYPE] DefaultVariant -> [Stage]Functoid {
	:transform{
		p: [Stage::Prev+]DefaultVariant #&,
		f: Stage::PrevFile+,
		s: Stage &
	} -> (:transform, p, f, s);
}
::rlc::ast [Stage:TYPE] SpecialVariant -> [Stage]Functoid {
	Variant: function::SpecialVariant;

	:transform{
		p: [Stage::Prev+]SpecialVariant #&,
		f: Stage::PrevFile+,
		s: Stage &
	} -> (:transform, p, f, s):
		Variant := p.Variant;
}
::rlc::ast [Stage:TYPE] Variant -> [Stage]Functoid {
	Name: Stage::Name+;

	:transform{
		p: [Stage::Prev+]Variant #&,
		f: Stage::PrevFile+,
		s: Stage &
	} -> (:transform, p, f, s):
		Name := s.transform_name(p.Name, f);
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

	:transform{
		p: [Stage::Prev+]Abstractable #&
	} -> (:transform, p):
		Abstractness := p.Abstractness;


	<<<
		p: [Stage::Prev+]Abstractable #\,
		f: Stage::PrevFile+,
		s: Stage &
	>>> THIS - std::Dyn
	{
		TYPE SWITCH(p)
		{
		[Stage::Prev+]Converter:
			= :dup(<[Stage]Converter>(:transform(
				<<[Stage::Prev+]Converter #&>>(*p), f, s)));
		[Stage::Prev+]MemberFunction:
			= :dup(<[Stage]MemberFunction>(:transform(
				<<[Stage::Prev+]MemberFunction #&>>(*p), f, s)));
		[Stage::Prev+]Operator:
			= :dup(<[Stage]Operator>(:transform(
				<<[Stage::Prev+]Operator #&>>(*p), f, s)));
		}
	}
}

(// Type conversion operator. /)
::rlc::ast [Stage:TYPE] Converter -> [Stage]Abstractable, [Stage]Functoid
{
	:transform{
		p: [Stage::Prev+]Converter #&,
		f: Stage::PrevFile+,
		s: Stage &
	} -> (:transform, p), (:transform, p, f, s);

	# type() [Stage]Type #\ INLINE := <<[Stage]Type #\>>([Stage]Functoid::Return!);
}

::rlc::ast [Stage:TYPE] MemberFunction -> [Stage]Abstractable, [Stage]Function
{
	:transform{
		p: [Stage::Prev+]MemberFunction #&,
		f: Stage::PrevFile+,
		s: Stage &
	} -> (:transform, p), (:transform, p, f, s);
}

/// Custom operator implementation.
::rlc::ast [Stage:TYPE] Operator -> [Stage]Abstractable, [Stage]Functoid
{
	Op: rlc::Operator;

	:transform{
		p: [Stage::Prev+]Operator #&,
		f: Stage::PrevFile+,
		s: Stage &
	} -> (:transform, p), (:transform, p, f, s):
		Op := p.Op;
}

::rlc::ast [Stage:TYPE] Factory -> [Stage]Member, [Stage]Functoid
{
	:transform{
		p: [Stage::Prev+]Factory #&,
		f: Stage::PrevFile+,
		s: Stage &
	} -> (:transform, p), (:transform, p, f, s);
}