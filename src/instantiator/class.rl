INCLUDE "stage.rl"
INCLUDE "../resolver/stage.rl"
INCLUDE "../ast/class.rl"
INCLUDE "type.rl"


::rlc::instantiator Class -> Instance, Type
{
	/// named and anonymous member variable types.
	PRIVATE Fields: ast::[Config]Type-std::Val-Resolveable-std::Vec-Resolveable;
	PRIVATE Destructor: ast::[Config]Destructor-Resolveable;
	PRIVATE Bases: Class #\ - std::VecSet; /// All base classes.
	PRIVATE TransitiveBases: Class #\ - std::VecSet;
	PRIVATE Concretisations: Class #\ - std::VecSet; /// All instantiated deriving types.
	PRIVATE TransitiveConcretisations: Class #\ - std::VecSet;

	{};
	{&&};

	resolve_bases() VOID {}

	# is_direct_base_of(c: Class #\) BOOL INLINE := Concretisations.find(c);
	# is_transitive_base_of(c: Class #\) BOOL INLINE := TransitiveConcretisations.find(c);
	# inherits_directly_from(c: Class #\) BOOL INLINE := Bases.find(c);
	# inherits_transitively_from(c: Class #\) BOOL INLINE := TransitiveBases.find(c);

	resolve_fields(
		id: InstanceID #\,
		ctx: Context #&
	) ast::[Config]Type-std::Val-Resolveable-std::Vec #&
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
			t: ast::[Config]Type-std::Val (BARE);
			TRY t := type::resolve(fieldV.Type!, _ctx);
			CATCH(err: std::Error-std::Val) res.fail_share(&&err);
			res.resolve(&&t);
		}

		FOR(field ::= fields.AnonVars.start())
		{
			res: ?& := Fields![field!.Index];

			res.start_resolving(id->desc_pos());
			t: ast::[Config]Type-std::Val (BARE);
			TRY t := type::resolve(field!.Type!, _ctx);
			CATCH(err: std::Error-std::Val) res.fail_share(&&err);
			res.resolve(&&t);
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
				dtorCall: ast::[Config]OperatorExpression (BARE);
				dtorCall!.Op := :destructor;
				member: ast::[Config]MemberReferenceExpression (BARE);
				member.Object := :a.ast::[Config]ThisExpression(BARE);
				member.Member := :field(id, field());
				member.IsArrowAccess := FALSE;
				dtorCall.Operands += :dup(&&member);
				dtorStmt: ast::[Config]ExpressionStatement (BARE);
				dtorStmt.Expression := :dup(&&dtorCall);
				dtor.Body.Statements[:ok(field())] := :dup(&&dtorStmt);
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