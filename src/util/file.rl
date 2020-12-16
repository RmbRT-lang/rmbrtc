INCLUDE 'std/string'
INCLUDE 'std/memory'
INCLUDE 'std/vector'
INCLUDE 'std/err/filenotfound'

::rlc::util
{
	absolute_file(name: std::[char#]Buffer #&) std::Utf8
	{
		n: std::Utf8(name, :cstring);

		IF(real ::= detail::realpath(n.data(), &detail::path_buf[0]))
			RETURN std::Utf8(real, :cstring);

		THROW std::io::FileNotFound(name);
	}

	(// Returns the parent directory, including the final '/'. /)
	parent_dir(name: std::[char#]Buffer #&) std::[char#]Buffer
	{
		FOR(i ::= name.Size; i--;)
			IF(name[i] == '/')
				RETURN name.cut(i+1);
		THROW;
	}

	concat_paths(
		base: std::[char#]Buffer #&,
		relative: std::[char#]Buffer #&
	) std::Utf8
	{
		path: std::Utf8(base);
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
	path_buf: std::[char]Vector(:move, std::[char]alloc(4097));
	EXTERN realpath(char #\, char \) char #*;
}