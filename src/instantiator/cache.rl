INCLUDE "instance.rl"
INCLUDE "stage.rl"

INCLUDE "class.rl"

::rlc::instantiator
{

	Cache
	{

		TemplateArgumentCache: SharedTplArg-std::VecSet;
		TemplateArgumentSetCache: SharedTplArgSet-std::VecSet;
		IDs: InstanceID-std::Dyn-std::VecSet; /// Instance ID pool with fixed addresses.
		Classes: Class-std::[InstanceID #\]DynMap;

		Enums: ast::[resolver::Config]GlobalEnum #\ -std::VecSet;
		GlobalVars: ast::[resolver::Config]GlobalVariable #\ -std::VecSet;
		ExternFns: ast::[resolver::Config]ExternFunction #\ -std::VecSet;
		ExternVars: ast::[resolver::Config]ExternVariable #\ -std::VecSet;

		[Args...:TYPE] declare_default(
			parent: InstanceID #*,
			desc: ast::[resolver::Config]Instantiable #\
		) Instance \ INLINE := declare(parent, desc, <ast::[Config]TemplateArg-std::Vec>());

		[Args...:TYPE] declare(
			parent: InstanceID #*,
			desc: ast::[resolver::Config]Instantiable #\,
			templates: ast::[Config]TemplateArg-std::Vec&&
		) Instance \ INLINE
		{
			TYPE SWITCH(desc)
			{
			ast::[resolver::Config]Class:
				= Classes.ensure(IDs.ensure(:key(parent, desc, &&templates)).ptr()).ptr();
			}
		}

		[Args...:TYPE] generate_default(
			generator: instantiator::Generator &,
			parent: InstanceID #*,
			desc: ast::[resolver::Config]Instantiable #\
		) Instance \ INLINE
		{
			inst ::= declare_default(parent, desc);
			generator.generate(inst);
			= inst;
		}

		[Args...:TYPE] generate(
			generator: instantiator::Generator &,
			parent: InstanceID #*,
			desc: ast::[resolver::Config]Instantiable #\,
			templates: ast::[Config]TemplateArg-std::Vec&&
		) Instance \ INLINE
		{
			inst ::= declare(parent, desc, &&templates);
			generator.generate(inst);
			= inst;
		}
	}
}