INCLUDE "type.rl"


::rlc::ast
{
	ENUM TemplateDeclArgType { type, number, value }

	[Stage:TYPE] TemplateDecl
	{
		Arguments: Stage-TemplateArgDecl-std::DynVec;

		:transform{
			p: [Stage::Prev+]TemplateDecl #&,
			f: Stage::PrevFile+,
			s: Stage &
		}:
			Arguments := :reserve(##p.Arguments)
		{
			FOR(a ::= p.Arguments.start())
				Arguments += <<<[Stage]TemplateArgDecl>>>(a!, f, s);
		}

		# exists() BOOL INLINE := ##Arguments != 0;
	}

	[Stage:TYPE] TemplateArgDecl VIRTUAL {
		Name: Stage::Name;
		Variadic: BOOL;

		# ABSTRACT type() TemplateDeclArgType;

		:transform{
			p: [Stage::Prev+]TemplateDecl #&,
			f: Stage::PrevFile+,
			s: Stage &
		}:
			Name := s.transform_name(p.Name, f),
			Variadic := p.Variadic;

		<<<
			p: [Stage::Prev+]TemplateArgDecl #&,
			f: Stage::PrevFile+,
			s: Stage &
		>>> THIS-std::Dyn
		{
			TYPE SWITCH(p)
			{
			[Stage::Prev+]TypeTemplateArgDecl:
				= :dup(<[Stage]TypeTemplateArgDecl>(:transform(
					<<[Stage::Prev+]TypeTemplateArgDecl #&>>(p), f, s)));
			[Stage::Prev+]ValueTemplateArgDecl:
				= :dup(<[Stage]ValueTemplateArgDecl>(:transform(
					<<[Stage::Prev+]ValueTemplateArgDecl #&>>(p), f, s)));
			[Stage::Prev+]NumberTemplateArgDecl:
				= :dup(<[Stage]NumberTemplateArgDecl>(:transform(
					<<[Stage::Prev+]NumberTemplateArgDecl #&>>(p), f, s)));
			}
		}
	}

	[Stage:TYPE] TypeTemplateArgDecl -> [Stage]TemplateArgDecl
	{
		# FINAL type() TemplateDeclArgType := :type;

		:transform{
			p: [Stage::Prev+]TypeTemplateDecl #&,
			f: Stage::PrevFile+,
			s: Stage &
		} -> (:transform, p, f, s);
	}

	[Stage:TYPE] ValueTemplateArgDecl -> [Stage]TemplateArgDecl
	{
		Type: Stage-ast::Type - std::Dyn;
		# FINAL type() TemplateDeclArgType := :value;

		:transform{
			p: [Stage::Prev+]ValueTemplateDecl #&,
			f: Stage::PrevFile+,
			s: Stage &
		} -> (:transform, p, f, s):
			Type := <<<ast::[Stage]Type>>>(p.Type!, f, s);
	}

	[Stage:TYPE] NumberTemplateArgDecl -> [Stage]TemplateArgDecl
	{
		# FINAL type() TemplateDeclArgType := :number;

		:transform{
			p: [Stage::Prev+]NumberTemplateDecl #&,
			f: Stage::PrevFile+,
			s: Stage &
		} -> (:transform, p, f, s);
	}
}