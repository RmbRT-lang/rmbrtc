INCLUDE "../resolver/type.rl"

INCLUDE 'std/hash'
INCLUDE 'std/hashset'

::rlc::instantiator Type VIRTUAL -> std::CustomHashable
{
	TYPE ReferenceType := resolver::Type::ReferenceType;
	TYPE Indirection := resolver::Type::Indirection;
	TYPE Qualifier := scoper::Type::Qualifier;


	# VIRTUAL plain() BOOL := FALSE;

	<<<
		type: resolver::Type #\,
		scope: Scope #&
	>>> Type #\ := detail::create_type(type, scope);

	<<<
		base: Type #\,
		decorators: resolver::Type #\,
		scope: Scope #&
	>>> Type #\
	{
		IF(decorators->plain())
			RETURN base;
		
		type ::= base;
		FOR(it ::= decorators->Modifiers!.start(:ok); it; ++it)
		{
			SWITCH(t ::= it!.Indirection)
			{
			:plain: {;}
			:pointer, :nonnull:
				type := scope.type(<PointerType>(type, t == :pointer));
			:expectDynamic, :maybeDynamic:
				type := scope.type(<DynamicType>(type, t == :expectDynamic));
			:future:
				type := scope.type(<FutureType>(type));
			}

			IF(it!.Qualifier)
				type := scope.type(<QualifiedType>(type, it!.Qualifier));

			IF(it!.IsArray)
				IF(it!.ArraySize)
					type := scope.type(<ArrayType>(type, it!.ArraySize!, scope));
				ELSE
					type := scope.type(<ArrayType>(type, :unbounded));
		}

		SWITCH(decorators->Reference)
		{
		:none: {;}
		:reference, :tempReference:
			type := scope.type(<instantiator::ReferenceType>(type, decorators->Reference));
		}

		RETURN type;
	}

	STATIC resolve_expression(
		type: resolver::TypeOfExpression #\,
		scope: Scope #&
	) Type #\;
}

::rlc::instantiator TypeCache
{
	[T: TYPE]
	THIS[t: T!&&] Type #\
	{
		h ::= std::hash(t);
		IF(ret ::= Cache.find(h))
			RETURN *ret;

		ret: Type #\ := std::dup(&&t);
		Cache.insert(h, :gc(ret));
		RETURN ret;
	}
PRIVATE:
	Cache: Type-std::DynHashSet;
}