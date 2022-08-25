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
			[Stage::Prev+]Constructor::ExplicitInits:
				= :dup(<ExplicitInits>(:transform(
					<<[Stage::Prev+]Constructor::ExplicitInits #&>>(*p), f, s)));
			[Stage::Prev+]Constructor::CtorAlias:
				= :dup(<CtorAlias>(:transform(
					<<[Stage::Prev+]Constructor::CtorAlias #&>>(*p), f, s)));
			}
		}
	}

	BaseInit -> CodeObject
	{
		Base: Stage::Inheritance;
		Arguments: [Stage]Expression - std::DynVec;
	}

	MemberInit -> CodeObject
	{
		Member: Stage::MemberVariableReference;
		Arguments: [Stage]Expression - std::DynVec;
	}

	ExplicitInits -> Initialisers
	{
		BaseInits: BaseInit - std::Vec;
		MemberInits: MemberInit - std::Vec;
	}

	CtorAlias -> Initialisers
	{
		Arguments: [Stage]Expression - std::DynVec;
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
			Body := <<<[Stage]BlockStatement>>>(:transform(p.Body!, f, s));
	}
}

::rlc::ast [Stage: TYPE] DefaultConstructor -> [Stage]Constructor
{
	:transform{
		p: [Stage::Prev+]DefaultConstructor #&,
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

	Cmp
	{
		STATIC cmp(lhs: THIS#&, rhs: THIS#&) ?
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