INCLUDE "type.rl"
INCLUDE "scopeitem.rl"
INCLUDE "global.rl"
INCLUDE "member.rl"

::rlc::ast
{
	[Stage:TYPE] Typedef VIRTUAL -> [Stage]ScopeItem, [Stage]Templateable
	{
		Type: [Stage]Type-std::Dyn;
	}

	[Stage:TYPE] GlobalTypedef -> [Stage]Global, [Stage]Typedef { }
	[Stage:TYPE] MemberTypedef -> [Stage]Member, [Stage]Typedef { }
}