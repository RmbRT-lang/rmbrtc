INCLUDE "stage.rl"
INCLUDE "../resolver/stage.rl"
INCLUDE "../ast/class.rl"
INCLUDE "type.rl"


::rlc::instantiator [T:TYPE] TYPE RVec :=
	T!-std::Val-Resolveable-std::Vec-Resolveable;

::rlc::instantiator Class -> Instance, Type
{
	/// named and anonymous base & member variable types.
	PRIVATE BaseTypes: InstanceType-RVec;
	PRIVATE FieldTypes: ast::[Config]Type-RVec;

	PRIVATE Destructor: ast::[Config]Destructor-Resolveable;


	/// Inheritance lookup / registry.
	PRIVATE Bases: Class #\ - std::VecSet;
	PRIVATE TransitiveBases: Class #\ - std::VecSet;

	/// All instantiated deriving types.
	PRIVATE Concretisations: Class #\ - std::VecSet;
	PRIVATE TransitiveConcretisations: Class #\ - std::VecSet;


	{id: InstanceID #\} -> (id), ();
	{&&};



	# is_direct_base_of(c: Class #\) BOOL INLINE := Concretisations.find(c);
	# is_transitive_base_of(c: Class #\) BOOL INLINE := TransitiveConcretisations.find(c);
	# inherits_directly_from(c: Class #\) BOOL INLINE := Bases.find(c);
	# inherits_transitively_from(c: Class #\) BOOL INLINE := TransitiveBases.find(c);

	# id() InstanceID #\ INLINE := >(Instance).ID;
	# descriptor() ? := <<ast::[resolver::Config]Class #\>>(id()->Descriptor);

	resolve_size() VOID
	{
		IF(>(Type).Size.determined())
			RETURN;

	}

	PRIVATE resolve_bases() VOID {
	}

	PRIVATE resolve_field_types(
		ctx: Context #&
	) ast::[Config]Type-std::Val-Resolveable-std::Vec #&
	{
		IF(FieldTypes.determined())
			= *FieldTypes;

		desc ::= descriptor();
		fields: ?#& := desc->Members.Fields;

		FieldTypes.resolve(##fields.NamedVars + ##fields.AnonVars);

		_ctx: ClassContext := :childOf(&ctx, id());

		FOR(field ::= fields.NamedVars.start())
		{
			fieldV: ?#& := <<ast::[resolver::Config]MemberVariable#&>>(field!.Value!);
			res: ?& := FieldTypes![fieldV.Index];

			res.start_resolving(id()->desc_pos());
			t: ast::[Config]Type-std::Val (BARE);
			TRY t := type::resolve(fieldV.Type!, _ctx);
			CATCH(err: std::Error-std::Shared) res.fail_share(&&err);
			res.resolve(&&t);
		}

		FOR(field ::= fields.AnonVars.start())
		{
			res: ?& := FieldTypes![field!.Index];

			res.start_resolving(id()->desc_pos());
			t: ast::[Config]Type-std::Val (BARE);
			TRY t := type::resolve(field!.Type!, _ctx);
			CATCH(err: std::Error-std::Shared) res.fail_share(&&err);
			res.resolve(&&t);
		}

		= *FieldTypes;
	}

	resolve_destructor(
		ctx: Context #&
	) ast::[Config]Destructor #&
	{
		IF(Destructor.determined())
			= *Destructor;

		resolve_field_types(ctx);

		dtor: ast::[Config]Destructor (BARE);
		desc ::= <<ast::[resolver::Config]Class #\>>(id()->Descriptor);
		IF:!(_dtor ::= desc->Members.Destructor.ptr())
		{
			/// auto-generate destructor.
			/// 1. fields (reverse order)
			/// 2. base classes (reverse order)

			dtor.Body.Statements.resize_bare(##*FieldTypes);
			FOR(field ::= FieldTypes->start().ok())
			{
				dtorCall: ast::[Config]OperatorExpression (BARE);
				dtorCall!.Op := :destructor;
				member: ast::[Config]MemberReferenceExpression (BARE);
				member.Object := :a.ast::[Config]ThisExpression(BARE);
				member.Member := :field(id(), field());
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