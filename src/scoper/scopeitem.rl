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
	) {ScopeItem \, bool} := detail::create_scope_item(entry, file, group);
}

::rlc::scoper IncompatibleOverloadError -> std::Error
{
	FileName: std::Utf8;
	Line: uint;
	Column: uint;
	ScopeName: std::Utf8;
	Name: String;

	Reason: char #\;

	{
		existing: ScopeItem #\,
		addition: parser::ScopeItem #\,
		file: src::File #&,
		reason: char #\
	}:	FileName(file.Name),
		ScopeName(existing->parent_scope()->name()),
		Name(file.content(addition->name())),
		Reason(reason)
	{
		file.position(addition->name().Start, &Line, &Column);
	}

	# FINAL print(o: std::io::OStream &) VOID
	{
		o.write(FileName.content());
		o.write(':');
		std::io::format::dec(o, Line);
		o.write(':');
		std::io::format::dec(o, Column);
		o.write(": invalid overload of ");
		o.write(ScopeName.content());
		o.write("::");
		IF(Name.Size)
			o.write(Name);
		ELSE
			o.write("<unnamed>");
		o.write(": ");
		o.write(Reason);
		o.write('.');
	}
}


::rlc::scoper::detail create_scope_item(
	entry: parser::ScopeItem #\,
	file: src::File#&,
	group: detail::ScopeItemGroup \
) {ScopeItem \, bool}
{
	cat ::= entry->category();

	IF(group->Items)
	{
		cmp ::= &*group->Items.front();
		IF(cmp->category() != cat)
			THROW <IncompatibleOverloadError>(cmp, entry, file, "kind mismatch");
		IF(!entry->overloadable())
			THROW <IncompatibleOverloadError>(cmp, entry, file, "not overloadable");

		same: bool;
		SWITCH(cat)
		{
		CASE :global:
			{
				type ::= [parser::Global #\]dynamic_cast(entry)->type();
				type2 ::= [scoper::Global #\]dynamic_cast(cmp)->type();
				same := type == type2;

				IF(same && type == :namespace)
					RETURN (cmp, FALSE);
			}
		CASE :member:
			{
				type ::= [parser::Member #\]dynamic_cast(entry)->type();
				type2 ::= [scoper::Member #\]dynamic_cast(cmp)->type();
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
		i := Global::create([parser::Global #\]dynamic_cast(entry), file, group);
	CASE :member:
		i := Member::create([parser::Member #\]dynamic_cast(entry), file, group);
	CASE :local:
		i := ::[LocalVariable]new([parser::LocalVariable #\]dynamic_cast(entry), file, group);
	DEFAULT:
		THROW <std::err::Unimplemented>(cat.NAME());
	}

	RETURN (i, TRUE);
}