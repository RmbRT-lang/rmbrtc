INCLUDE "../stackframe.rl"
INCLUDE "../registers.rl"

(/ Eigenschaften unseres generators:

1. Für normale funktionen benutzen wir einen normalen linearen allokator mit reset bei scopes oder nach statements. Für Koroutinen und rekursives nehmen wir eine andere methode, die komprimiert.
2. Wir gucken uns an, welche instruktion welche register benötigt, und versuchen dann, die werte direkt schon in die richtigen register zu packen, damit sie nicht migrieren müssen. Dabei wäre es am besten, eine art constraint maske zu haben.
	1. Register LRU cache.
	2. Register swaps (XCHG) können theoretisch benutzt werden statt spills, wenn es nur um migrationen geht. Aber es könnte schwer sein, das in SIMD branchless abzubilden.
3. Instruktionen werden erst mal in eine Zwischenrepräsentation gepackt, die dann mgl. in einem zweiten Durchlauf zu Bytecode umgewandelt werden.
4. Der IR optimierer sollte pro backend sein, damit er genau weiß, was zu tun ist. Der kann dann auch prüfen, was zu tun ist, wenn SIMD / alignment etc. benutzt wird. Das richtige interleaving, die richtige anzahl von cache misses in flight, usw. D.h., der Codegenerator spielt noch in den Typchecker mit rein.
5. Was ist mit codegenerierung für inlinebare funktionen? Idealerweise geht da nur optional noch mal ein optimierer drüber, aber der code sollte alle mögliche arbeit schon vorher erledigt haben, sodass nur noch mal etwas scheduling oder so optimiert wird, oder noch mal vereinfachung, wenn nötig. Wobei das optional wäre, bzw. erst bei -O1 oder -O2 oder so. /)
::rlc::codegen::x86::o0 [#N] Generators {
	Stack: [#N]BumpStackFrames;
	Registers: [#N]Registers;
	Code: @(SIMD) RAW[][N];
}

::rlc::codegen::x86::o0 [#N]generate(ir0: Ir0[#][N]) VOID {
}