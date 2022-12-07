INCLUDE "scopeitem.rl"
INCLUDE "global.rl"

INCLUDE 'std/set'

::rlc::ast [Stage:TYPE] Namespace -> [Stage]MergeableScopeItem, [Stage]Global
{
	Entries: [Stage]GlobalScope;

	:childOf{parent: [Stage]ScopeBase \}: Entries := :childOf(parent);

	:transform{
		p: [Stage::Prev+]Namespace #&,
		f: Stage::PrevFile+,
		s: Stage &,
		parent: [Stage]ScopeBase \
	} -> (:transform, p, f, s, parent), ():
		Entries := :transform(p.Entries, f, s, parent);

	PRIVATE FINAL merge_impl(rhs: [Stage]MergeableScopeItem &&) VOID
	{
		ns: ?& := <<THIS &>>(rhs);

		FOR[insert](rhs_entry ::= ns.Entries.start())
		{
			IF:!(rhs_entry_si ::= <<[Stage]ScopeItem *>>(rhs_entry!.Value))
			{
				Entries += &&rhs_entry!.Value;
				CONTINUE;
			}

			FOR[collisions](entry ::= Entries.start())
			{
				IF:!(entry_si ::= <<[Stage]ScopeItem *>>(entry!.Value))
					CONTINUE;

				IF(entry_si!->Name == rhs_entry_si!->Name)
				{
					merge_entry ::= <<[Stage]MergeableScopeItem *>>(&entry!.Value!);
					merge_rhs ::= <<[Stage]MergeableScopeItem *>>(&rhs_entry!.Value!);

					IF(!merge_entry || !merge_rhs)
						THROW <MergeError>(entry_si, rhs_entry_si);

					// Merge colliding items.
					merge_entry->merge(&&*merge_rhs);

					CONTINUE [insert];
				}
			}
			// If no collision was found, just insert.
			Entries += &&rhs_entry!.Value;
		}

		ns.Entries := BARE;
	}
}