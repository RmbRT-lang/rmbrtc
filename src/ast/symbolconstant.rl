::rlc::ast [Stage:TYPE] SymbolConstant
{
	ENUM Type {
		identifier,
		less,
		greater,
		lessGreater,
		exclamationMark,
		questionMark,
		lessMinus
	}

	:identifier{i: src::String}: NameType(:identifier), Identifier(i);
	:special{t: Type}: NameType(t) { ASSERT(is_special()); }
	
	:typed_identifier{
		i: src::String,
		type: ast::[Stage]Type-std::Dyn
	}:
		NameType(:identifier),
		Identifier(i),
		TypeAnnotation := &&type;

	:typed_special{
		t: Type,
		type: ast::[Stage]Type-std::Dyn
	}:
		NameType(t),
		TypeAnnotation := &&type
	{ ASSERT(is_special()); }

	:transform{
		p: [Stage::Prev+]SymbolConstant #&,
		ctx: Stage::Context+ #&
	}:
		NameType := p.NameType,
		Identifier := ctx.transform_name(p.Identifier),
		TypeAnnotation := :make_if(p.TypeAnnotation, p.TypeAnnotation.ok(), ctx);

	NameType: Type;
	Identifier: Stage::Name;
	TypeAnnotation: ast::[Stage]Type - std::DynOpt;

	# has_name() BOOL := NameType == :identifier;
	# is_special() BOOL := NameType != :identifier;

	# THIS <>(rhs: THIS#&) S1
	{
		IF(NameType == :identifier && rhs.NameType == :identifier)
			= Identifier <> rhs.Identifier;
		= <S1>(NameType) <> <S1>(rhs.NameType);
	}
}