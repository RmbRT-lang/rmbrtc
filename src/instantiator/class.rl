INCLUDE "stage.rl"
INCLUDE "../resolver/stage.rl"
INCLUDE "../ast/class.rl"
INCLUDE "type.rl"


::rlc::instantiator Class -> Instance, Type
{
	/// named and anonymous member variable types.
	PRIVATE Fields: ast::[Config]Type-std::Dyn-Resolveable-std::Vec-Resolveable;

	resolve_fields(
		id: InstanceID #\,
		ctx: Context #\
	) ast::[Config]Type-std::Dyn-Resolveable-std::Vec-Resolveable #&
	{
		IF(Fields.determined())
			RETURN Fields;

		desc ::=  <<ast::[resolver::Config]Class #\>>(id->Descriptor);
		fields: ?#& := desc->Members.Fields;

		Fields.resolve(##fields.NamedVars + ##fields.AnonVars);

		_ctx: ClassContext := :childOf(ctx, id);

		FOR(field ::= fields.NamedVars.start())
		{
			fieldV: ?#& := <<ast::[resolver::Config]MemberVariable#&>>(field!.Value!);
			res: ?& := Fields![fieldV.Index];

			res.start_resolving(id->desc_pos());
			t: Type-std::DynOpt;
			TRY t := type::resolve(fieldV.Type!, _ctx);
			CATCH(err: std::Error-std::Shared) res.fail_share(&&err);
			res.resolve(:!(&&t));
		}

		FOR(field ::= fields.AnonVars.start())
		{
			res: ?& := Fields![field!.Index];

			res.start_resolving(id->desc_pos());
			t: Type-std::DynOpt;
			TRY t := type::resolve(field!.Type!, _ctx);
			CATCH(err: std::Error-std::Shared) res.fail_share(&&err);
			res.resolve(:!(&&t));
		}

		RETURN Fields;
	}
}