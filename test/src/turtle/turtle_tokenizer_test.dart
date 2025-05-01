import 'package:test/test.dart';
import 'package:rdf_core/src/turtle/turtle_tokenizer.dart';

void main() {
  group('TurtleTokenizer', () {
    test('should tokenize prefixes', () {
      final tokenizer = TurtleTokenizer(
        '@prefix solid: <http://www.w3.org/ns/solid/terms#> .',
      );
      expect(tokenizer.nextToken().type, equals(TokenType.prefix));
      expect(tokenizer.nextToken().type, equals(TokenType.prefixedName));
      expect(tokenizer.nextToken().type, equals(TokenType.iri));
      expect(tokenizer.nextToken().type, equals(TokenType.dot));
      expect(tokenizer.nextToken().type, equals(TokenType.eof));
    });

    test('should tokenize IRIs', () {
      final tokenizer = TurtleTokenizer('<http://example.com/foo>');
      expect(tokenizer.nextToken().type, equals(TokenType.iri));
      expect(tokenizer.nextToken().type, equals(TokenType.eof));
    });

    test('should tokenize blank nodes', () {
      final tokenizer = TurtleTokenizer('_:b1');
      expect(tokenizer.nextToken().type, equals(TokenType.blankNode));
      expect(tokenizer.nextToken().type, equals(TokenType.eof));
    });

    test('should tokenize literals', () {
      final tokenizer = TurtleTokenizer('"Hello, World!"');
      expect(tokenizer.nextToken().type, equals(TokenType.literal));
      expect(tokenizer.nextToken().type, equals(TokenType.eof));
    });

    test('should tokenize typed literals', () {
      final tokenizer = TurtleTokenizer(
        '"42"^^<http://www.w3.org/2001/XMLSchema#integer>',
      );
      final literalToken = tokenizer.nextToken();
      expect(literalToken.type, equals(TokenType.literal));
      expect(
        literalToken.value,
        equals('"42"^^<http://www.w3.org/2001/XMLSchema#integer>'),
      );
      expect(tokenizer.nextToken().type, equals(TokenType.eof));
    });

    test('should tokenize typed literals with prefixed name as type', () {
      final tokenizer = TurtleTokenizer('"42"^^xsd:integer');
      final literalToken = tokenizer.nextToken();
      expect(literalToken.type, equals(TokenType.literal));
      expect(literalToken.value, equals('"42"^^xsd:integer'));
      expect(tokenizer.nextToken().type, equals(TokenType.eof));
    });

    test('should tokenize language-tagged literals', () {
      final tokenizer = TurtleTokenizer('"Hello"@en');
      expect(tokenizer.nextToken().type, equals(TokenType.literal));
      expect(tokenizer.nextToken().type, equals(TokenType.eof));
    });

    test('should tokenize triples', () {
      final tokenizer = TurtleTokenizer(
        '<http://example.com/foo> <http://example.com/bar> "baz" .',
      );
      expect(tokenizer.nextToken().type, equals(TokenType.iri));
      expect(tokenizer.nextToken().type, equals(TokenType.iri));
      expect(tokenizer.nextToken().type, equals(TokenType.literal));
      expect(tokenizer.nextToken().type, equals(TokenType.dot));
      expect(tokenizer.nextToken().type, equals(TokenType.eof));
    });

    test('should tokenize blank node triples', () {
      final tokenizer = TurtleTokenizer('[ <http://example.com/bar> "baz" ] .');
      expect(tokenizer.nextToken().type, equals(TokenType.openBracket));
      expect(tokenizer.nextToken().type, equals(TokenType.iri));
      expect(tokenizer.nextToken().type, equals(TokenType.literal));
      expect(tokenizer.nextToken().type, equals(TokenType.closeBracket));
      expect(tokenizer.nextToken().type, equals(TokenType.dot));
      expect(tokenizer.nextToken().type, equals(TokenType.eof));
    });

    test('should tokenize semicolon-separated triples', () {
      final tokenizer = TurtleTokenizer(
        '<http://example.com/foo> <http://example.com/bar> "baz" ; <http://example.com/qux> "quux" .',
      );
      expect(tokenizer.nextToken().type, equals(TokenType.iri));
      expect(tokenizer.nextToken().type, equals(TokenType.iri));
      expect(tokenizer.nextToken().type, equals(TokenType.literal));
      expect(tokenizer.nextToken().type, equals(TokenType.semicolon));
      expect(tokenizer.nextToken().type, equals(TokenType.iri));
      expect(tokenizer.nextToken().type, equals(TokenType.literal));
      expect(tokenizer.nextToken().type, equals(TokenType.dot));
      expect(tokenizer.nextToken().type, equals(TokenType.eof));
    });

    test('should tokenize a type declaration', () {
      final tokenizer = TurtleTokenizer(
        '<http://example.com/foo> a <http://example.com/Bar> .',
      );
      expect(tokenizer.nextToken().type, equals(TokenType.iri));
      expect(tokenizer.nextToken().type, equals(TokenType.a));
      expect(tokenizer.nextToken().type, equals(TokenType.iri));
      expect(tokenizer.nextToken().type, equals(TokenType.dot));
      expect(tokenizer.nextToken().type, equals(TokenType.eof));
    });

    test('should not include dots in prefixed names', () {
      final tokenizer = TurtleTokenizer(
        'pro:card a foaf:PersonalProfileDocument; foaf:maker :me; foaf:primaryTopic :me.',
      );
      expect(tokenizer.nextToken().type, equals(TokenType.prefixedName));
      expect(tokenizer.nextToken().type, equals(TokenType.a));
      expect(tokenizer.nextToken().type, equals(TokenType.prefixedName));
      expect(tokenizer.nextToken().type, equals(TokenType.semicolon));
      expect(tokenizer.nextToken().type, equals(TokenType.prefixedName));
      expect(tokenizer.nextToken().type, equals(TokenType.prefixedName));
      expect(tokenizer.nextToken().type, equals(TokenType.semicolon));
      expect(tokenizer.nextToken().type, equals(TokenType.prefixedName));
      expect(tokenizer.nextToken().type, equals(TokenType.prefixedName));
      expect(tokenizer.nextToken().type, equals(TokenType.dot));
      expect(tokenizer.nextToken().type, equals(TokenType.eof));
    });

    test('should skip comments', () {
      final tokenizer = TurtleTokenizer(
        '<http://example.com/foo> # This is a comment\n <http://example.com/bar> "baz" .',
      );
      expect(tokenizer.nextToken().type, equals(TokenType.iri));
      expect(tokenizer.nextToken().type, equals(TokenType.iri));
      expect(tokenizer.nextToken().type, equals(TokenType.literal));
      expect(tokenizer.nextToken().type, equals(TokenType.dot));
      expect(tokenizer.nextToken().type, equals(TokenType.eof));
    });

    test('should handle inline comments', () {
      final tokenizer = TurtleTokenizer('''
        <http://example.com/foo> # Comment after IRI
        <http://example.com/bar> # Another comment
        "baz" . # Comment after statement
      ''');
      expect(tokenizer.nextToken().type, equals(TokenType.iri));
      expect(tokenizer.nextToken().type, equals(TokenType.iri));
      expect(tokenizer.nextToken().type, equals(TokenType.literal));
      expect(tokenizer.nextToken().type, equals(TokenType.dot));
      expect(tokenizer.nextToken().type, equals(TokenType.eof));
    });

    test('should handle escaped characters in literals', () {
      final tokenizer = TurtleTokenizer('"Hello\\nWorld"');
      final token = tokenizer.nextToken();
      expect(token.type, equals(TokenType.literal));
      expect(token.value, equals('"Hello\\nWorld"'));
    });

    test('should handle Unicode escape sequences in literals', () {
      final tokenizer = TurtleTokenizer('"Copyright \\u00A9"');
      final token = tokenizer.nextToken();
      expect(token.type, equals(TokenType.literal));
      expect(token.value, equals('"Copyright \\u00A9"'));
    });

    test('should track line numbers correctly', () {
      final tokenizer = TurtleTokenizer('''
        <http://example.com/foo>
        <http://example.com/bar>
        "baz" .
      ''');

      final token1 = tokenizer.nextToken(); // First IRI
      final token2 = tokenizer.nextToken(); // Second IRI
      final token3 = tokenizer.nextToken(); // Literal

      expect(token1.line, equals(1));
      expect(token2.line, equals(2));
      expect(token3.line, equals(3));
    });

    test('should throw FormatException for unclosed IRI', () {
      final tokenizer = TurtleTokenizer('<http://example.com/foo');
      expect(() => tokenizer.nextToken(), throwsFormatException);
    });

    test('should throw FormatException for unclosed literal', () {
      final tokenizer = TurtleTokenizer('"unclosed literal');
      expect(() => tokenizer.nextToken(), throwsFormatException);
    });

    test('should tokenize multiple prefixes', () {
      final tokenizer = TurtleTokenizer('''
        @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
        @prefix foaf: <http://xmlns.com/foaf/0.1/> .
      ''');

      // First prefix declaration
      expect(tokenizer.nextToken().type, equals(TokenType.prefix));
      expect(tokenizer.nextToken().type, equals(TokenType.prefixedName));
      expect(tokenizer.nextToken().type, equals(TokenType.iri));
      expect(tokenizer.nextToken().type, equals(TokenType.dot));

      // Second prefix declaration
      expect(tokenizer.nextToken().type, equals(TokenType.prefix));
      expect(tokenizer.nextToken().type, equals(TokenType.prefixedName));
      expect(tokenizer.nextToken().type, equals(TokenType.iri));
      expect(tokenizer.nextToken().type, equals(TokenType.dot));

      expect(tokenizer.nextToken().type, equals(TokenType.eof));
    });

    test('should recognize @prefix directive', () {
      final tokenizer = TurtleTokenizer(
        '@prefix foaf: <http://xmlns.com/foaf/0.1/> .',
      );

      final token1 = tokenizer.nextToken();
      expect(token1.type, equals(TokenType.prefix));
      expect(token1.value, equals('@prefix'));

      final token2 = tokenizer.nextToken();
      expect(token2.type, equals(TokenType.prefixedName));
      expect(token2.value, equals('foaf:'));

      final token3 = tokenizer.nextToken();
      expect(token3.type, equals(TokenType.iri));
      expect(token3.value, equals('<http://xmlns.com/foaf/0.1/>'));

      final token4 = tokenizer.nextToken();
      expect(token4.type, equals(TokenType.dot));
    });

    test('should recognize @base directive', () {
      final tokenizer = TurtleTokenizer('@base <http://example.org/> .');

      final token1 = tokenizer.nextToken();
      expect(token1.type, equals(TokenType.base));
      expect(token1.value, equals('@base'));

      final token2 = tokenizer.nextToken();
      expect(token2.type, equals(TokenType.iri));
      expect(token2.value, equals('<http://example.org/>'));

      final token3 = tokenizer.nextToken();
      expect(token3.type, equals(TokenType.dot));
    });

    test('should recognize IRIs', () {
      final tokenizer = TurtleTokenizer(
        '<http://example.org/subject> <http://example.org/predicate> <http://example.org/object> .',
      );

      final token1 = tokenizer.nextToken();
      expect(token1.type, equals(TokenType.iri));
      expect(token1.value, equals('<http://example.org/subject>'));

      final token2 = tokenizer.nextToken();
      expect(token2.type, equals(TokenType.iri));
      expect(token2.value, equals('<http://example.org/predicate>'));

      final token3 = tokenizer.nextToken();
      expect(token3.type, equals(TokenType.iri));
      expect(token3.value, equals('<http://example.org/object>'));

      final token4 = tokenizer.nextToken();
      expect(token4.type, equals(TokenType.dot));
    });

    test('should recognize relative IRIs', () {
      final tokenizer = TurtleTokenizer('<subject> <predicate> <object> .');

      final token1 = tokenizer.nextToken();
      expect(token1.type, equals(TokenType.iri));
      expect(token1.value, equals('<subject>'));

      final token2 = tokenizer.nextToken();
      expect(token2.type, equals(TokenType.iri));
      expect(token2.value, equals('<predicate>'));

      final token3 = tokenizer.nextToken();
      expect(token3.type, equals(TokenType.iri));
      expect(token3.value, equals('<object>'));

      final token4 = tokenizer.nextToken();
      expect(token4.type, equals(TokenType.dot));
    });

    test('should recognize mixed prefix, base and triple statements', () {
      final input = '''
        @prefix ex: <http://example.org/> .
        @base <http://example.org/base/> .
        
        <relative> a ex:Type .
      ''';
      final tokenizer = TurtleTokenizer(input);

      // @prefix statement
      expect(tokenizer.nextToken().type, equals(TokenType.prefix));
      expect(tokenizer.nextToken().type, equals(TokenType.prefixedName));
      expect(tokenizer.nextToken().type, equals(TokenType.iri));
      expect(tokenizer.nextToken().type, equals(TokenType.dot));

      // @base statement
      expect(tokenizer.nextToken().type, equals(TokenType.base));
      expect(tokenizer.nextToken().type, equals(TokenType.iri));
      expect(tokenizer.nextToken().type, equals(TokenType.dot));

      // triple statement
      expect(tokenizer.nextToken().type, equals(TokenType.iri));
      expect(tokenizer.nextToken().type, equals(TokenType.a));
      expect(tokenizer.nextToken().type, equals(TokenType.prefixedName));
      expect(tokenizer.nextToken().type, equals(TokenType.dot));

      // End of input
      expect(tokenizer.nextToken().type, equals(TokenType.eof));
    });

    test('should handle comments and whitespace', () {
      final input = '''
        # This is a comment
        @prefix ex: <http://example.org/> . # Comment after statement
        
        # Comment before @base
        @base <http://example.org/base/> .
        
        # Comment before triple
        <subject> a ex:Type . # Comment after triple
      ''';
      final tokenizer = TurtleTokenizer(input);

      // @prefix statement
      expect(tokenizer.nextToken().type, equals(TokenType.prefix));
      expect(tokenizer.nextToken().type, equals(TokenType.prefixedName));
      expect(tokenizer.nextToken().type, equals(TokenType.iri));
      expect(tokenizer.nextToken().type, equals(TokenType.dot));

      // @base statement
      expect(tokenizer.nextToken().type, equals(TokenType.base));
      expect(tokenizer.nextToken().type, equals(TokenType.iri));
      expect(tokenizer.nextToken().type, equals(TokenType.dot));

      // triple statement
      expect(tokenizer.nextToken().type, equals(TokenType.iri));
      expect(tokenizer.nextToken().type, equals(TokenType.a));
      expect(tokenizer.nextToken().type, equals(TokenType.prefixedName));
      expect(tokenizer.nextToken().type, equals(TokenType.dot));

      // End of input
      expect(tokenizer.nextToken().type, equals(TokenType.eof));
    });

    test('should properly handle prefixed names with empty prefix', () {
      final tokenizer = TurtleTokenizer(':localName');
      final token = tokenizer.nextToken();
      expect(token.type, equals(TokenType.prefixedName));
      expect(token.value, equals(':localName'));
      expect(tokenizer.nextToken().type, equals(TokenType.eof));
    });

    test('should handle escaped characters in IRIs', () {
      final tokenizer = TurtleTokenizer('<http://example.org/path\\u00A9>');
      final token = tokenizer.nextToken();
      expect(token.type, equals(TokenType.iri));
      expect(token.value, equals('<http://example.org/path\\u00A9>'));
    });

    test('should handle recognizing \'a\' keyword in various contexts', () {
      final tokenizer1 = TurtleTokenizer('a\n');
      expect(tokenizer1.nextToken().type, equals(TokenType.a));

      final tokenizer2 = TurtleTokenizer('a\t');
      expect(tokenizer2.nextToken().type, equals(TokenType.a));

      final tokenizer3 = TurtleTokenizer('abc');
      // In diesem Fall sollte 'abc' als präfixierter Name erkannt werden
      expect(tokenizer3.nextToken().type, equals(TokenType.prefixedName));
    });

    test('should handle incomplete or malformed prefixed names', () {
      // Ein Präfix ohne lokalen Namen
      final tokenizer1 = TurtleTokenizer('ex:');
      final token1 = tokenizer1.nextToken();
      expect(token1.type, equals(TokenType.prefixedName));
      expect(token1.value, equals('ex:'));

      // Nur ein Präfix ohne Doppelpunkt
      final tokenizer2 = TurtleTokenizer('example');
      final token2 = tokenizer2.nextToken();
      expect(token2.type, equals(TokenType.prefixedName));
      expect(token2.value, equals('example'));
    });

    test('should handle collections with parentheses', () {
      final tokenizer = TurtleTokenizer(
        '( <http://example.org/item1> <http://example.org/item2> )',
      );
      expect(tokenizer.nextToken().type, equals(TokenType.openParen));
      expect(tokenizer.nextToken().type, equals(TokenType.iri));
      expect(tokenizer.nextToken().type, equals(TokenType.iri));
      expect(tokenizer.nextToken().type, equals(TokenType.closeParen));
      expect(tokenizer.nextToken().type, equals(TokenType.eof));
    });

    test('should handle comma-separated object lists', () {
      final tokenizer = TurtleTokenizer(
        '<http://example.org/subject> <http://example.org/predicate> "obj1", "obj2", "obj3" .',
      );
      expect(tokenizer.nextToken().type, equals(TokenType.iri));
      expect(tokenizer.nextToken().type, equals(TokenType.iri));
      expect(tokenizer.nextToken().type, equals(TokenType.literal));
      expect(tokenizer.nextToken().type, equals(TokenType.comma));
      expect(tokenizer.nextToken().type, equals(TokenType.literal));
      expect(tokenizer.nextToken().type, equals(TokenType.comma));
      expect(tokenizer.nextToken().type, equals(TokenType.literal));
      expect(tokenizer.nextToken().type, equals(TokenType.dot));
      expect(tokenizer.nextToken().type, equals(TokenType.eof));
    });

    test('should handle invalid character sequences correctly', () {
      // These characters are not valid as first characters in Turtle syntax
      // and should cause a FormatException to be thrown
      expect(
        () => TurtleTokenizer('?invalid').nextToken(),
        throwsFormatException,
      );

      expect(
        () => TurtleTokenizer('!invalid').nextToken(),
        throwsFormatException,
      );

      // Invalid tokens with characters not allowed in Turtle syntax
      expect(() => TurtleTokenizer('\$%^&').nextToken(), throwsFormatException);
    });

    test('should process each character in the input correctly', () {
      final tokenizer = TurtleTokenizer('a b c');
      // 'a' should be recognized as the 'a' keyword (rdf:type)
      expect(tokenizer.nextToken().type, equals(TokenType.a));
      // 'b' should be recognized as a prefixed name
      expect(tokenizer.nextToken().type, equals(TokenType.prefixedName));
      // 'c' should be recognized as a prefixed name
      expect(tokenizer.nextToken().type, equals(TokenType.prefixedName));
      // End of input
      expect(tokenizer.nextToken().type, equals(TokenType.eof));
    });

    test('should correctly parse IRIs with escape sequences', () {
      // This test confirms that escape sequences in IRIs are handled
      final tokenizer = TurtleTokenizer('<http://example.org/path\\u00A9>');
      final token = tokenizer.nextToken();
      expect(token.type, equals(TokenType.iri));
      expect(token.value, equals('<http://example.org/path\\u00A9>'));
    });

    group('Multiline string literals', () {
      test('should tokenize triple-quoted multiline string literals', () {
        final tokenizer = TurtleTokenizer('"""Hello\nWorld"""');
        final token = tokenizer.nextToken();
        expect(token.type, equals(TokenType.literal));
        expect(token.value, equals('"""Hello\nWorld"""'));
        expect(tokenizer.nextToken().type, equals(TokenType.eof));
      });

      test('should handle empty triple-quoted string literals', () {
        final tokenizer = TurtleTokenizer('""""""');
        final token = tokenizer.nextToken();
        expect(token.type, equals(TokenType.literal));
        expect(token.value, equals('""""""'));
        expect(tokenizer.nextToken().type, equals(TokenType.eof));
      });

      test(
        'should handle triple-quoted string literals with escaped quotes',
        () {
          final tokenizer = TurtleTokenizer(
            '"""This has \\"quotes\\" inside it"""',
          );
          final token = tokenizer.nextToken();
          expect(token.type, equals(TokenType.literal));
          expect(token.value, equals('"""This has \\"quotes\\" inside it"""'));
          expect(tokenizer.nextToken().type, equals(TokenType.eof));
        },
      );

      test(
        'should handle triple-quoted string literals with embedded double quotes',
        () {
          final tokenizer = TurtleTokenizer('"""This has "embedded" quotes"""');
          final token = tokenizer.nextToken();
          expect(token.type, equals(TokenType.literal));
          expect(token.value, equals('"""This has "embedded" quotes"""'));
          expect(tokenizer.nextToken().type, equals(TokenType.eof));
        },
      );

      test(
        'should handle triple-quoted string literals with multiple lines',
        () {
          final input = '''"""This is a multiline
literal with several
lines of text"""''';
          final tokenizer = TurtleTokenizer(input);
          final token = tokenizer.nextToken();
          expect(token.type, equals(TokenType.literal));
          expect(token.value, equals(input));
          expect(tokenizer.nextToken().type, equals(TokenType.eof));
        },
      );

      test(
        'should throw FormatException for unclosed triple-quoted literal',
        () {
          final tokenizer = TurtleTokenizer('"""unclosed multiline literal');
          expect(() => tokenizer.nextToken(), throwsFormatException);
        },
      );

      test('should handle language tags with triple-quoted literals', () {
        final tokenizer = TurtleTokenizer('"""Hello\nWorld"""@en');
        final token = tokenizer.nextToken();
        expect(token.type, equals(TokenType.literal));
        expect(token.value, equals('"""Hello\nWorld"""@en'));
        expect(tokenizer.nextToken().type, equals(TokenType.eof));
      });

      test(
        'should handle datatype annotations with triple-quoted literals',
        () {
          final tokenizer = TurtleTokenizer(
            '"""Hello\nWorld"""^^<http://www.w3.org/2001/XMLSchema#string>',
          );
          final token = tokenizer.nextToken();
          expect(token.type, equals(TokenType.literal));
          expect(
            token.value,
            equals(
              '"""Hello\nWorld"""^^<http://www.w3.org/2001/XMLSchema#string>',
            ),
          );
          expect(tokenizer.nextToken().type, equals(TokenType.eof));
        },
      );

      test('should handle triple-quoted literals with special characters', () {
        final input = '''"""Special characters: 
* Tab: \t
* Newline: \n
* Carriage return: \r
* Backslash: \\
* Unicode: \u00A9"""''';
        final tokenizer = TurtleTokenizer(input);
        final token = tokenizer.nextToken();
        expect(token.type, equals(TokenType.literal));
        expect(token.value, equals(input));
        expect(tokenizer.nextToken().type, equals(TokenType.eof));
      });

      test(
        'should correctly track line numbers with triple-quoted literals',
        () {
          final input = '''<http://example.org/subject>
"""This is a 
multiline
literal"""
<http://example.org/object> .''';
          final tokenizer = TurtleTokenizer(input);

          final subject = tokenizer.nextToken(); // Subject IRI
          expect(subject.type, equals(TokenType.iri));
          expect(subject.line, equals(1));

          final literal = tokenizer.nextToken(); // Multiline literal
          expect(literal.type, equals(TokenType.literal));
          expect(literal.line, equals(2)); // Line where literal starts

          final object = tokenizer.nextToken(); // Object IRI
          expect(object.type, equals(TokenType.iri));
          expect(object.line, equals(5)); // Line after the multiline literal
        },
      );
    });
  });
}
