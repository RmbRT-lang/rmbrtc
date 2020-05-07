# rmbrtc

`rmbrtc` is a self-hosted compiler for the RmbRT programming language.

**License**&emsp;
The compiler is released under the GNU Affero General Public License, version 3.
You can find a copy of the license in the `LICENSE` file of this repository.


**Compiling**&emsp;
To compile this compiler, use the [C bootstrap compiler](https://github.com/RmbRT-lang/rmbrtbc).
In a later version, this will probably no longer be possible, as `rmbrtc` will be using language features beyond what the bootstrap compiler supports.
The last released version that can still be compiled with the bootstrap compiler will be tagged as a special release and is guaranteed to be able to compile itself already.

To compile `rmbrtc` using the bootstrap compiler, you need to clone the [RmbRT standard library](https://github.com/RmbRT-lang/std), and check out the version corresponding to the version of `rmbrtc` you want to compile (as they are developed in parallel, versions depend on each other).
Corresponding version of `rmbrtc` and the standard library will have the same tag names, at least until they are mature enough that the design will no longer change significantly.
Set up the `RLINCLUDE` environment variable to point to the directory containing the standard library's `std` folder, and then invoke the compiler with the source file `src/main.rl`.