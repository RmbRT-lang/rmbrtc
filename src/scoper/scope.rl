INCLUDE "types.rl"
INCLUDE "scopeitem.rl"

INCLUDE "../parser/scopeitem.rl"

INCLUDE 'std/set'
INCLUDE 'std/tags'
INCLUDE 'std/io/stream'

(// A scope contains a collection of scope items. /)
::rlc::scoper Scope
{
	std::NoCopy;
	std::NoMove;

	Owner: ScopeOwner *;
	Parent: Scope *;
	Items: detail::ScopeItemGroupSet;

	CONSTRUCTOR(
		owner: ScopeOwner *,
		parent: Scope *
	):	Owner(owner),
		Parent(parent);

	# root() Scope #\
	{
		scope ::= THIS;
		WHILE(scope->Parent)
			scope := scope->Parent;
		RETURN scope;
	}

	# find(name: String #&) detail::ScopeItemGroup #*
	{
		it ::= Items.find(name);
		RETURN it ? it->Ptr : NULL;
	}

	find(name: String #&) detail::ScopeItemGroup *
	{
		it ::= Items.find(name);
		RETURN it ? it->Ptr : NULL;
	}

	insert(
		entry: parser::ScopeItem #\,
		file: src::File #&) ScopeItem \
	{
		name ::= file.content(entry->name());
		IF(Owner
		&& Owner->owner_type() == OwnerType::scopeItem
		&& <ScopeItem \>(Owner)->Templates.find(name))
			THROW "shadowing template parameter";

		loc: detail::ScopeItemGroupSet::Location;
		it ::= Items.find(name, &loc);

		group ::= it
			? it->Ptr
			: Items.insert_at(loc, ::[detail::ScopeItemGroup]new(name, THIS)).Ptr;

		ret ::= ScopeItem::create(entry, file, group);
		group->Items.emplace_back(ret);
		RETURN ret;
	}

	# print_name(
		o: std::io::OStream &) VOID
	{
		IF(Parent)
			Parent->print_name(o);
		IF(!Owner
		|| Owner->owner_type() != OwnerType::scopeItem)
			RETURN;

		IF(Parent && Parent->Parent)
			o.write("::");

		n ::= <ScopeItem #\>(Owner)->name();
		o.write(n.Data, n.Size);
	}
}

::rlc::scoper ::detail
{
	(// A collection of scope items with the same name. /)
	ScopeItemGroup
	{
		std::NoCopy;
		std::NoMove;

		Scope: scoper::Scope \;
		Name: String;
		Items: std::[std::[ScopeItem]Dynamic]Vector;

		CONSTRUCTOR(name: String#&, scope: scoper::Scope \):
			Scope(scope),
			Name(name);

		STATIC cmp(
			lhs: String #&,
			rhs: ScopeItemGroup # \) INLINE int :=
			std::str::cmp(lhs, rhs->Name);
	}

	TYPE ScopeItemGroupSet
		:= std::[std::[detail::ScopeItemGroup]Dynamic, detail::ScopeItemGroup]VectorSet;
}