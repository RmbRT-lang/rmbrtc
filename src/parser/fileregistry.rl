INCLUDE "file.rl"

INCLUDE 'std/string'
INCLUDE 'std/map'

::rlc::parser FileRegistry
{
PRIVATE:
	Utf8Cmp
	{
		STATIC cmp(
			a: std::Utf8 #&,
			b: std::Utf8 #&
		) INLINE int
			:= a.cmp(b);
	}

	TYPE FileMap := std::[std::Utf8, std::[File]Dynamic, Utf8Cmp]TreeMap;
	Files: FileMap;

PUBLIC:
	get(file: std::Utf8 #&) File *
	{
		entry ::= &Files.get(file);
		IF(entry->Ptr)
			RETURN entry->Ptr;
		ELSE
			RETURN (*entry := ::[File]new(file)).Ptr;
	}
}