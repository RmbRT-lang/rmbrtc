INCLUDE "compiler/c.rl"
INCLUDE "ast/namespace.rl"

::rlc {
	TEST "Nested namespace" {
		outer: ast::[resolver::Config]Namespace (BARE);
		outer.Parent := NULL;
		outer.Name := "outer";
		outer.Entries.Parent := &outer;
		inner: ast::[resolver::Config]Namespace -std::Dyn := :a(BARE);
		pInner ::= &inner!;
		inner!.Parent := &outer.Entries;
		inner!.Name := "inner";
		outer.Entries += :<>(&&inner);
		o ::= <<<std::io::OStream>>>(&std::io::out);
		pInner->print_name(o);
	}
}