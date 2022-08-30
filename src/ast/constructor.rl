INCLUDE "variable.rl"
INCLUDE "expression.rl"
INCLUDE "symbol.rl"
INCLUDE "symbolconstant.rl"
INCLUDE "statement.rl"

INCLUDE 'std/vector'
INCLUDE 'std/memory'

::rlc::ast [Stage: TYPE] Constructor VIRTUAL ->
	[Stage]Member,
	[Stage]Templateable,
	CodeObject
{
	Initialisers VIRTUAL {
		<<<
			p: [Stage::Prev+]Constructor::Initialisers #\,
			f: Stage::PrevFile+,
			s: Stage &
		>>> THIS - std::Dyn
		{
			TYPE SWITCH(p)
			{
			[Stage::Prev+]Constructor::ExplicitInits+:
				= :dup(<ExplicitInits>(:transform(
					<<[Stage::Prev+]Constructor::ExplicitInits+ #&>>(*p), f, s)));
			[Stage::Prev+]Constructor::CtorAlias+:
				= :dup(<CtorAlias>(:transform(
					<<[Stage::Prev+]Constructor::CtorAlias #&>>(*p), f, s)));
			}
		}
	}

	BaseInit -> CodeObject
	{
		Base: Stage::Inheritance;
		Arguments: [Stage]Expression - std::DynVec;

		:transform{
			p: [Stage::Prev+]Constructor::BaseInit+ #&,
			f: Stage::PrevFile+,
			s: Stage &
		}:
			Base := s.transform_inheritance(p.Base, f),
			Arguments := :reserve(##p.Arguments)
		{
			FOR(a ::= p.Arguments.start())
				Arguments += <<<[Stage]Expression>>>(a!, f, s);
		}
	}

	MemberInit -> CodeObject
	{
		Member: Stage::MemberVariableReference;
		Arguments: [Stage]Expression - std::DynVec;

		:transform{
			p: [Stage::Prev+]Constructor::MemberInit+ #&,
			f: Stage::PrevFile+,
			s: Stage &
		}:
			Member := s.transform_member_variable_reference(p.Member, f),
			Arguments := :reserve(##p.Arguments)
		{
			FOR(a ::= p.Arguments.start())
				Arguments += <<<[Stage]Expression>>>(a!, f, s);
		}
	}

	ExplicitInits -> Initialisers
	{
		BaseInits: BaseInit - std::Vec;
		MemberInits: MemberInit - std::Vec;

		:transform{
			p: [Stage::Prev+]Constructor::ExplicitInits+ #&,
			f: Stage::PrevFile+,
			s: Stage &
		}:
			BaseInits := :reserve(##p.BaseInits),
			MemberInits := :reserve(##p.MemberInits)
		{
			FOR(i ::= p.BaseInits.start())
				BaseInits += :transform(i!, f, s);
			FOR(i ::= p.MemberInits.start())
				MemberInits += :transform(i!, f, s);
		}
	}

	CtorAlias -> Initialisers
	{
		Arguments: [Stage]Expression - std::DynVec;

		:transform{
			p: [Stage::Prev+]Constructor::CtorAlias+ #&,
			f: Stage::PrevFile+,
			s: Stage &
		}:
			Arguments := :reserve(##p.Arguments)
		{
			FOR(a ::= p.Arguments.start())
				Arguments += <<<[Stage]Expression>>>(a!, f, s);
		}
	}

	Inits: Initialisers - std::Dyn;
	Body: [Stage]BlockStatement - std::Dyn;
	Inline: BOOL;

	:transform{
		p: [Stage::Prev+]Constructor #&,
		f: Stage::PrevFile+,
		s: Stage &
	} -> (:transform, p), (:transform, p, f, s), (p):
		Inline := p.Inline
	{
		IF(p.Inits)
			Inits := <<<Initialisers>>>(p.Inits!, f, s);
		IF(p.Body)
			Body := :a(:transform(*p.Body!, f, s));
	}

	<<<
		p: [Stage::Prev+]Constructor #\,
		f: Stage::PrevFile+,
		s: Stage &
	>>> THIS - std::Dyn
	{
		TYPE SWITCH(p)
		{
		[Stage::Prev+]NullConstructor:
		= :dup(<[Stage]NullConstructor>(:transform(
			<<[Stage::Prev+]NullConstructor #&>>(*p), f, s)));
		[Stage::Prev+]BareConstructor:
		= :dup(<[Stage]BareConstructor>(:transform(
			<<[Stage::Prev+]BareConstructor #&>>(*p), f, s)));
		[Stage::Prev+]CustomConstructor:
		= :dup(<[Stage]CustomConstructor>(:transform(
			<<[Stage::Prev+]CustomConstructor #&>>(*p), f, s)));
		[Stage::Prev+]DefaultConstructor:
			= :dup(<[Stage]DefaultConstructor>(:transform(
				<<[Stage::Prev+]DefaultConstructor #&>>(*p), f, s)));
		[Stage::Prev+]CopyConstructor:
			= :dup(<[Stage]CopyConstructor>(:transform(
				<<[Stage::Prev+]CopyConstructor #&>>(*p), f, s)));
		[Stage::Prev+]MoveConstructor:
			= :dup(<[Stage]MoveConstructor>(:transform(
				<<[Stage::Prev+]MoveConstructor #&>>(*p), f, s)));
		}
	}
}


::rlc::ast [Stage: TYPE] StructuralConstructor -> [Stage]Constructor
{
	:transform{
		p: [Stage::Prev+]StructuralConstructor #&,
		f: Stage::PrevFile+,
		s: Stage &
	} -> (:transform, p, f, s);
}

::rlc::ast [Stage: TYPE] DefaultConstructor -> [Stage]Constructor
{
	:transform{
		p: [Stage::Prev+]DefaultConstructor #&,
		f: Stage::PrevFile+,
		s: Stage &
	} -> (:transform, p, f, s);
}

::rlc::ast [Stage: TYPE] NullConstructor -> [Stage]Constructor
{
	:transform{
		p: [Stage::Prev+]NullConstructor #&,
		f: Stage::PrevFile+,
		s: Stage &
	} -> (:transform, p, f, s);
}

::rlc::ast [Stage: TYPE] BareConstructor -> [Stage]Constructor
{
	:transform{
		p: [Stage::Prev+]BareConstructor #&,
		f: Stage::PrevFile+,
		s: Stage &
	} -> (:transform, p, f, s);
}

::rlc::ast [Stage: TYPE] CopyConstructor -> [Stage]Constructor
{
	Argument: ast::[Stage]Argument-std::Opt;

	:named_arg{
		name: Stage::Name
	} -> (BARE): Argument(:a(name, :gc(std::heap::[[Stage]ThisType]new(:cref))));
	:unnamed_arg{} -> (BARE);

	:transform{
		p: [Stage::Prev+]CopyConstructor #&,
		f: Stage::PrevFile+,
		s: Stage &
	} -> (:transform, p, f, s)
	{
		IF(p.Argument)
			Argument := :a(:transform(p.Argument!, f, s));
	}
}

::rlc::ast [Stage: TYPE] MoveConstructor -> [Stage]Constructor
{
	Argument: ast::[Stage]Argument-std::Opt;

	{};
	:named_arg{
		name: Stage::Name
	} -> (BARE): Argument(:a(name, :gc(std::heap::[[Stage]ThisType]new(:tempRef))));
	:unnamed_arg{} -> (BARE);

	:transform{
		p: [Stage::Prev+]MoveConstructor #&,
		f: Stage::PrevFile+,
		s: Stage &
	} -> (:transform, p, f, s)
	{
		IF(p.Argument)
			Argument := :a(:transform(p.Argument!, f, s));
	}
}

::rlc::ast [Stage: TYPE] CustomConstructor -> [Stage]Constructor
{
	Name: [Stage]SymbolConstant - std::Opt;
	Arguments: [Stage]TypeOrArgument - std::DynVec;

	# named() BOOL INLINE := Name;

	:transform{
		p: [Stage::Prev+]CustomConstructor #&,
		f: Stage::PrevFile+,
		s: Stage &
	} -> (:transform, p, f, s):
		Arguments := :reserve(##p.Arguments)
	{
		IF(p.Name)
			Name := :a(:transform(p.Name!, f, s));

		FOR(a ::= p.Arguments.start())
			Arguments += <<<[Stage]TypeOrArgument>>>(a!, f, s);
	}

	PRIVATE TYPE Self := THIS;
	Cmp
	{
		STATIC cmp(
			lhs: Self#&,
			rhs: Self#&) ?
		{
			IF(lhs.Name)
			{
				IF(rhs.Name)
					= [Stage]SymbolConstant::Cmp::cmp(lhs.Name!, rhs.Name!);
				ELSE
					= 1;
			} ELSE IF(rhs.Name)
			{
				= -1;
			} ELSE
				= 0;
		}
	}
}