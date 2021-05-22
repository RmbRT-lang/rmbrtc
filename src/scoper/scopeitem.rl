INCLUDE "scope.rl"
INCLUDE "templates.rl"

INCLUDE "../parser/scopeitem.rl"
INCLUDE "../parser/member.rl"
INCLUDE "../parser/global.rl"

INCLUDE 'std/error'
INCLUDE 'std/io/format'

::rlc::scoper
{
	(// Identifies the kind of object that is owning a scope. /)
	ENUM OwnerType
	{
		scopeItem,
		statement
	}

	(// An object that owns a scope. /)
	ScopeOwner
	{
		# ABSTRACT owner_type() OwnerType;
	}
}

::rlc::scoper ScopeItem VIRTUAL -> ScopeOwner
{
	# FINAL owner_type() OwnerType := OwnerType::scopeItem;

	Group: detail::ScopeItemGroup \;
	Templates: TemplateDecls;

	TYPE Category := parser::ScopeItem::Category;
	# ABSTRACT category() ScopeItem::Category;

	{
		group: detail::ScopeItemGroup \,
		item: parser::ScopeItem #\,
		file: src::File#&
	}:	Group(group),
		Templates(item->Templates, file);

	(// The scope this item is contained in. /)
	# parent_scope() INLINE Scope \ := Group->Scope;
	(// The object owning the scope containing this item, if any. /)
	# parent() INLINE ScopeOwner * := parent_scope()->Owner;

	# name() INLINE String#& := Group->Name;

	STATIC create(
		entry: parser::ScopeItem #\,
		file: src::File#&,
		group: detail::ScopeItemGroup \
	) {ScopeItem \, BOOL} := detail::create_scope_item(entry, file, group);
}

::rlc::scoper IncompatibleOverloadError -> std::Error
{
	FileName: std::Utf8;
	Line: UINT;
	Column: UINT;
	ScopeName: std::Utf8;
	Name: String;

	Reason: CHAR #\;

	{
		existing: ScopeItem #\,
		addition: parser::ScopeItem #\,
		file: src::File #&,
		reason: CHAR #\
	}:	FileName(file.Name),
		ScopeName(existing->parent_scope()->name()),
		Name(file.content(addition->name())),
		Reason(reason)
	{
		file.position(addition->name().Start, &Line, &Column);
	}

	# FINAL print(o: std::io::OStream &) VOID
	{
		o.write_all(FileName.content(), ':');
		std::io::format::dec(o, Line);
		o.write(':');
		std::io::format::dec(o, Column);
		o.write_all(": invalid overload of ", ScopeName.content(), "::");
		IF(Name.Size)
			o.write(Name);
		ELSE
			o.write("<unnamed>");
		o.write_all(": ", Reason, '.');
	}
}


::rlc::scoper::detail create_scope_item(
	entry: parser::ScopeItem #\,
	file: src::File#&,
	group: detail::ScopeItemGroup \
) {ScopeItem \, BOOL}
{
	cat ::= entry->category();

	IF(group->Items)
	{
		cmp # ::= &*group->Items.front();
		IF(cmp->category() != cat)
			THROW <IncompatibleOverloadError>(cmp, entry, file, "kind mismatch");
		IF(!entry->overloadable())
			THROW <IncompatibleOverloadError>(cmp, entry, file, "not overloadable");

		same: BOOL;
		SWITCH(cat)
		{
		CASE :global:
			{
				type ::= <<parser::Global #\>>(entry)->type();
				type2 ::= <<scoper::Global #\>>(cmp)->type();
				same := type == type2;

				IF(same && type == :namespace)
				{
					ns ::= <<parser::Namespace #\>>(entry);
					cmpns ::= <<scoper::Namespace \>>(cmp);
					FOR(it ::= ns->Entries.start(); it; it++)
						cmpns->insert(*it, file);

					RETURN (cmp, FALSE);
				}
			}
		CASE :member:
			{
				type ::= <<parser::Member #\>>(entry)->type();
				type2 ::= <<scoper::Member #\>>(cmp)->type();
				same := type == type2;
			}
		CASE :local:
			same := TRUE;
		DEFAULT:
			THROW <std::err::Unimplemented>(cat.NAME());
		}

		IF(!same)
			THROW <IncompatibleOverloadError>(cmp, entry, file, "kind mismatch");
	}
	i: ScopeItem *;
	SWITCH(cat)
	{
	CASE :global:
		i := Global::create(<<parser::Global #\>>(entry), file, group);
	CASE :member:
		i := Member::create(<<parser::Member #\>>(entry), file, group);
	CASE :local:
		i := ::[LocalVariable]new(<<parser::LocalVariable #\>>(entry), file, group);
	DEFAULT:
		THROW <std::err::Unimplemented>(cat.NAME());
	}

	RETURN (i, TRUE);
}