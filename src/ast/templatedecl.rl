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
			s: Stage &,
			parent: [Stage]ScopeBase \
		}:
			Arguments := :reserve(##p.Arguments)
		{
			FOR(a ::= p.Arguments.start())
				Arguments += :make(a!, f, s, parent);
		}

		# exists() BOOL INLINE := ##Arguments != 0;
	}

	[Stage:TYPE] TemplateArgDecl VIRTUAL
	{
		Name: Stage::Name;
		Variadic: BOOL;

		# ABSTRACT type() TemplateDeclArgType;

		:transform{
			p: [Stage::Prev+]TemplateArgDecl #&,
			f: Stage::PrevFile+,
			s: Stage &
		}:
			Name := s.transform_name(p.Name, f),
			Variadic := p.Variadic;

		<<<
			p: [Stage::Prev+]TemplateArgDecl #&,
			f: Stage::PrevFile+,
			s: Stage &,
			parent: [Stage]ScopeBase \
		>>> THIS-std::Dyn
		{
			TYPE SWITCH(p)
			{
			[Stage::Prev+]TypeTemplateArgDecl:
				= :a.[Stage]TypeTemplateArgDecl(:transform(>>p, f, s));
			[Stage::Prev+]ValueTemplateArgDecl:
				= :a.[Stage]ValueTemplateArgDecl(:transform(>>p, f, s, parent));
			[Stage::Prev+]NumberTemplateArgDecl:
				= :a.[Stage]NumberTemplateArgDecl(:transform(>>p, f, s));
			}
		}
	}

	[Stage:TYPE] TypeTemplateArgDecl -> [Stage]TemplateArgDecl
	{
		# FINAL type() TemplateDeclArgType := :type;

		:transform{
			p: [Stage::Prev+]TypeTemplateArgDecl #&,
			f: Stage::PrevFile+,
			s: Stage &
		} -> (:transform, p, f, s);
	}

	[Stage:TYPE] ValueTemplateArgDecl -> [Stage]TemplateArgDecl
	{
		Type: Stage-ast::Type - std::Dyn;
		# FINAL type() TemplateDeclArgType := :value;

		:transform{
			p: [Stage::Prev+]ValueTemplateArgDecl #&,
			f: Stage::PrevFile+,
			s: Stage &,
			parent: [Stage]ScopeBase \
		} -> (:transform, p, f, s):
			Type := :make(p.Type!, f, s, parent);
	}

	[Stage:TYPE] NumberTemplateArgDecl -> [Stage]TemplateArgDecl
	{
		# FINAL type() TemplateDeclArgType := :number;

		:transform{
			p: [Stage::Prev+]NumberTemplateArgDecl #&,
			f: Stage::PrevFile+,
			s: Stage &
		} -> (:transform, p, f, s);
	}
}