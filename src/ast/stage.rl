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
	PrevParent: [Stage::Prev+]ScopeBase #* -__;
	Parent: [Stage]ScopeBase * -__;
	PrevStmt: [Stage::Prev+]Statement # * - __;
	Stmt: [Stage]Statement * -__;
	ParentCtx: Stage::Context #*;

	# in_parent(
		prev: [Stage::Prev+]ScopeBase #*,
		parent: [Stage]ScopeBase *
	) Stage::Context+ #& INLINE := <Stage::Context+ #&>(THIS);

	# in_stmt(
		prev: [Stage::Prev+]Statement #*,
		cur: [Stage]Statement *
	) Stage::Context+ #& INLINE := <Stage::Context+ #&>(THIS);
}