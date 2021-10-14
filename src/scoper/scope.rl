INCLUDE "types.rl"
INCLUDE "scopeitem.rl"

INCLUDE "../parser/scopeitem.rl"

INCLUDE 'std/set'
INCLUDE 'std/tags'
INCLUDE 'std/io/stream'
INCLUDE 'std/streambuffer'

(// A scope contains a collection of scope items. /)
::rlc::scoper Scope
{
	std::NoCopy;
	std::NoMove;

	Owner: ScopeOwner *;
	Parent: Scope *;
	Items: detail::ScopeItemGroupSet;

	{
		owner: ScopeOwner *,
		parent: Scope *
	}:	Owner(owner),
		Parent(parent);

	# root() Scope #\
	{
		scope ::= &THIS;
		WHILE(scope->Parent)
			scope := scope->Parent;
		RETURN scope;
	}

	# is_root() BOOL := !Parent;

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
		IF(<<ScopeItem #*>>(Owner)
		&& <ScopeItem \>(Owner)->Templates.find(name))
			THROW "shadowing template parameter";

		loc: detail::ScopeItemGroupSet::Location;
		it ::= Items.find(name, &loc);

		group ::= it
			? (*it)!
			: Items.insert_at(loc, :gc(std::[detail::ScopeItemGroup]new(name, &THIS)))!;

		ret ::= <<<ScopeItem>>>(entry, file, group);
		IF(ret.(1))
			group->Items += :gc(ret.(0));
		RETURN ret.(0);
	}

	# print_name(
		o: std::io::OStream &) VOID
	{
		IF(Parent)
			Parent->print_name(o);
		IF(!<<ScopeItem #*>>(Owner))
			RETURN;

		IF(Parent && Parent->Parent)
			o.write("::");

		n ::= <ScopeItem #\>(Owner)->name();
		o.write(n.Data, n.Size);
	}

	# name() std::Utf8
	{
		buf: std::StreamBuffer;
		print_name(buf);
		RETURN <std::Utf8 &&>(buf);
	}
}

::rlc::scoper::detail
{
	(// A collection of scope items with the same name. /)
	ScopeItemGroup
	{
		std::NoCopy;
		std::NoMove;

		Scope: scoper::Scope \;
		Name: String;
		Items: ScopeItem - std::DynVector;

		{name: String#&, scope: scoper::Scope \}:
			Scope(scope),
			Name(name);

		STATIC cmp(
			lhs: String #&,
			rhs: ScopeItemGroup # \) INLINE INT :=
			std::str::cmp(lhs, rhs->Name);
	}

	TYPE ScopeItemGroupSet
		:= std::[std::[ScopeItemGroup]Dynamic, ScopeItemGroup]VectorSet;
}