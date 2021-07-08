INCLUDE "../scoper/destructor.rl"
INCLUDE "scopeitem.rl"
INCLUDE "member.rl"

::rlc::resolver Destructor -> Member, ScopeItem
{
	# FINAL type() ScopeItem::Type := :destructor;

	Body: BlockStatement;
	Inline: BOOL;

	{dtor: scoper::Destructor #\}:
		ScopeItem(dtor),
		Member(dtor),
		Body(&dtor->Body),
		Inline(dtor->Inline);
}