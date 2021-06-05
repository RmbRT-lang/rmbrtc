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
		symbolConstant,
		tuple,
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
			STATIC table: {tok::Type, ReferenceType}#[](
				(:and, ReferenceType::reference),
				(:doubleAnd, ReferenceType::tempReference));

			FOR(i ::= 0; i < ##table; i++)
				IF(p.consume(table[i].(0)))
					RETURN table[i].(1);

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
			STATIC table: {tok::Type, Indirection}#[](
				(:asterisk, Indirection::pointer),
				(:backslash, Indirection::nonnull),
				(:doubleDotExclamationMark, Indirection::expectDynamic),
				(:doubleDotQuestionMark, Indirection::maybeDynamic),
				(:at, Indirection::future));

			FOR(i ::= 0; i < ##table; i++)
				IF(p.consume(table[i].(0)))
					RETURN table[i].(1);

			RETURN Indirection::plain;
		}


		Qualifier
		{
			Const: BOOL;
			Volatile: BOOL;

			parse(
				p: Parser&) BOOL
			{
				start ::= p.progress();
				IF((Const := p.consume(:hash)))
					Volatile := p.consume(:dollar);
				ELSE IF((Volatile := p.consume(:dollar)))
					Const := p.consume(:hash);
				
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
				allowReferences: BOOL) VOID
			{
				Qualifier.parse(p);
				IF(allowReferences)
					Reference := parse_reference_type(p);
				ELSE
					Reference := :none;
			}
		}

		Modifier
		{
			Indirection: Type::Indirection;
			Qualifier: Type::Qualifier;
			IsArray: BOOL;
			ArraySize: std::[std::[Expression]Dynamic]Vector;

			parse(
				p: Parser&) BOOL
			{
				start ::= p.progress();
				Indirection := Type::parse_indirection(p);
				Qualifier.parse(p);

				IF(IsArray := p.consume(:bracketOpen))
				{
					IF(!p.consume(:bracketClose))
					{
						DO()
						{
							bounds ::= Expression::parse(p);
							IF(!bounds)
								p.fail("expected expression");
							ArraySize += :gc(bounds);
						} WHILE(p.consume(:comma))

						p.expect(:bracketClose);
					}
				}

				RETURN p.progress() != start;
			}
		}


		{};
		{t: Type &&}:
			Modifiers(&&t.Modifiers),
			Reference(t.Reference);

		Modifiers: std::[Modifier]Vector;
		Reference: Type::ReferenceType;
		Variadic: BOOL;

		[T:TYPE] PRIVATE STATIC parse_impl(
			p: Parser &) Type *
		{
			v: T;
			IF(v.parse(p))
			{
				t: Type \ := std::dup(&&v);
				WHILE(p.consume(:minus))
				{
					STATIC expect: tok::Type#[](
						:doubleColon,
						:bracketOpen,
						:identifier);
					found ::= FALSE;
					FOR(i ::= 0; i < ##expect; i++)
						found |= p.match(expect[i]);
					IF(!found)
						p.fail("expected symbol");

					next ::= Type::parse(p);
					ASSERT(next->type() == :name);
					
					tplArg: TemplateArg(:emplace, t);
					<TypeName \>(next)->Name.Children.back().Templates += &&tplArg;
					t := next;
				}
				RETURN t;
			}
			ELSE
				RETURN NULL;
		}

		STATIC parse(
			p: Parser &) Type! *
		{
			IF(v ::= [TypeOfExpression]parse_impl(p))
				RETURN v;
			IF(v ::= [TupleType]parse_impl(p))
				RETURN v;
			IF(v ::= [Signature]parse_impl(p))
				RETURN v;
			IF(v ::= [Void]parse_impl(p))
				RETURN v;
			IF(v ::= [TypeName]parse_impl(p))
				RETURN v;
			IF(v ::= [BuiltinType]parse_impl(p))
				RETURN v;
			IF(v ::= [SymbolConstantType]parse_impl(p))
				RETURN v;

			RETURN NULL;
		}

		PROTECTED parse_generic_part(
			p: Parser&) VOID
		{
			mod: Modifier;
			WHILE(mod.parse(p))
				Modifiers += &&mod;

			Reference := parse_reference_type(p);
			Variadic := p.consume(:tripleDot);
		}
	}

	Signature -> Type
	{
		# FINAL type() TypeType := :signature;
		{};

		Args: std::[std::[Type]Dynamic]Vector;
		Ret: std::[Type]Dynamic;

		parse(p: Parser&) BOOL
		{
			t: Trace(&p, "signature");
			// ((T1, T2) Ret)
			IF(!p.consume(:parentheseOpen))
				RETURN FALSE;

			p.expect(:parentheseOpen);

			IF(!p.consume(:parentheseClose))
			{
				DO(arg: Type *)
				{
					IF(arg := Type::parse(p))
						Args += :gc(arg);
					ELSE
						p.fail("expected type");
				} WHILE(p.consume(:comma))
				p.expect(:parentheseClose);
			}

			type ::= Type::parse(p);
			IF(!type)
				p.fail("expected type");
			Ret := :gc(type);

			p.expect(:parentheseClose);

			parse_generic_part(p);

			RETURN TRUE;
		}
	}

	Void -> Type
	{
		# FINAL type() TypeType := :void;

		parse(p: Parser&) BOOL
		{
			IF(!p.consume(:void))
				RETURN FALSE;
			parse_generic_part(p);
			RETURN TRUE;
		}
	}

	SymbolConstantType -> Type
	{
		# FINAL type() TypeType := :symbolConstant;

		Name: src::String;

		parse(p: Parser &) BOOL
		{
			IF(!p.consume(:colon))
				RETURN FALSE;
			p.expect(:identifier, &Name);

			parse_generic_part(p);

			RETURN TRUE;
		}
	}

	TupleType -> Type
	{
		# FINAL type() TypeType := :tuple;

		Types: Type - std::Dynamic - std::Vector;

		parse(p: Parser &) BOOL
		{
			IF(!p.consume(:braceOpen))
				RETURN FALSE;

			IF(t ::= Type::parse(p))
				Types += :gc(t);
			ELSE p.fail("expected type");
			p.expect(:comma);
			DO()
				IF(t ::= Type::parse(p))
					Types += :gc(t);
				ELSE p.fail("expected type");
				WHILE(p.consume(:comma))
			p.expect(:braceClose);

			parse_generic_part(p);
			RETURN TRUE;
		}
	}

	TypeOfExpression -> Type
	{
		# FINAL type() TypeType := :expression;

		Expression: std::[parser::Expression]Dynamic;

		parse(p: Parser &) BOOL
		{
			IF(!p.consume(:type))
				RETURN FALSE;
			p.expect(:parentheseOpen);
			IF(!(Expression := :gc(parser::Expression::parse(p))))
				p.fail("expected expression");
			p.expect(:parentheseClose);

			parse_generic_part(p);

			RETURN TRUE;
		}
	}

	TypeName -> Type
	{
		# FINAL type() TypeType := :name;
		Name: Symbol;
		NoDecay: BOOL;

		parse(p: Parser&) BOOL
		{
			IF(!Name.parse(p))
				RETURN FALSE;
			NoDecay := p.consume(:exclamationMark);
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
			uint,
			um,
			sm
		}

		# FINAL type() TypeType := :builtin;

		Kind: Primitive;

		parse(p: Parser&) BOOL
		{
			STATIC table: {tok::Type, Primitive}#[](
				(:bool, Primitive::bool),
				(:char, Primitive::char),
				(:int, Primitive::int),
				(:uint, Primitive::uint),
				(:um, Primitive::um),
				(:sm, Primitive::sm));

			FOR(i ::= 0; i < ##table; i++)
				IF(p.consume(table[i].(0)))
				{
					Kind := table[i].(1);
					Type::parse_generic_part(p);
					RETURN TRUE;
				}

			RETURN FALSE;
		}
	}
}