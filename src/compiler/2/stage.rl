//INCLUDE "typededupler.rl"
INCLUDE "postparser.rl"

::rlc::compiler Stage2 {
	Build: compiler::Build \;

	{build: compiler::Build \}:
		Build := build;

	launch_workers() VOID
	{
	}


	run(rootScope: scoper::Namespace) VOID
	{
	}
}