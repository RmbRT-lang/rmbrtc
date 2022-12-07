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
			p: [Stage::Prev+]Constructor::Initialisers #&,
			f: Stage::PrevFile+,
			s: Stage &,
			parent: [Stage]ScopeBase \
		>>> THIS - std::Dyn
		{
			TYPE SWITCH(p)
			{
			[Stage::Prev+]Constructor::ExplicitInits+:
				= :a.ExplicitInits(:transform(>>p, f, s, parent));
			[Stage::Prev+]Constructor::CtorAlias+:
				= :a.CtorAlias(:transform(>>p, f, s, parent));
			}
		}
	}

	BaseInit -> CodeObject
	{
		Arguments: [Stage]Expression - std::DynVec;

		:transform{
			p: [Stage::Prev+]Constructor::BaseInit+ #&,
			f: Stage::PrevFile+,
			s: Stage &,
			parent: [Stage]ScopeBase \
		} -> (p):
			Arguments := :reserve(##p.Arguments)
		{
			FOR(a ::= p.Arguments.start())
				Arguments += :make(a!, f, s, parent);
		}
	}

	MemberInit -> CodeObject
	{
		Member: Stage::MemberVariableReference;
		Arguments: [Stage]Expression - std::DynVec;

		:transform{
			p: [Stage::Prev+]Constructor::MemberInit+ #&,
			f: Stage::PrevFile+,
			s: Stage &,
			parent: [Stage]ScopeBase \
		} -> (p):
			Member := s.transform_member_variable_reference(p.Member, f),
			Arguments := :reserve(##p.Arguments)
		{
			FOR(a ::= p.Arguments.start())
				Arguments += <<<[Stage]Expression>>>(a!, f, s, parent);
		}
	}

	ExplicitInits -> Initialisers
	{
		BaseInits: BaseInit - std::Vec;
		MemberInits: MemberInit - std::Vec;

		:transform{
			p: [Stage::Prev+]Constructor::ExplicitInits+ #&,
			f: Stage::PrevFile+,
			s: Stage &,
			parent: [Stage]ScopeBase \
		}:
			BaseInits := :reserve(##p.BaseInits),
			MemberInits := :reserve(##p.MemberInits)
		{
			FOR(i ::= p.BaseInits.start())
				BaseInits += :transform(i!, f, s, parent);
			FOR(i ::= p.MemberInits.start())
				MemberInits += :transform(i!, f, s, parent);
		}
	}

	CtorAlias -> Initialisers
	{
		Arguments: [Stage]Expression - std::DynVec;

		:transform{
			p: [Stage::Prev+]Constructor::CtorAlias+ #&,
			f: Stage::PrevFile+,
			s: Stage &,
			parent: [Stage]ScopeBase \
		}:
			Arguments := :reserve(##p.Arguments)
		{
			FOR(a ::= p.Arguments.start())
				Arguments += :make(a!, f, s, parent);
		}
	}

	Inits: Initialisers - std::DynOpt;
	Body: [Stage]BlockStatement - std::DynOpt;
	Inline: BOOL;

	:transform{
		p: [Stage::Prev+]Constructor #&,
		f: Stage::PrevFile+,
		s: Stage &,
		parent: [Stage]ScopeBase \
	} -> (:transform, p), (:transform, p, f, s, parent), (p):
		Inits := :make_if(p.Inits, p.Inits.ok(), f, s, parent),
		Body := :if(p.Body, :transform(p.Body.ok(), f, s, parent)),
		Inline := p.Inline;

	<<<
		p: [Stage::Prev+]Constructor #&,
		f: Stage::PrevFile+,
		s: Stage &,
		parent: [Stage]ScopeBase \
	>>> THIS - std::Dyn
	{
		TYPE SWITCH(p)
		{
		[Stage::Prev+]NullConstructor:
			= :a.[Stage]NullConstructor(:transform(>>p, f, s, parent));
		[Stage::Prev+]BareConstructor:
			= :a.[Stage]BareConstructor(:transform(>>p, f, s, parent));
		[Stage::Prev+]CustomConstructor:
			= :a.[Stage]CustomConstructor(:transform(>>p, f, s, parent));
		[Stage::Prev+]DefaultConstructor:
			= :a.[Stage]DefaultConstructor(:transform(>>p, f, s, parent));
		[Stage::Prev+]CopyConstructor:
			= :a.[Stage]CopyConstructor(:transform(>>p, f, s, parent));
		[Stage::Prev+]MoveConstructor:
			= :a.[Stage]MoveConstructor(:transform(>>p, f, s, parent));
		}
	}
}


::rlc::ast [Stage: TYPE] StructuralConstructor -> [Stage]Constructor
{
	:transform{
		p: [Stage::Prev+]StructuralConstructor #&,
		f: Stage::PrevFile+,
		s: Stage &,
		parent: [Stage]ScopeBase \
	} -> (:transform, p, f, s, parent);
}

::rlc::ast [Stage: TYPE] DefaultConstructor -> [Stage]Constructor
{
	:transform{
		p: [Stage::Prev+]DefaultConstructor #&,
		f: Stage::PrevFile+,
		s: Stage &,
		parent: [Stage]ScopeBase \
	} -> (:transform, p, f, s, parent);
}

::rlc::ast [Stage: TYPE] NullConstructor -> [Stage]Constructor
{
	:transform{
		p: [Stage::Prev+]NullConstructor #&,
		f: Stage::PrevFile+,
		s: Stage &,
		parent: [Stage]ScopeBase \
	} -> (:transform, p, f, s, parent);
}

::rlc::ast [Stage: TYPE] BareConstructor -> [Stage]Constructor
{
	:transform{
		p: [Stage::Prev+]BareConstructor #&,
		f: Stage::PrevFile+,
		s: Stage &,
		parent: [Stage]ScopeBase \
	} -> (:transform, p, f, s, parent);
}

::rlc::ast [Stage: TYPE] CopyConstructor -> [Stage]Constructor
{
	Argument: ast::[Stage]Argument-std::Opt;

	:named_arg{
		name: Stage::Name
	} -> (BARE): Argument := :a(name, :a.[Stage]ThisType(:cref));
	:unnamed_arg{} -> (BARE);

	:transform{
		p: [Stage::Prev+]CopyConstructor #&,
		f: Stage::PrevFile+,
		s: Stage &,
		parent: [Stage]ScopeBase \
	} -> (:transform, p, f, s, parent)
	{
		IF(p.Argument)
			Argument := :a(:transform(p.Argument!, f, s, parent));
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
		s: Stage &,
		parent: [Stage]ScopeBase \
	} -> (:transform, p, f, s, parent)
	{
		IF(p.Argument)
			Argument := :a(:transform(p.Argument!, f, s, parent));
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
		s: Stage &,
		parent: [Stage]ScopeBase \
	} -> (:transform, p, f, s, parent):
		Arguments := :reserve(##p.Arguments)
	{
		IF(p.Name)
			Name := :a(:transform(p.Name!, f, s, parent));

		FOR(a ::= p.Arguments.start())
			Arguments += :make(a!, f, s, parent);
	}

	# THIS <>(rhs: THIS#&) S1 := Name <> rhs.Name;
}