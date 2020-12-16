INCLUDE "../parser/concept.rl"

INCLUDE "global.rl"
INCLUDE "member.rl"
INCLUDE "scopeitem.rl"

::rlc::scoper Concept -> VIRTUAL ScopeItem, Scope
{
	(// The member functions required by the concept. /)
	Functions: std::[MemberFunction \]Vector;

	{
		parsed: parser::Concept #\,
		file: src::File #&,
		group: detail::ScopeItemGroup \}:
		Scope(THIS, group->Scope)
	{
		FOR(i ::= 0; i < parsed->Members.size(); i++)
		{
			member ::= Scope::insert(parsed->Members[i], file);
			IF(memfn ::= [MemberFunction \]dynamic_cast(member))
				IF(!memfn->Body)
					Functions.push_back(memfn);
		}
	}
}

::rlc::scoper GlobalConcept -> Global, Concept
{
	# FINAL type() Global::Type := Global::Type::concept;

	{
		parsed: parser::GlobalConcept #\,
		file: src::File #&,
		group: detail::ScopeItemGroup \}:
		ScopeItem(group, parsed, file),
		Concept(parsed, file, group);
}