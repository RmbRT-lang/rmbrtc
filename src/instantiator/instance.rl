

::rlc::instantiator
{
	GenerationError -> std::Error
	{
		PRIVATE ErrData {
			At: InstanceID #\;
			PrevErr: THIS-std::Shared;
			Message: CHAR #*;
		}

		Data: ErrData - std::Shared;

		:chain{at: InstanceID #\, err: THIS#&}:
			Data := :a(at, err.Data, NULL);

		{at: InstanceID #\, msg: CHAR#\}:
			Data := :a(at, NULL, msg);

		{...};

		# FINAL stream(o: std::io::OStream &) VOID
		{
			IF(!Data)
				RETURN;

			desc ::= Data!.At->Descriptor;
			std::io::write(o,
				:stream(<<ast::CodeObject #\>>(desc)->Position), ": error during instantiation: ");
			IF(Data!.PrevErr)
				std::io::write(o, "\n", :stream(<GenerationError>(Data!.PrevErr)));
			ELSE
				std::io::write(o, Data!.Message);
		}
	}

	Instance VIRTUAL { }

	InstanceID
	{
		Parent: InstanceID #*; /// The parent instance, we inherit templates from it.
		Descriptor: ast::[resolver::Config]Instantiable #\;
		Templates: SharedTplArgSet; /// Deduplicate template arguments.

		:default_key{
			parent: InstanceID #*,
			descriptor: ast::[resolver::Config]Instantiable #\
		}:
			Parent := parent,
			Descriptor := descriptor;

		:key{
			parent: InstanceID #*,
			descriptor: ast::[resolver::Config]Instantiable #\,
			templates: ast::[Config]TemplateArg-std::Vec&&
		}:
			Parent := parent,
			Descriptor := descriptor,
			Templates := :a(&&templates);

		# |THIS ? INLINE := (Parent, Descriptor, Templates);
		# THIS <> (rhs: THIS #&) S1 := |THIS <> |rhs;

		# desc_pos() src::Position #& := <<ast::CodeObject#\>>(Descriptor)->Position;
	}
}