INCLUDE "stage.rl"
INCLUDE "../resolver/stage.rl"
INCLUDE "../ast/class.rl"
INCLUDE "type.rl"


::rlc::instantiator Class -> Instance, Type
{
	/// named and anonymous member variable types.
	PRIVATE Fields: ast::[Config]Type-std::Dyn-Resolveable-std::Vec-Resolveable;
	PRIVATE Destructor: ast::[Config]Destructor-Resolveable;
	PRIVATE Bases: Class #\ - std::Vec; /// All base classes.
	PRIVATE Concretisations: Class #\ - std::Vec; /// All instantiated deriving types.

	resolve_bases() VOID {}

	resolve_fields(
		id: InstanceID #\,
		ctx: Context #&
	) ast::[Config]Type-std::Dyn-Resolveable-std::Vec #&
	{
		IF(Fields.determined())
			= *Fields;

		desc ::=  <<ast::[resolver::Config]Class #\>>(id->Descriptor);
		fields: ?#& := desc->Members.Fields;

		Fields.resolve(##fields.NamedVars + ##fields.AnonVars);

		_ctx: ClassContext := :childOf(&ctx, id);

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

		= *Fields;
	}

	resolve_destructor(
		id: InstanceID #\,
		ctx: Context #&
	) ast::[Config]Destructor #&
	{
		IF(Destructor.determined())
			= *Destructor;

		resolve_fields(id, ctx);

		dtor: ast::[Config]Destructor (BARE);
		desc ::= <<ast::[resolver::Config]Class #\>>(id->Descriptor);
		IF:!(_dtor ::= desc->Members.Destructor.ptr())
		{
			/// auto-generate destructor.
			/// 1. fields (reverse order)
			/// 2. base classes (reverse order)

			dtor.Body.Statements.resize_bare(##*Fields);
			FOR(field ::= Fields->start().ok())
			{
				dtorCall: ast::[Config]OperatorExpression-std::Dyn := :a(BARE);
				dtorCall!.Op := :destructor;
				member: ast::[Config]MemberReferenceExpression-std::Dyn := :a(BARE);
				member!.Object := :a.ast::[Config]ThisExpression(BARE);
				member!.Member := :field(id, field());
				member!.IsArrowAccess := FALSE;
				dtorCall!.Operands += :<>(&&member);
				dtorStmt: ast::[Config]ExpressionStatement-std::Dyn := :a(BARE);
				dtorStmt!.Expression := :<>(&&dtorCall);
				dtor.Body.Statements[:ok(field())] := :<>(&&dtorStmt);
			}
		} ELSE
		{
			dtor: ast::[Config]Destructor (BARE);
			dtor.Body.Statements.resize_bare(##_dtor->Body.Statements);
			dtor.Inline := _dtor->Inline;
			_ctx: StatementContext := :childOf(&ctx, &dtor.Body);
			FOR(stmt ::= _dtor->Body.Statements.start().ok())
				dtor.Body.Statements[stmt()] := statement::evaluate(stmt!, _ctx);
		}
		Destructor.resolve(&&dtor);

		= *Destructor;
	}
}