INCLUDE "scopeitem.rl"
INCLUDE "global.rl"

INCLUDE 'std/set'

::rlc::ast [Stage:TYPE] Namespace ->
	[Stage]MergeableScopeItem,
	[Stage]Global,
	[Stage]ScopeBase
{
	Entries: [Stage]GlobalScope;
	Tests: [Stage]Test -std::ValVec;

	:childOf{parent: [Stage]ScopeBase \}: Entries := :childOf(parent);

	:transform{
		p: [Stage::Prev+]Namespace #&,
		ctx: Stage::Context+ #&
	} -> (:transform, p, ctx), (), (:childOf, ctx.Parent):
		Entries := :transform_virtual(p.Entries, ctx.in_parent(&p, &THIS))
	{
		_ctx ::= ctx.in_parent(&p, &THIS);
		FOR(t ::= p.Tests.start())
			Tests += :transform(t!, _ctx);
	}


	#? scope_item(name: Stage::Name #&) [Stage]ScopeItem #? * {
		IF(found ::= Entries.scope_item(name))
			= found;
		(/FOR(inc ::= THIS.Included.start())
			IF(found ::= <<THIS#? \>>(inc!)->scope_item(name))
				= found;/)
		= NULL;
	}
	#? local(name: Stage::Name #&, LocalPosition) [Stage]ScopeItem #? * := scope_item(name);

	PRIVATE FINAL merge_impl(rhs: [Stage]MergeableScopeItem &&) VOID
	{
		ns: ?& := <<THIS &>>(rhs);

		FOR[insert](rhs_entry ::= ns.Entries.start())
		{
			IF:!(rhs_entry_si ::= <<[Stage]ScopeItem #*>>(rhs_entry!.Value))
			{
				Entries.insert(&&rhs_entry!.Value);
				CONTINUE;
			}

			FOR[collisions](entry ::= Entries.start())
			{
				IF:!(entry_si ::= <<[Stage]ScopeItem #*>>(entry!.Value))
					CONTINUE;

				IF(entry_si!->Name == rhs_entry_si!->Name)
				{
					merge_entry ::= <<[Stage]MergeableScopeItem *>>(entry!.Value.mut_ptr());
					merge_rhs ::= <<[Stage]MergeableScopeItem *>>(rhs_entry!.Value.mut_ptr());

					IF(!merge_entry || !merge_rhs)
						THROW <MergeError>(entry_si, rhs_entry_si);

					// Merge colliding items.
					merge_entry->merge(&&*merge_rhs);

					CONTINUE [insert];
				}
			}
			// If no collision was found, just insert.
			Entries.insert(&&rhs_entry!.Value);
		}

		ns.Entries := BARE;
	}

	PRIVATE FINAL include_impl(rhs: [Stage]MergeableScopeItem #&) VOID
	{
		ns: ?& := <<THIS #&>>(rhs);

		FOR(rhs_entry ::= ns.Entries.start())
		{
			IF:!(rhs_entry_si ::= <<[Stage]ScopeItem #*>>(rhs_entry))
				CONTINUE;
			IF:!(lhs_entry ::= THIS.Entries.Elements.find(rhs_entry!.Key))
				CONTINUE;

			IF:!(lhs_entry_si ::= <<[Stage]ScopeItem #*>>(lhs_entry))
				CONTINUE;

			IF:!(merge_lhs ::= <<[Stage]MergeableScopeItem *>>(lhs_entry->mut_ptr()))
				THROW <MergeError>(lhs_entry_si, rhs_entry_si);
			IF:!(merge_rhs ::= <<[Stage]MergeableScopeItem #*>>(&rhs_entry!.Value!))
				THROW <MergeError>(lhs_entry_si, rhs_entry_si);

			merge_lhs->include(merge_rhs);
		}
	}
}