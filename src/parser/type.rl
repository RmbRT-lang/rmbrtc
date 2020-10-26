INCLUDE "symbol.rl"
INCLUDE "parser.rl"
INCLUDE "expression.rl"

::rlc::parser
{
	ENUM TypeType
	{
		signature,
		void,
		name,
		expression,
		builtin
	}

	Type VIRTUAL
	{
		# ABSTRACT type() TypeType;

		ENUM ReferenceType
		{
			none,
			reference,
			tempReference
		}

		PRIVATE STATIC parse_reference_type(
			p: Parser&) Type::ReferenceType
		{
			STATIC table: std::[tok::Type, ReferenceType]Pair#[](
				std::pair(tok::Type::and, ReferenceType::reference),
				std::pair(tok::Type::doubleAnd, ReferenceType::tempReference));

			FOR(i ::= 0; i < ::size(table); i++)
				IF(p.consume(table[i].First))
					RETURN table[i].Second;

			RETURN ReferenceType::none;
		}

		ENUM Indirection
		{
			plain,
			pointer,
			nonnull,
			expectDynamic,
			maybeDynamic,
			future
		}

		PRIVATE STATIC parse_indirection(
			p: Parser&) Type::Indirection
		{
			STATIC table: std::[tok::Type, Indirection]Pair#[](
				std::pair(tok::Type::asterisk, Indirection::pointer),
				std::pair(tok::Type::backslash, Indirection::nonnull),
				std::pair(tok::Type::doubleDotExclamationMark, Indirection::expectDynamic),
				std::pair(tok::Type::doubleDotQuestionMark, Indirection::maybeDynamic),
				std::pair(tok::Type::at, Indirection::future));

			FOR(i ::= 0; i < ::size(table); i++)
				IF(p.consume(table[i].First))
					RETURN table[i].Second;

			RETURN Indirection::plain;
		}


		Qualifier
		{
			Const: bool;
			Volatile: bool;

			parse(
				p: Parser&) bool
			{
				start ::= p.progress();
				IF((Const := p.consume(tok::Type::hash)))
					Volatile := p.consume(tok::Type::dollar);
				ELSE IF((Volatile := p.consume(tok::Type::dollar)))
					Const := p.consume(tok::Type::hash);
				
				RETURN p.progress() != start;
			}
		}

		(// Modifiers to be applied to auto types. /)
		Auto
		{
			Qualifier: Type::Qualifier;
			Reference: Type::ReferenceType;

			parse(p: Parser &) INLINE VOID { parse(p, TRUE); }
			parse(
				p: Parser&,
				allowReferences: bool) VOID
			{
				Qualifier.parse(p);
				Reference := parse_reference_type(p);
				IF(!allowReferences
				&& Reference != ReferenceType::none)
					p.fail("forbidden reference specifier");
			}
		}

		Modifier
		{
			Indirection: Type::Indirection;
			Qualifier: Type::Qualifier;
			IsArray: bool;
			ArraySize: std::[std::[Expression]Dynamic]Vector;

			parse(
				p: Parser&) bool
			{
				start ::= p.progress();
				Indirection := Type::parse_indirection(p);
				Qualifier.parse(p);

				IF(IsArray := p.consume(tok::Type::bracketOpen))
				{
					IF(!p.consume(tok::Type::bracketClose))
					{
						DO()
						{
							bounds ::= Expression::parse(p);
							IF(!bounds)
								p.fail("expected expression");
							ArraySize.push_back(bounds);
						} WHILE(p.consume(tok::Type::comma))

						p.expect(tok::Type::bracketClose);
					}
				}

				RETURN p.progress() != start;
			}
		}


		CONSTRUCTOR();
		CONSTRUCTOR(t: Type &&):
			Modifiers(__cpp_std::move(t.Modifiers)),
			Reference(t.Reference);

		Modifiers: std::[Modifier]Vector;
		Reference: Type::ReferenceType;

		[T:TYPE] PRIVATE STATIC parse_impl(
			p: Parser &) T! *
		{
			v: T;
			IF(v.parse(p))
				RETURN std::dup_mv(v);
			ELSE
				RETURN NULL;
		}

		STATIC parse(
			p: Parser &) Type! *
		{
			IF(v ::= [TypeOfExpression]parse_impl(p))
				RETURN v;
			IF(v ::= [Signature]parse_impl(p))
				RETURN v;
			IF(v ::= [Void]parse_impl(p))
				RETURN v;
			IF(v ::= [TypeName]parse_impl(p))
				RETURN v;
			IF(v ::= [BuiltinType]parse_impl(p))
				RETURN v;

			RETURN NULL;
		}

		PROTECTED parse_generic_part(
			p: Parser&) VOID
		{
			mod: Modifier;
			WHILE(mod.parse(p))
				Modifiers.push_back(__cpp_std::move(mod));

			Reference := parse_reference_type(p);
		}
	}

	Signature -> Type
	{
		# FINAL type() TypeType := TypeType::signature;
		CONSTRUCTOR();

		Args: std::[std::[Type]Dynamic]Vector;
		Ret: std::[Type]Dynamic;

		parse(p: Parser&) bool
		{
			t: Trace(&p, "signature");
			// ((T1, T2) Ret)
			IF(!p.consume(tok::Type::parentheseOpen))
				RETURN FALSE;

			p.expect(tok::Type::parentheseOpen);

			IF(!p.consume(tok::Type::parentheseClose))
			{
				DO(arg: Type *)
				{
					IF(arg := Type::parse(p))
						Args.push_back(std::[Type]Dynamic(arg));
					ELSE
						p.fail("expected type");
				} WHILE(p.consume(tok::Type::comma))
				p.expect(tok::Type::parentheseClose);
			}

			type ::= Type::parse(p);
			IF(!type)
				p.fail("expected type");
			Ret := type;

			p.expect(tok::Type::parentheseClose);

			parse_generic_part(p);

			RETURN TRUE;
		}
	}

	Void -> Type
	{
		# FINAL type() TypeType := TypeType::void;

		parse(p: Parser&) bool
		{
			IF(!p.consume(tok::Type::void))
				RETURN FALSE;
			parse_generic_part(p);
			RETURN TRUE;
		}
	}

	TypeOfExpression -> Type
	{
		# FINAL type() TypeType := TypeType::expression;

		Expression: std::[parser::Expression]Dynamic;

		parse(p: Parser &) bool
		{
			IF(!p.consume(tok::Type::type))
				RETURN FALSE;
			p.expect(tok::Type::parentheseOpen);
			IF(!(Expression := parser::Expression::parse(p)))
				p.fail("expected expression");
			p.expect(tok::Type::parentheseClose);

			RETURN TRUE;
		}
	}

	TypeName -> Type
	{
		# FINAL type() TypeType := TypeType::name;
		Name: Symbol;
		NoDecay: bool;

		parse(p: Parser&) bool
		{
			IF(!Name.parse(p))
				RETURN FALSE;
			NoDecay := p.consume(tok::Type::exclamationMark);
			parse_generic_part(p);
			RETURN TRUE;
		}
	}

	BuiltinType -> Type
	{
		ENUM Primitive
		{
			bool,
			char,
			int,
			uint
		}

		# FINAL type() TypeType := TypeType::builtin;

		Kind: Primitive;

		parse(p: Parser&) bool
		{
			STATIC table: std::[tok::Type, Primitive]Pair#[](
				std::pair(tok::Type::bool, Primitive::bool),
				std::pair(tok::Type::char, Primitive::char),
				std::pair(tok::Type::int, Primitive::int),
				std::pair(tok::Type::uint, Primitive::uint));

			FOR(i ::= 0; i < ::size(table); i++)
				IF(p.consume(table[i].First))
				{
					Kind := table[i].Second;
					parse_generic_part(p);
					RETURN TRUE;
				}

			RETURN FALSE;
		}
	}
}