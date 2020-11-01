INCLUDE "scope.rl"
INCLUDE "templates.rl"

INCLUDE "../parser/scopeitem.rl"
INCLUDE "../parser/member.rl"
INCLUDE "../parser/global.rl"

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

	CONSTRUCTOR(
		group: detail::ScopeItemGroup \,
		item: parser::ScopeItem #\,
		file: src::File#&
	):	Group(group),
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
	) ScopeItem \ := detail::create_scope_item(entry, file, group);
}

::rlc::scoper::detail create_scope_item(
	entry: parser::ScopeItem #\,
	file: src::File#&,
	group: detail::ScopeItemGroup \
) ScopeItem \
{
	cat ::= entry->category();
	IF(cat == parser::ScopeItem::Category::global)
		RETURN Global::create([parser::Global #\]dynamic_cast(entry), file, group);
	IF(cat == parser::ScopeItem::Category::member)
		RETURN Member::create([parser::Member #\]dynamic_cast(entry), file, group);
	IF(cat == parser::ScopeItem::Category::local)
		RETURN ::[LocalVariable]new([parser::LocalVariable #\]dynamic_cast(entry), file, group);
	THROW;
}