INCLUDE 'std/tempalloc'
INCLUDE 'std/str'
INCLUDE 'std/hash'
INCLUDE 'std/io/format'

::rlc::src
{
	TYPE Index := U4; /// We need to be able to handle files larger than 64KiB, as that can realistically be exceeded in practice.
	TYPE Size := U2; /// These are mostly used for printing diagnostics anyway, and a diagnostic dump larger than 64KiB is meaningless.
	TYPE Line := U2;
	TYPE Column := U2; /// Lines longer than 64Ki or files longer than 64Ki lines will have unreliable diagnostics, but that's not really a problem, I think. We do not have the unity build problem to begin with.
	TYPE File := U2; /// We want to be able to support more than 256 files total. 64Ki sounds reasonable as an upper limit to how many files we want to support. Any more than that would be immense bloatware, anyway, and should never be built to begin with.

	(// Byte offset into a file. /)
	Position
	{
		Pos: U4;

		# file() U2 -- := Pos >> 21; // 11bit, up to 2048 code files per project.
		# byte() Index -- := Pos & (1 << 21 -1); // 21 bit, up to 2MiB code files (~32K LOC).

		{} --;
		{file: U2, byte: Index} --: Pos := (file << 21) | (byte & (1 << 21 -1));
		:raw{pos: U4}: Pos := pos;

		# at() WHERE {
			last_nl: U4;
			line: U4 := 1;

			FOR(fileContents[file()]![FOR byte()])
			{
				line += IT == '\n';
				last_nl := IT == '\n' ?? IOTA : last_nl;
			}
			= <WHERE>(fileNames[file()]![], line, byte() - last_nl);
		}
	}

	Span {
		Start: src::Index;
		Length: src::Size;
		# span(other: THIS) THIS
		{
			start ::= std::math::min(THIS.Start, other.Start);
			end ::= std::math::max(THIS.end(), other.end());
			= (start, end - start);
		}

		# contents(file: U2) CHAR#[#] --
			:= >fileContents[file]![FROM Start FOR Length];

		# <BOOL> INLINE := Length != 0;
		# end() Index := Start + Length;
	}



	// CAUTION: keep capacity in sync with file limit, so that we do not get any reallocations, as this gets modified in a different thread.

	// Names for our files.
	fileNamesAlloc: std::temp::Alloc := :custom(1 << 20, 1 << 20);
	fileNames: CHAR#[#]-std::Vec;
	fileNameHashes: U8-std::Vec;

	// Source code.
	fileContents: CHAR[#]-std::Vec;
	fileContentsAlloc: std::temp::Alloc := :custom(16 << 20, 2 << 20);

	::init file_rl() VOID
	{
		fileNames.reserve(2048);
		fileNameHashes.reserve(2048);
		fileContents.reserve(2048);
	}

	IncludeContext {
		From: WHERE;
		File: CHAR#[#];
		{...};
	}
	alloc_file_contents(size: U8, ctx: VOID *) VOID * {
		dec ::= std::io::format::dec(size);
		_ctx: IncludeContext * := >ctx;
		at: WHERE := _ctx ?? _ctx->From : HERE;
		file: CHAR#[#] := _ctx ?? _ctx->File : "file"[#];
		IF(size > 1<<21)
		{
			term::error(at, "size of ", file, " exceeds 2MiB bounds (", dec, ")");
		}  ELSE IF(size > 3<<19)
		{
			term::warning(at, file, " is getting close to the 2MiB size limit: ", dec);
		}

		mem ::= src::fileContentsAlloc.alloc_raw(size+32, PAGE);

		std::mem::cpy(
			<U1 *>(mem) + size,
			"\000\000\000\n\"'´`\n\n\n/)/)/)/)/)/)/)/)/)/)/)/)/)/)/)"[],
			32);
		= mem;
	}

	has_file(path: CHAR#[#]) src::File-std::Opt --
		:= has_file_h(std::hash_str(path), path);

	has_file_h(h: U8, path: CHAR#[#]) src::File-std::Opt
	{
		// TODO: we want more performance here.
		FOR(fileNameHashes!)
			IF(IT == h && std::str::eq(fileNames[IOTA], path))
				= :a(IOTA);
		= NULL;
	}

	add_file(h: U8, path: os::fs::FilePath, from: WHERE) {src::File, CHAR#[#]}
	{
		path_str: CHAR[512] (NOINIT);
		len ::= path.to_c_path(path_str[#]);

		h ::= std::hash_str(path_str[FOR len]);
		IF(f ::= has_file_h(h, path_str[FOR len]))
			= (*f, fileContents[*f]);

		IF:!(content ::= os::fs::ReadFile(path, NULL))
		{
			error ::= std::str::c(<CHAR#\>(content.(0))[]);

			os::term::Print_v(
				:style(:normal, :red),
				std::str::c(from.(0)[]),
				":",
				std::io::format::dec(from.(1)),
				":",
				std::io::format::dec(from.(2)),
				": error: \"",
				path_str[FOR len],
				"\" could not be included: ",
				error,
				"\n"
			);
		}

		source ::= <CHAR\>(content->Data)[FOR content->Size];
		= (add_file_with_source_ok(h, path_str[FOR len], source), source);
	}

	add_file_with_source(path: CHAR#[#], source: CHAR[#]) src::File-std::Opt
	{
		h ::= std::hash_str(path);
		IF(file ::= has_file_h(h, path))
			= NULL;
		= :a(add_file_with_source_ok(h, path, source));
	}

	// The source will be owned by the compiler. The name will be copied.
	add_file_with_source_ok(h: U8, path: CHAR#[#], source: CHAR[#]) src::File
	{
		file ::= ##src::fileNameHashes;
		src::fileNameHashes += h;

		mem ::= src::fileNamesAlloc.alloc_raw(##path+1, CACHELINE);
		<U1 *>(mem)[##path] := 0;


		std::mem::cpy(mem, &path[0], ##path);

		src::fileNames += <CHAR#\>(mem)[FOR ##path];
		src::fileContents += source;
		= file;
	}
}