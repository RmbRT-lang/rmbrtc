INCLUDE "scope.rl"
INCLUDE "templates.rl"

INCLUDE "../parser/scopeitem.rl"
INCLUDE "../parser/member.rl"
INCLUDE "../parser/global.rl"

INCLUDE 'std/error'
INCLUDE 'std/io/format'

(// An object that owns a scope. /)
::rlc::scoper ScopeOwner VIRTUAL { }

::rlc::scoper ScopeItem VIRTUAL -> ScopeOwner
{
	Group: detail::ScopeItemGroup \;
	Templates: TemplateDecls;

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

	<<<
		entry: parser::ScopeItem #\,
		file: src::File#&,
		group: detail::ScopeItemGroup \
	>>> {ScopeItem \, BOOL}
		:= detail::create_scope_item(entry, file, group);
}

::rlc::scoper IncompatibleOverloadError -> std::Error
{
	FileName: std::Utf8;
	Line: UINT;
	Column: UINT;
	ScopeName: std::Utf8;
	Name: String;
	Type: CHAR #\;
	NewType: CHAR #*;

	Reason: CHAR #\;

	{
		existing: ScopeItem #\,
		addition: parser::ScopeItem #\,
		file: src::File #&,
		reason: CHAR #\,
		type: CHAR #\,
		newType: CHAR #*
	}:	FileName(file.Name),
		ScopeName(existing->parent_scope()->name()),
		Name(file.content(addition->name())),
		Reason(reason),
		Type(type),
		NewType(newType)
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
		o.write_all(": ", Reason, " (", Type);
		IF(NewType)
			o.write_all(", ", NewType);
		o.write(").");
	}
}

::rlc::scoper::detail origin_type(
	s: ScopeItem #\) CHAR #\
{
	TYPE SWITCH(s)
	{
	DEFAULT: THROW <std::err::Unimplemented>(TYPE(s));
	CASE Namespace: RETURN TYPE TYPE(parser::Namespace);
	CASE Variable: RETURN TYPE TYPE(parser::Variable);
	CASE Class: RETURN TYPE TYPE(parser::Class);
	CASE Enum: RETURN TYPE TYPE(parser::Enum);
	CASE Enum::Constant: RETURN TYPE TYPE(parser::Enum::Constant);
	CASE ExternSymbol: RETURN TYPE TYPE(parser::ExternSymbol);
	CASE Rawtype: RETURN TYPE TYPE(parser::Rawtype);
	CASE Union: RETURN TYPE TYPE(parser::Union);
	CASE Function: RETURN TYPE TYPE(parser::Function);
	CASE Constructor: RETURN TYPE TYPE(parser::Constructor);
	CASE Destructor: RETURN TYPE TYPE(parser::Destructor);
	}
}

::rlc::scoper::detail create_scope_item(
	entry: parser::ScopeItem #\,
	file: src::File#&,
	group: detail::ScopeItemGroup \
) {ScopeItem \, BOOL}
{
	type ::= TYPE(entry);

	IF(group->Items)
	{
		cmp # ::= &*group->Items.front();

		IF(origin_type(cmp) != type)
			THROW <IncompatibleOverloadError>(cmp, entry, file, "kind mismatch", type, TYPE(cmp));
		IF(!entry->overloadable())
			THROW <IncompatibleOverloadError>(cmp, entry, file, "not overloadable", type, NULL);

		IF(type == TYPE TYPE(parser::Namespace))
		{
			ns ::= <<parser::Namespace #\>>(entry);
			cmpns ::= <<scoper::Namespace \>>(cmp);
			FOR(it ::= ns->Entries.start(); it; it++)
				cmpns->insert(*it, file);

			RETURN (cmp, FALSE);
		}
	}

	IF(p ::= <<parser::Global #*>>(entry))
		RETURN (<<ScopeItem \>>(<<<Global>>>(p, file, group)), TRUE);
	ELSE IF(p ::= <<parser::Member #*>>(entry))
		RETURN (<<ScopeItem \>>(<<<Member>>>(p, file, group)), TRUE);
	ELSE IF(p ::= <<parser::LocalVariable #*>>(entry))
		RETURN (std::[LocalVariable]new(p, file, group), TRUE);
	ELSE
		THROW <std::err::Unimplemented>(type);
}