INCLUDE "../scoper/destructor.rl"
INCLUDE "scopeitem.rl"
INCLUDE "member.rl"

::rlc::resolver Destructor -> Member, ScopeItem
{
	Body: BlockStatement;
	Inline: BOOL;

	{dtor: scoper::Destructor #\, cache: Cache &}
	->	ScopeItem(dtor, cache),
		Member(dtor)
	:	Body(&dtor->Body, cache),
		Inline(dtor->Inline);
}