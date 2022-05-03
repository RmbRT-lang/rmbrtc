INCLUDE "scopeitem.rl"
INCLUDE "global.rl"

INCLUDE 'std/set'

::rlc::ast [Stage:TYPE] Namespace -> [Stage]MergeableScopeItem, [Stage]Global
{
	Entries: [Stage]Global - std::DynVec;

	PRIVATE FINAL merge_impl(rhs: [Stage]MergeableScopeItem &&) VOID
	{
		ns ::= <<[Stage]Namespace &>>(rhs);

		FOR[insert](rhs_entry ::= ns.Entries.start(); rhs_entry; ++rhs_entry)
		{
			FOR[collisions](entry ::= Entries.start(); entry; ++entry)
			{
				IF(entry!->Name == rhs_entry!->Name)
				{
					merge_entry ::= <<[Stage]MergeableScopeItem *>>(entry!);
					merge_rhs ::= <<[Stage]MergeableScopeItem *>>(rhs_entry!);

					IF(!merge_entry || !merge_rhs)
						THROW <[Stage]MergeError>(entry, rhs_entry);

					// Merge colliding items.
					merge_entry->merge(&&*merge_rhs);

					CONTINUE [insert];
				}
			}
			// If no collision was found, just insert.
			Entries += &&*rhs_entry;
		}

		ns.Entries.~;
		ns.Entries.{};
	}
}