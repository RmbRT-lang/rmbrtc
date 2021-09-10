INCLUDE "../parser/mask.rl"

INCLUDE "global.rl"
INCLUDE "member.rl"
INCLUDE "scopeitem.rl"

::rlc::scoper Mask VIRTUAL -> ScopeItem, Scope
{
	(// The member functions required by the mask. /)
	Functions: std::[MemberFunction \]Vector;
	Fields: std::[MemberVariable \]Vector;

	(//
	A view is a mask that does not extend an object with fields of its own.
	/)
	# is_view() INLINE BOOL := !Fields;

	{
		parsed: parser::Mask #\,
		file: src::File #&,
		group: detail::ScopeItemGroup \
	}->	ScopeItem(group, parsed, file),
		Scope(&THIS, group->Scope)
	{
		FOR(i ::= 0; i < ##parsed->Members; i++)
		{
			member ::= Scope::insert(<<parser::ScopeItem #\>>(parsed->Members[i]), file);
			IF(memfn ::= <<MemberFunction *>>(member))
			{
				IF(!memfn->Body)
					Functions += memfn;
			} ELSE IF(field ::= <<MemberVariable *>>(member))
				Fields += field;
		}
	}
}

::rlc::scoper GlobalMask -> Global, Mask
{
	{
		parsed: parser::GlobalMask #\,
		file: src::File #&,
		group: detail::ScopeItemGroup \
	}->	Mask(parsed, file, group);
}