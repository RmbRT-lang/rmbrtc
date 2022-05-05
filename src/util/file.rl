INCLUDE 'std/string'
INCLUDE 'std/str'
INCLUDE 'std/memory'
INCLUDE 'std/vector'
INCLUDE 'std/err/filenotfound'

::rlc::util
{
	absolute_file(name: std::str::CV #&) std::Str
	{
		n: std::Str(name);
		n.append(:ch(0));

		IF(real ::= detail::realpath(n.data(), &detail::path_buf[0]))
			RETURN <std::Str>(real);

		THROW <std::io::FileNotFound>(name);
	}

	(// Returns the parent directory, including the final '/'. /)
	parent_dir(name: std::[CHAR#]Buffer #&) std::[CHAR#]Buffer
	{
		FOR(i ::= name.Size; i--;)
			IF(name[i] == '/')
				RETURN name.cut(i+1);
		THROW;
	}

	concat_paths(
		base: std::[CHAR#]Buffer #&,
		relative: std::[CHAR#]Buffer #&
	) std::Str
	{
		path: std::Str(<std::str::CV>(base++));
		IF(!base.Size)
			THROW;
		IF(base[base.Size-1] != '/')
			path.append(:ch('/'));
		path.append(relative++);

		RETURN path;
	}
}

::rlc::util::detail
{
	path_buf: std::[CHAR]Vec := :move(std::heap::[CHAR]alloc(4097));
	EXTERN realpath(CHAR #\, CHAR \) CHAR #*;
}