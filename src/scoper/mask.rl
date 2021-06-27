INCLUDE "../parser/mask.rl"

INCLUDE "global.rl"
INCLUDE "member.rl"
INCLUDE "scopeitem.rl"

::rlc::scoper Mask -> VIRTUAL ScopeItem, Scope
{
	(// The member functions required by the mask. /)
	Functions: std::[MemberFunction \]Vector;

	{
		parsed: parser::Mask #\,
		file: src::File #&,
		group: detail::ScopeItemGroup \}:
		Scope(&THIS, group->Scope)
	{
		FOR(i ::= 0; i < ##parsed->Members; i++)
		{
			member ::= Scope::insert(parsed->Members[i], file);
			IF(memfn ::= <<MemberFunction \>>(member))
				IF(!memfn->Body)
					Functions += memfn;
		}
	}
}

::rlc::scoper GlobalMask -> Global, Mask
{
	# FINAL type() Global::Type := :mask;

	{
		parsed: parser::GlobalMask #\,
		file: src::File #&,
		group: detail::ScopeItemGroup \
	}:	ScopeItem(group, parsed, file),
		Mask(parsed, file, group);
}