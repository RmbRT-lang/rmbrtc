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

	:transform{
		p: [Stage::Prev+]SymbolConstant #&,
		f: Stage::PrevFile+,
		s: Stage &
	}:
		NameType := p.NameType,
		Identifier := s.transform_name(p.Identifier, f);

	NameType: Type;
	Identifier: Stage::Name;

	# has_name() BOOL := NameType == :identifier;
	# is_special() BOOL := NameType != :identifier;


	Cmp {
		STATIC cmp(lhs: THIS#&, rhs: THIS#&) ?
		{
			IF(lhs.NameType == :identifier && rhs.NameType == :identifier)
			{
				= Stage::Name::Cmp::cmp(lhs.Identifier, rhs.Identifier);
			}
			= <SM>(lhs.NameType) - <SM>(rhs.NameType);
		}
	}

}