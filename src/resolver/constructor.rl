INCLUDE "../scoper/constructor.rl"
INCLUDE "symbol.rl"
INCLUDE "member.rl"

::rlc::resolver Constructor -> Member, ScopeItem
{
	# FINAL type() ScopeItem::Type := :constructor;

	BaseInit
	{
		Base: Symbol;
		Arguments: Expression - std::Dynamic - std::Vector;
		{
			scoped: scoper::Constructor::BaseInit #&,
			ctor: scoper::Constructor #\
		}:	Base(:resolve(ctor->ArgScope, scoped.Base))
		{
			FOR(it ::= scoped.Arguments.start(); it; it++)
				Arguments += :gc(Expression::create(&ctor->ArgScope, (*it)));
		}
	}

	MemberInit
	{
		Member: scoper::MemberVariable #\;
		Arguments: Expression - std::Dynamic - std::Vector;

		STATIC resolve_member(
			scoped: scoper::Constructor::MemberInit #&,
			ctor: scoper::Constructor #\
		) scoper::MemberVariable #\
		{
			member # ::= ctor->parent_scope()->find(scoped.Member);
			IF(!member)
				THROW <Symbol::NotResolved>(
					ctor->parent_scope(),
					scoped.Member,
					scoped.Position,
					"initialiser: unknown member");
			IF(m ::= <<scoper::MemberVariable #\>>(&*member->Items[0]))
				RETURN m;
			THROW <Symbol::NotResolved>(
				ctor->parent_scope(),
				scoped.Member,
				scoped.Position,
				"initialiser: not a member variable");
		}

		{
			scoped: scoper::Constructor::MemberInit #&,
			ctor: scoper::Constructor #\
		}:	Member(resolve_member(scoped, ctor))
		{
			FOR(it ::= scoped.Arguments.start(); it; it++)
				Arguments += :gc(Expression::create(&ctor->ArgScope, (*it)));
		}
	}

	Arguments: LocalVariable - std::Dynamic - std::Vector;
	BaseInits: BaseInit - std::Vector;
	MemberInits: MemberInit - std::Vector;
	Body: BlockStatement - std::Dynamic;
	Inline: BOOL;

	{ctor: scoper::Constructor #\, cache: Cache &}
	->	ScopeItem(ctor, cache),
		Member(ctor)
	:	Inline(ctor->Inline)
	{
		FOR(arg ::= ctor->Arguments.start(); arg; arg++)
			Arguments += :create(*arg, cache);
		FOR(init ::= ctor->BaseInits.start(); init; init++)
			BaseInits += (*init, ctor);
		FOR(init ::= ctor->MemberInits.start(); init; init++)
			MemberInits += (*init, ctor);
		IF(ctor->Body)
			Body := :create(ctor->Body, cache);
	}
}