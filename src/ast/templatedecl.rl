INCLUDE "type.rl"
INCLUDE "scope.rl"

::rlc::ast
{
	ENUM TemplateDeclArgType { type, number, value }

	[Stage:TYPE] TemplateDecl
	{
		Arguments: Stage-TemplateArgDecl-std::DynVec;

		:transform{
			p: [Stage::Prev+]TemplateDecl #&,
			ctx: Stage::Context+ #&
		}:
			Arguments := :reserve(##p.Arguments)
		{
			FOR(a ::= p.Arguments.start())
				Arguments += :make(a!, ctx);
		}

		# exists() BOOL INLINE := ##Arguments != 0;
	}

	[Stage:TYPE] TemplateArgDecl VIRTUAL -> [Stage]ScopeItem
	{
		Variadic: BOOL;

		# ABSTRACT type() TemplateDeclArgType;

		:transform{
			p: [Stage::Prev+]TemplateArgDecl #&,
			ctx: Stage::Context+ #&
		} -> (:transform, p, ctx):
			Variadic := p.Variadic;

		<<<
			p: [Stage::Prev+]TemplateArgDecl #&,
			ctx: Stage::Context+ #&
		>>> THIS-std::Dyn
		{
			TYPE SWITCH(p)
			{
			[Stage::Prev+]TypeTemplateArgDecl:
				= :a.[Stage]TypeTemplateArgDecl(:transform(>>p, ctx));
			[Stage::Prev+]ValueTemplateArgDecl:
				= :a.[Stage]ValueTemplateArgDecl(:transform(>>p, ctx));
			[Stage::Prev+]NumberTemplateArgDecl:
				= :a.[Stage]NumberTemplateArgDecl(:transform(>>p, ctx));
			}
		}
	}

	[Stage:TYPE] TypeTemplateArgDecl -> [Stage]TemplateArgDecl, PotentialScope
	{
		# FINAL type() TemplateDeclArgType := :type;

		:transform{
			p: [Stage::Prev+]TypeTemplateArgDecl #&,
			ctx: Stage::Context+ #&
		} -> (:transform, p, ctx), ();
	}

	[Stage:TYPE] ValueTemplateArgDecl -> [Stage]TemplateArgDecl
	{
		Type: Stage-ast::Type - std::Dyn;
		# FINAL type() TemplateDeclArgType := :value;

		:transform{
			p: [Stage::Prev+]ValueTemplateArgDecl #&,
			ctx: Stage::Context+ #&
		} -> (:transform, p, ctx):
			Type := :make(p.Type!, ctx);
	}

	[Stage:TYPE] NumberTemplateArgDecl -> [Stage]TemplateArgDecl
	{
		# FINAL type() TemplateDeclArgType := :number;

		:transform{
			p: [Stage::Prev+]NumberTemplateArgDecl #&,
			ctx: Stage::Context+ #&
		} -> (:transform, p, ctx);
	}
}