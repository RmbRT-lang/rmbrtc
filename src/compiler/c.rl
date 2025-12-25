INCLUDE "compiler.rl"
INCLUDE "../ast/fileregistry.rl"
INCLUDE "../util/file.rl"
INCLUDE "../ast/symbol.rl"
INCLUDE 'std/streambuffer'
INCLUDE 'std/vector'
INCLUDE 'std/set'

INCLUDE "../parser/templatedecl.rl"
INCLUDE "../parser/type.rl"
INCLUDE "../parser/stage.rl"
INCLUDE "../scoper/stage.rl"
INCLUDE "../resolver/stage.rl"
INCLUDE "../instantiator/stage.rl"
INCLUDE "../instantiator/rootscope.rl"
INCLUDE "../c/cprinter.rl"

::rlc::compiler CCompiler -> Compiler
{
}