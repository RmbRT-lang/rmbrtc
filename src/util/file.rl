INCLUDE 'std/string'
INCLUDE 'std/str'
INCLUDE 'std/memory'
INCLUDE 'std/vector'
INCLUDE 'std/err/filenotfound'

::rlc::util
{
	absolute_file(name: std::str::C8CView #&) std::Utf8
	{
		n: std::Utf8(name);
		n.append(0);

		IF(real ::= detail::realpath(n.data(), &detail::path_buf[0]))
			RETURN <std::Utf8>(real);

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
	) std::Utf8
	{
		path: std::Utf8(<std::str::C8CView>(base));
		IF(!base.Size)
			THROW;
		IF(base[base.Size-1] != '/')
			path.append('/');
		path.append(relative);

		RETURN path;
	}
}

::rlc::util::detail
{
	path_buf: std::[CHAR]Vector := :move(std::heap::[CHAR]alloc(4097));
	EXTERN realpath(CHAR #\, CHAR \) CHAR #*;
}