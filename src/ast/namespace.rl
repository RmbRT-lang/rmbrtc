INCLUDE "scopeitem.rl"
INCLUDE "global.rl"

INCLUDE 'std/set'

::rlc::ast [Stage:TYPE] Namespace -> [Stage]MergeableScopeItem, [Stage]Global
{
	Entries: [Stage]Global - std::DynVec;

	:transform{
		p: [Stage::Prev+]Namespace #&,
		f: Stage::PrevFile+,
		s: Stage &
	} -> (:transform, p, f, s), ():
		Entries := :reserve(##p.Entries)
	{
		FOR(it ::= p.Entries.start())
			Entries += <<<[Stage]Global>>>(it!, f, s);
	}

	PRIVATE FINAL merge_impl(rhs: [Stage]MergeableScopeItem &&) VOID
	{
		ns: ?& := <<[Stage]Namespace &>>(rhs);

		FOR[insert](rhs_entry ::= ns.Entries.start())
		{
			IF:!(rhs_entry_si ::= <<[Stage]ScopeItem *>>(rhs_entry!))
			{
				Entries += &&*rhs_entry;
				CONTINUE;
			}

			FOR[collisions](entry ::= Entries.start())
			{
				IF:!(entry_si ::= <<[Stage]ScopeItem *>>(entry!))
					CONTINUE;

				IF(entry_si!->Name == rhs_entry_si!->Name)
				{
					merge_entry ::= <<[Stage]MergeableScopeItem *>>(entry!);
					merge_rhs ::= <<[Stage]MergeableScopeItem *>>(rhs_entry!);

					IF(!merge_entry || !merge_rhs)
						THROW <MergeError>(entry_si, rhs_entry_si);

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