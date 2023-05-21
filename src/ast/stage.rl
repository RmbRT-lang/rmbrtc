INCLUDE 'std/io/streamutil'

_
{
	[T...:TYPE] {T!&&...} {}
}

[U:TYPE]
__
{
	[T...:TYPE] {T!&&...} {}
	[T:TYPE] # <T!> INLINE := <T!>();
}

::rlc::ast [Stage: TYPE] DefaultContext
{
	PrevParent: ast::[Stage::Prev+]ScopeBase #\ -std::Opt;
	Parent: ast::[Stage]ScopeBase \ - std::Opt;
	PrevStmt: [Stage::Prev+]Statement # \ - std::Opt;
	Stmt: ast::[Stage]Statement \ - std::Opt;
	ParentInst: ast::[Stage]Instantiable * - std::Opt;

	{};
	{BARE} ();

	# in_parent(
		prev: ast::[Stage::Prev+]ScopeBase #\,
		parent: ast::[Stage]ScopeBase \
	) Stage::Context+
	{
		ret ::= <Stage::Context+ &>(THIS);
		ASSERT(prev);
		ret.PrevParent := :a(prev);
		ASSERT(parent);
		ret.Parent := :a(parent);

		prevName: std::StreamBuffer;
		name: std::StreamBuffer;
		TRY {
			prev->print_name(prevName);
			parent->print_name(name);
		} CATCH(CHAR #\) { = &&ret; }

		IF(TYPE TYPE(Stage) != TYPE TYPE(scoper::Config) && prevName <> name)
		{
			o ::= <<<std::io::OStream>>>(&std::io::out);
			std::io::write(o, prevName!++, " != ", name!++, "\n");
			DIE;
		}

		= &&ret;
	}

	# in_stmt(
		prev: ast::[Stage::Prev+]Statement #\,
		cur: ast::[Stage]Statement \
	) Stage::Context+
	{
		ret ::= <Stage::Context+ &>(THIS);
		ret.PrevStmt := :a(prev);
		ret.Stmt := :a(cur);
		= ret;
	}

	# in_path(instance: [Stage]Instantiable *) Stage::Context+
	{
		ret ::= <Stage::Context+ &>(THIS);
		ret.ParentInst := :a(instance);
		= ret;
	}

	# extend_with(
		lhs: [Stage]MergeableScopeItem &,
		rhs: [Stage::Prev+]MergeableScopeItem #&
	) VOID
	{
		TYPE SWITCH(lhs)
		{
		[Stage]Namespace:
		{
			this: ?& := <<[Stage]Namespace &>>(lhs);
			ns: ?& := <<[Stage::Prev+]Namespace #&>>(rhs);
			_ctx ::= in_parent(&ns, &this);

			FOR(test ::= ns.Tests.start())
				this.Tests += :transform(test!, _ctx);

			FOR(it ::= ns.Entries.start())
			{
				itItem: ?& := <<[Stage::Prev+]ScopeItem #&>>(it!.Value!);
				this.Entries.insert_or_merge(it!.Key!, itItem, _ctx);
			}
		}
		[Stage]Function:
		{
			this: ?& := <<[Stage]Function &>>(lhs);
			from: ?& := <<[Stage::Prev+]Function #&>>(rhs);
			_ctx: ?& :=  <Stage::Context+#&>(THIS);

			IF(from.Default)
			{
				IF(this.Default)
					THROW <MergeError>(&this, &from);
				this.Default := :a(:transform(from.Default!, _ctx));
			}

			FOR(var ::= from.Variants.start())
			{
				name ::= <Stage::Context+&>(THIS).transform_name(var!.Key);
				IF(prev ::= this.Variants.find(name))
					THROW <VariantMergeError>(this, prev!, var!.Value!);
				new: [Stage]Variant-std::Val := :transform(var!.Value!, _ctx);
				ASSERT(this.Variants.insert(new->Name, &&new));
			}
		}
		}
	}
}