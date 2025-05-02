import 'package:test/test.dart';
import 'package:rdf_core/src/exceptions/exceptions.dart';
import 'package:rdf_core/src/graph/rdf_term.dart';
import 'package:rdf_core/src/turtle/turtle_parser.dart';
import 'package:rdf_core/src/turtle/turtle_tokenizer.dart';

void main() {
  group('TurtleParser', () {
    test('should parse prefixes', () {
      final parser = TurtleParser(
        '@prefix solid: <http://www.w3.org/ns/solid/terms#> .',
      );
      final triples = parser.parse();
      expect(triples, isEmpty);
    });

    test('should parse simple triples', () {
      final parser = TurtleParser(
        '<http://example.com/foo> <http://example.com/bar> "baz" .',
      );
      final triples = parser.parse();
      expect(triples.length, equals(1));
      expect(triples[0].subject, equals(IriTerm('http://example.com/foo')));
      expect(triples[0].predicate, equals(IriTerm('http://example.com/bar')));
      expect(triples[0].object, equals(LiteralTerm.string('baz')));
    });

    test('should parse simple triples with escapes', () {
      final parser = TurtleParser(
        '<http://example.com/foo> <http://example.com/bar> "baz\\r\\nis\\"so cool\\" - or is \\\\ more cool? \\t \\b \\f" .',
      );
      final triples = parser.parse();
      expect(triples.length, equals(1));
      expect(triples[0].subject, equals(IriTerm('http://example.com/foo')));
      expect(triples[0].predicate, equals(IriTerm('http://example.com/bar')));
      expect(
        triples[0].object,
        equals(
          LiteralTerm.string(
            'baz\r\nis"so cool" - or is \\ more cool? \t \b \f',
          ),
        ),
      );
    });

    test('should parse simple triples with boolean type', () {
      final parser = TurtleParser(
        '<http://example.com/foo> <http://example.com/bar> "baz"^^<http://www.w3.org/2001/XMLSchema#boolean> .',
      );
      final triples = parser.parse();
      expect(triples.length, equals(1));
      expect(triples[0].subject, equals(IriTerm('http://example.com/foo')));
      expect(triples[0].predicate, equals(IriTerm('http://example.com/bar')));
      expect(triples[0].object, equals(LiteralTerm.typed('baz', 'boolean')));
    });

    test('should parse simple triples with boolean value true', () {
      final parser = TurtleParser(
        '<http://example.com/foo> <http://example.com/bar> true .',
      );
      final triples = parser.parse();
      expect(triples.length, equals(1));
      expect(triples[0].subject, equals(IriTerm('http://example.com/foo')));
      expect(triples[0].predicate, equals(IriTerm('http://example.com/bar')));
      expect(triples[0].object, equals(LiteralTerm.typed('true', 'boolean')));
    });

    test('should parse simple triples with boolean value false', () {
      final parser = TurtleParser(
        '<http://example.com/foo> <http://example.com/bar> false .',
      );
      final triples = parser.parse();
      expect(triples.length, equals(1));
      expect(triples[0].subject, equals(IriTerm('http://example.com/foo')));
      expect(triples[0].predicate, equals(IriTerm('http://example.com/bar')));
      expect(triples[0].object, equals(LiteralTerm.typed('false', 'boolean')));
    });

    test('should parse simple triples with integer literal', () {
      final parser = TurtleParser(
        '<http://example.com/foo> <http://example.com/bar> 42 .',
      );
      final triples = parser.parse();
      expect(triples.length, equals(1));
      expect(triples[0].subject, equals(IriTerm('http://example.com/foo')));
      expect(triples[0].predicate, equals(IriTerm('http://example.com/bar')));
      expect(triples[0].object, equals(LiteralTerm.typed('42', 'integer')));
    });

    test('should parse simple triples with negative integer literal', () {
      final parser = TurtleParser(
        '<http://example.com/foo> <http://example.com/bar> -15 .',
      );
      final triples = parser.parse();
      expect(triples.length, equals(1));
      expect(triples[0].subject, equals(IriTerm('http://example.com/foo')));
      expect(triples[0].predicate, equals(IriTerm('http://example.com/bar')));
      expect(triples[0].object, equals(LiteralTerm.typed('-15', 'integer')));
    });

    test('should parse simple triples with decimal literal', () {
      final parser = TurtleParser(
        '<http://example.com/foo> <http://example.com/bar> 3.14 .',
      );
      final triples = parser.parse();
      expect(triples.length, equals(1));
      expect(triples[0].subject, equals(IriTerm('http://example.com/foo')));
      expect(triples[0].predicate, equals(IriTerm('http://example.com/bar')));
      expect(triples[0].object, equals(LiteralTerm.typed('3.14', 'decimal')));
    });

    test('should parse simple triples with negative decimal literal', () {
      final parser = TurtleParser(
        '<http://example.com/foo> <http://example.com/bar> -2.718 .',
      );
      final triples = parser.parse();
      expect(triples.length, equals(1));
      expect(triples[0].subject, equals(IriTerm('http://example.com/foo')));
      expect(triples[0].predicate, equals(IriTerm('http://example.com/bar')));
      expect(triples[0].object, equals(LiteralTerm.typed('-2.718', 'decimal')));
    });

    test('should parse simple triples with zero-decimal literal', () {
      final parser = TurtleParser(
        '<http://example.com/foo> <http://example.com/bar> 0.0 .',
      );
      final triples = parser.parse();
      expect(triples.length, equals(1));
      expect(triples[0].subject, equals(IriTerm('http://example.com/foo')));
      expect(triples[0].predicate, equals(IriTerm('http://example.com/bar')));
      expect(triples[0].object, equals(LiteralTerm.typed('0.0', 'decimal')));
    });

    test('should parse simple triples with boolean type and prefix', () {
      final parser = TurtleParser(
        '@prefix xsd: <http://www.w3.org/2001/XMLSchema#> .\n'
        '<http://example.com/foo> <http://example.com/bar> "baz"^^xsd:boolean .',
      );
      final triples = parser.parse();
      expect(triples.length, equals(1));
      expect(triples[0].subject, equals(IriTerm('http://example.com/foo')));
      expect(triples[0].predicate, equals(IriTerm('http://example.com/bar')));
      expect(triples[0].object, equals(LiteralTerm.typed('baz', 'boolean')));
    });

    test('should parse simple triples with language tag', () {
      final parser = TurtleParser(
        '<http://example.com/foo> <http://example.com/bar> "baz"@de .',
      );
      final triples = parser.parse();
      expect(triples.length, equals(1));
      expect(triples[0].subject, equals(IriTerm('http://example.com/foo')));
      expect(triples[0].predicate, equals(IriTerm('http://example.com/bar')));
      expect(triples[0].object, equals(LiteralTerm.withLanguage('baz', 'de')));
    });

    test('should parse semicolon-separated triples', () {
      final parser = TurtleParser('''
        <http://example.com/foo> 
          <http://example.com/bar> "baz" ;
          <http://example.com/qux> "quux" .
        ''');
      final triples = parser.parse();
      expect(triples.length, equals(2));
      expect(triples[0].subject, equals(IriTerm('http://example.com/foo')));
      expect(triples[0].predicate, equals(IriTerm('http://example.com/bar')));
      expect(triples[0].object, equals(LiteralTerm.string('baz')));
      expect(triples[1].subject, equals(IriTerm('http://example.com/foo')));
      expect(triples[1].predicate, equals(IriTerm('http://example.com/qux')));
      expect(triples[1].object, equals(LiteralTerm.string('quux')));
    });

    test('should parse blank nodes', () {
      final parser = TurtleParser('[ <http://example.com/bar> "baz" ] .');
      final triples = parser.parse();
      expect(triples.length, equals(1));
      expect(triples[0].subject, isA<BlankNodeTerm>());
      expect(triples[0].predicate, equals(IriTerm('http://example.com/bar')));
      expect(triples[0].object, equals(LiteralTerm.string('baz')));
    });

    test('should parse type declarations', () {
      final parser = TurtleParser(
        '<http://example.com/foo> a <http://example.com/Bar> .',
      );
      final triples = parser.parse();
      expect(triples.length, equals(1));
      expect(triples[0].subject, equals(IriTerm('http://example.com/foo')));
      expect(
        triples[0].predicate,
        equals(IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#type')),
      );
      expect(triples[0].object, equals(IriTerm('http://example.com/Bar')));
    });

    test('should reject using "a" as a subject', () {
      final parser = TurtleParser('a <http://example.com/bar> "baz" .');
      expect(() => parser.parse(), throwsA(isA<RdfSyntaxException>()));
    });

    test('should parse a complete profile', () {
      final parser = TurtleParser('''
        @prefix solid: <http://www.w3.org/ns/solid/terms#> .
        @prefix space: <http://www.w3.org/ns/pim/space#> .
        
        <https://example.com/profile#me>
          a solid:Profile ;
          solid:storage <https://example.com/storage/> ;
          space:storage <https://example.com/storage/> .
        ''');
      final triples = parser.parse();
      expect(triples.length, equals(3));

      // Type declaration
      expect(
        triples[0].subject,
        equals(IriTerm('https://example.com/profile#me')),
      );
      expect(
        triples[0].predicate,
        equals(IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#type')),
      );
      expect(
        triples[0].object,
        equals(IriTerm('http://www.w3.org/ns/solid/terms#Profile')),
      );

      // Storage declarations
      expect(
        triples[1].subject,
        equals(IriTerm('https://example.com/profile#me')),
      );
      expect(
        triples[1].predicate,
        equals(IriTerm('http://www.w3.org/ns/solid/terms#storage')),
      );
      expect(
        triples[1].object,
        equals(IriTerm('https://example.com/storage/')),
      );

      expect(
        triples[2].subject,
        equals(IriTerm('https://example.com/profile#me')),
      );
      expect(
        triples[2].predicate,
        equals(IriTerm('http://www.w3.org/ns/pim/space#storage')),
      );
      expect(
        triples[2].object,
        equals(IriTerm('https://example.com/storage/')),
      );
    });

    test('should parse a simple profile', () {
      final input = '''
        @prefix solid: <http://www.w3.org/ns/solid/terms#> .
        @prefix space: <http://www.w3.org/ns/pim/space#> .
        
        <https://example.com/profile#me>
          a solid:Profile ;
          solid:storage <https://example.com/storage/> ;
          space:storage <https://example.com/storage/> .
      ''';

      final parser = TurtleParser(input);
      final triples = parser.parse();

      expect(triples.length, equals(3));

      // Check type declaration
      expect(
        triples[0].subject,
        equals(IriTerm('https://example.com/profile#me')),
      );
      expect(
        triples[0].predicate,
        equals(IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#type')),
      );
      expect(
        triples[0].object,
        equals(IriTerm('http://www.w3.org/ns/solid/terms#Profile')),
      );

      // Check solid:storage
      expect(
        triples[1].subject,
        equals(IriTerm('https://example.com/profile#me')),
      );
      expect(
        triples[1].predicate,
        equals(IriTerm('http://www.w3.org/ns/solid/terms#storage')),
      );
      expect(
        triples[1].object,
        equals(IriTerm('https://example.com/storage/')),
      );

      // Check space:storage
      expect(
        triples[2].subject,
        equals(IriTerm('https://example.com/profile#me')),
      );
      expect(
        triples[2].predicate,
        equals(IriTerm('http://www.w3.org/ns/pim/space#storage')),
      );
      expect(
        triples[2].object,
        equals(IriTerm('https://example.com/storage/')),
      );
    });

    test('should resolve relative IRIs using the base URI', () {
      final parser = TurtleParser(
        '<foo> <bar> <baz> .',
        baseUri: 'http://example.com/',
      );
      final triples = parser.parse();

      expect(triples.length, equals(1));
      expect(triples[0].subject, equals(IriTerm('http://example.com/foo')));
      expect(triples[0].predicate, equals(IriTerm('http://example.com/bar')));
      expect(triples[0].object, equals(IriTerm('http://example.com/baz')));
    });

    test('should resolve empty relative IRIs using the base URI', () {
      final parser = TurtleParser(
        '@prefix foaf: <http://xmlns.com/foaf/0.1/> .'
        '<https://solidproject.org/TR/wac> foaf:topic <> .',
        baseUri: 'http://my.example.com/',
      );
      final triples = parser.parse();

      expect(triples.length, equals(1));
      expect(
        triples[0].subject,
        equals(IriTerm('https://solidproject.org/TR/wac')),
      );
      expect(
        triples[0].predicate,
        equals(IriTerm('http://xmlns.com/foaf/0.1/topic')),
      );
      expect(triples[0].object, equals(IriTerm('http://my.example.com/')));
    });

    test('should handle prefixed names with empty prefix', () {
      final parser = TurtleParser('''
        @prefix : <http://example.com/default#> .
        :foo :bar :baz .
      ''');
      final triples = parser.parse();

      expect(triples.length, equals(1));
      expect(
        triples[0].subject,
        equals(IriTerm('http://example.com/default#foo')),
      );
      expect(
        triples[0].predicate,
        equals(IriTerm('http://example.com/default#bar')),
      );
      expect(
        triples[0].object,
        equals(IriTerm('http://example.com/default#baz')),
      );
    });

    test('should throw RdfSyntaxException for unknown prefix', () {
      final parser = TurtleParser(
        'unknown:foo <http://example.com/bar> "baz" .',
      );
      expect(() => parser.parse(), throwsA(isA<RdfSyntaxException>()));
    });

    test('should parse objects with multiple commas', () {
      final parser = TurtleParser('''
        @prefix ex: <http://example.com/> .
        ex:subject ex:predicate "obj1", "obj2", "obj3" .
      ''');
      final triples = parser.parse();

      expect(triples.length, equals(3));
      expect(triples[0].subject, equals(IriTerm('http://example.com/subject')));
      expect(
        triples[0].predicate,
        equals(IriTerm('http://example.com/predicate')),
      );
      expect(triples[0].object, equals(LiteralTerm.string('obj1')));

      expect(triples[1].subject, equals(IriTerm('http://example.com/subject')));
      expect(
        triples[1].predicate,
        equals(IriTerm('http://example.com/predicate')),
      );
      expect(triples[1].object, equals(LiteralTerm.string('obj2')));

      expect(triples[2].subject, equals(IriTerm('http://example.com/subject')));
      expect(
        triples[2].predicate,
        equals(IriTerm('http://example.com/predicate')),
      );
      expect(triples[2].object, equals(LiteralTerm.string('obj3')));
    });

    test('should handle Unicode escape sequences in literals', () {
      final parser = TurtleParser(
        '''<http://example.com/foo> <http://example.com/bar> "Copyright \\u00A9 2025" .''',
      );
      final triples = parser.parse();

      expect(triples.length, equals(1));
      expect(triples[0].subject, equals(IriTerm('http://example.com/foo')));
      expect(triples[0].predicate, equals(IriTerm('http://example.com/bar')));
      expect(triples[0].object, equals(LiteralTerm.string('Copyright © 2025')));
    });

    test('should handle long Unicode escape sequences', () {
      final parser = TurtleParser(
        '''<http://example.com/foo> <http://example.com/bar> "Emoji: \\U0001F600" .''',
      );
      final triples = parser.parse();

      expect(triples.length, equals(1));
      expect(triples[0].subject, equals(IriTerm('http://example.com/foo')));
      expect(triples[0].predicate, equals(IriTerm('http://example.com/bar')));
      expect(triples[0].object, equals(LiteralTerm.string('Emoji: 😀')));
    });

    test(
      'should throw RdfSyntaxException for invalid syntax - missing object',
      () {
        final parser = TurtleParser(
          '<http://example.com/foo> <http://example.com/bar> .',
        );
        expect(() => parser.parse(), throwsA(isA<RdfSyntaxException>()));
      },
    );

    test('should parse a complex example with different triple patterns', () {
      final parser = TurtleParser('''
        @prefix foaf: <http://xmlns.com/foaf/0.1/> .
        @prefix schema: <http://schema.org/> .
        @prefix xsd: <http://www.w3.org/2001/XMLSchema#> .
        
        <http://example.org/person/john>
          a foaf:Person ;
          foaf:name "John Smith" ;
          foaf:age "42"^^xsd:integer ;
          foaf:knows [
            a foaf:Person ;
            foaf:name "Jane Doe" ;
            schema:birthDate "1980-01-01"^^xsd:date
          ] ;
          schema:address [
            a schema:PostalAddress ;
            schema:streetAddress "123 Main St" ;
            schema:addressLocality "Anytown" ;
            schema:addressRegion "State" ;
            schema:postalCode "12345"
          ] .
      ''');

      final triples = parser.parse();

      // The result should have triples for:
      // - Main person type
      // - Main person name
      // - Main person age
      // - Main person knows relationship
      // - Known person type
      // - Known person name
      // - Known person birth date
      // - Main person address relationship
      // - Address type
      // - Address street
      // - Address locality
      // - Address region
      // - Address postal code
      expect(triples.length, equals(13));

      // Verify the main person triples
      final johnIri = IriTerm('http://example.org/person/john');
      final johnTriples = triples.where((t) => t.subject == johnIri).toList();
      expect(johnTriples.length, equals(5));

      // Check specific properties
      expect(
        johnTriples.any(
          (t) =>
              t.predicate ==
                  IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#type') &&
              t.object == IriTerm('http://xmlns.com/foaf/0.1/Person'),
        ),
        isTrue,
      );

      expect(
        johnTriples.any(
          (t) =>
              t.predicate == IriTerm('http://xmlns.com/foaf/0.1/name') &&
              t.object == LiteralTerm.string('John Smith'),
        ),
        isTrue,
      );

      // Test for blank node existence without checking specific label
      expect(
        johnTriples.any(
          (t) =>
              t.predicate == IriTerm('http://xmlns.com/foaf/0.1/knows') &&
              (t.object is BlankNodeTerm),
        ),
        isTrue,
      );
      expect(
        johnTriples.any(
          (t) =>
              t.predicate == IriTerm('http://schema.org/address') &&
              (t.object is BlankNodeTerm),
        ),
        isTrue,
      );
    });

    test('should handle comments gracefully', () {
      final parser = TurtleParser('''
        # This is a comment at the beginning
        <http://example.com/foo> # Comment after subject
          <http://example.com/bar> # Comment after predicate
          "baz" . # Comment after object
        # Comment at the end
      ''');

      final triples = parser.parse();
      expect(triples.length, equals(1));
      expect(triples[0].subject, equals(IriTerm('http://example.com/foo')));
      expect(triples[0].predicate, equals(IriTerm('http://example.com/bar')));
      expect(triples[0].object, equals(LiteralTerm.string('baz')));
    });

    test('should handle trailing semicolons correctly', () {
      final parser = TurtleParser('''
        @prefix ex: <http://example.com/> .
        ex:subject 
          ex:predicate1 "object1" ;
          ex:predicate2 "object2" ;
          .
      ''');

      final triples = parser.parse();
      expect(triples.length, equals(2));
    });

    test('should parse empty input', () {
      final parser = TurtleParser('');
      final triples = parser.parse();
      expect(triples, isEmpty);
    });

    test('should parse a simple triple', () {
      final parser = TurtleParser(
        '<http://example.org/subject> <http://example.org/predicate> <http://example.org/object> .',
      );
      final triples = parser.parse();

      expect(triples.length, equals(1));
      expect(
        (triples[0].subject as IriTerm).iri,
        equals('http://example.org/subject'),
      );
      expect(
        (triples[0].predicate as IriTerm).iri,
        equals('http://example.org/predicate'),
      );
      expect(
        (triples[0].object as IriTerm).iri,
        equals('http://example.org/object'),
      );
    });

    test('should resolve relative IRIs against base URI from constructor', () {
      final parser = TurtleParser(
        '<subject> <predicate> <object> .',
        baseUri: 'http://example.org/',
      );
      final triples = parser.parse();

      expect(triples.length, equals(1));
      expect(
        (triples[0].subject as IriTerm).iri,
        equals('http://example.org/subject'),
      );
      expect(
        (triples[0].predicate as IriTerm).iri,
        equals('http://example.org/predicate'),
      );
      expect(
        (triples[0].object as IriTerm).iri,
        equals('http://example.org/object'),
      );
    });

    test('should resolve relative IRIs against @base directive', () {
      final parser = TurtleParser('''
        @base <http://example.org/> .
        <subject> <predicate> <object> .
      ''');
      final triples = parser.parse();

      expect(triples.length, equals(1));
      expect(
        (triples[0].subject as IriTerm).iri,
        equals('http://example.org/subject'),
      );
      expect(
        (triples[0].predicate as IriTerm).iri,
        equals('http://example.org/predicate'),
      );
      expect(
        (triples[0].object as IriTerm).iri,
        equals('http://example.org/object'),
      );
    });

    test('should override base URI from constructor with @base directive', () {
      final parser = TurtleParser('''
        @base <http://example.com/> .
        <subject> <predicate> <object> .
        ''', baseUri: 'http://example.org/');
      final triples = parser.parse();

      expect(triples.length, equals(1));
      expect(
        (triples[0].subject as IriTerm).iri,
        equals('http://example.com/subject'),
      );
      expect(
        (triples[0].predicate as IriTerm).iri,
        equals('http://example.com/predicate'),
      );
      expect(
        (triples[0].object as IriTerm).iri,
        equals('http://example.com/object'),
      );
    });

    test('should allow multiple @base directives with progressive effect', () {
      final parser = TurtleParser('''
        @base <http://example.org/> .
        <subject1> <predicate1> <object1> .
        
        @base <http://example.com/> .
        <subject2> <predicate2> <object2> .
      ''');
      final triples = parser.parse();

      expect(triples.length, equals(2));
      expect(
        (triples[0].subject as IriTerm).iri,
        equals('http://example.org/subject1'),
      );
      expect(
        (triples[0].predicate as IriTerm).iri,
        equals('http://example.org/predicate1'),
      );
      expect(
        (triples[0].object as IriTerm).iri,
        equals('http://example.org/object1'),
      );

      expect(
        (triples[1].subject as IriTerm).iri,
        equals('http://example.com/subject2'),
      );
      expect(
        (triples[1].predicate as IriTerm).iri,
        equals('http://example.com/predicate2'),
      );
      expect(
        (triples[1].object as IriTerm).iri,
        equals('http://example.com/object2'),
      );
    });

    test('should resolve relative IRIs in prefixed names against base URI', () {
      final parser = TurtleParser('''
        @base <http://example.org/base/> .
        @prefix ex: <relative/> .
        
        <subject> a ex:Type .
      ''');
      final triples = parser.parse();

      expect(triples.length, equals(1));
      expect(
        (triples[0].subject as IriTerm).iri,
        equals('http://example.org/base/subject'),
      );
      expect(
        (triples[0].predicate as IriTerm).iri,
        equals('http://www.w3.org/1999/02/22-rdf-syntax-ns#type'),
      );
      expect(
        (triples[0].object as IriTerm).iri,
        equals('http://example.org/base/relative/Type'),
      );
    });

    test('should resolve path-absolute IRIs against base URI', () {
      final parser = TurtleParser('''
        @base <http://example.org/base/path/> .
        </absolute> </predicate> </object> .
      ''');
      final triples = parser.parse();

      expect(triples.length, equals(1));
      expect(
        (triples[0].subject as IriTerm).iri,
        equals('http://example.org/absolute'),
      );
      expect(
        (triples[0].predicate as IriTerm).iri,
        equals('http://example.org/predicate'),
      );
      expect(
        (triples[0].object as IriTerm).iri,
        equals('http://example.org/object'),
      );
    });

    test('should parse a full turtle document with prefixes and base', () {
      final parser = TurtleParser('''
        @base <http://example.org/> .
        @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
        @prefix foaf: <http://xmlns.com/foaf/0.1/> .
        @prefix : <local/> .
        
        <person/alice> a foaf:Person ;
          foaf:name "Alice" ;
          foaf:knows <person/bob> , :charlie .
          
        <person/bob> a foaf:Person ;
          foaf:name "Bob" .
          
        :charlie a foaf:Person ;
          foaf:name "Charlie" .
      ''');

      final triples = parser.parse();

      expect(triples.length, equals(8));

      // Verify alice triples
      final aliceTriples =
          triples
              .where(
                (t) =>
                    t.subject is IriTerm &&
                    (t.subject as IriTerm).iri ==
                        'http://example.org/person/alice',
              )
              .toList();

      expect(aliceTriples.length, equals(4));

      // Check type triple
      expect(
        aliceTriples.any(
          (t) =>
              t.predicate is IriTerm &&
              (t.predicate as IriTerm).iri ==
                  'http://www.w3.org/1999/02/22-rdf-syntax-ns#type' &&
              t.object is IriTerm &&
              (t.object as IriTerm).iri == 'http://xmlns.com/foaf/0.1/Person',
        ),
        isTrue,
      );

      // Check name triple
      expect(
        aliceTriples.any(
          (t) =>
              t.predicate is IriTerm &&
              (t.predicate as IriTerm).iri ==
                  'http://xmlns.com/foaf/0.1/name' &&
              t.object is LiteralTerm &&
              (t.object as LiteralTerm).value == 'Alice',
        ),
        isTrue,
      );

      // Check knows bob triple
      expect(
        aliceTriples.any(
          (t) =>
              t.predicate is IriTerm &&
              (t.predicate as IriTerm).iri ==
                  'http://xmlns.com/foaf/0.1/knows' &&
              t.object is IriTerm &&
              (t.object as IriTerm).iri == 'http://example.org/person/bob',
        ),
        isTrue,
      );

      // Check knows charlie triple
      expect(
        aliceTriples.any(
          (t) =>
              t.predicate is IriTerm &&
              (t.predicate as IriTerm).iri ==
                  'http://xmlns.com/foaf/0.1/knows' &&
              t.object is IriTerm &&
              (t.object as IriTerm).iri == 'http://example.org/local/charlie',
        ),
        isTrue,
      );

      // Verify bob triples
      final bobTriples =
          triples
              .where(
                (t) =>
                    t.subject is IriTerm &&
                    (t.subject as IriTerm).iri ==
                        'http://example.org/person/bob',
              )
              .toList();

      expect(bobTriples.length, equals(2));

      // Check bob's type
      expect(
        bobTriples.any(
          (t) =>
              t.predicate is IriTerm &&
              (t.predicate as IriTerm).iri ==
                  'http://www.w3.org/1999/02/22-rdf-syntax-ns#type' &&
              t.object is IriTerm &&
              (t.object as IriTerm).iri == 'http://xmlns.com/foaf/0.1/Person',
        ),
        isTrue,
      );

      // Check bob's name
      expect(
        bobTriples.any(
          (t) =>
              t.predicate is IriTerm &&
              (t.predicate as IriTerm).iri ==
                  'http://xmlns.com/foaf/0.1/name' &&
              t.object is LiteralTerm &&
              (t.object as LiteralTerm).value == 'Bob',
        ),
        isTrue,
      );

      // Verify charlie triples
      final charlieTriples =
          triples
              .where(
                (t) =>
                    t.subject is IriTerm &&
                    (t.subject as IriTerm).iri ==
                        'http://example.org/local/charlie',
              )
              .toList();

      expect(charlieTriples.length, equals(2));

      // Check charlie's type
      expect(
        charlieTriples.any(
          (t) =>
              t.predicate is IriTerm &&
              (t.predicate as IriTerm).iri ==
                  'http://www.w3.org/1999/02/22-rdf-syntax-ns#type' &&
              t.object is IriTerm &&
              (t.object as IriTerm).iri == 'http://xmlns.com/foaf/0.1/Person',
        ),
        isTrue,
      );

      // Check charlie's name
      expect(
        charlieTriples.any(
          (t) =>
              t.predicate is IriTerm &&
              (t.predicate as IriTerm).iri ==
                  'http://xmlns.com/foaf/0.1/name' &&
              t.object is LiteralTerm &&
              (t.object as LiteralTerm).value == 'Charlie',
        ),
        isTrue,
      );
    });

    test(
      'should throw RdfSyntaxException for invalid syntax - missing period',
      () {
        final parser = TurtleParser(
          '<http://example.com/foo> <http://example.com/bar> "baz"',
        );
        try {
          parser.parse();
          fail('Expected RdfSyntaxException was not thrown');
        } catch (e) {
          expect(e, isA<RdfSyntaxException>());
        }
      },
    );

    test('should maintain BlankNode identity within a parse session', () {
      final parser = TurtleParser('''
        @prefix ex: <http://example.org/> .
        _:b1 ex:name "Node 1" ;
             ex:relatedTo _:b2 .
        _:b2 ex:name "Node 2" ;
             ex:relatedTo _:b1 .
      ''');

      final triples = parser.parse();

      // Find all blank nodes
      final blankNodes = <BlankNodeTerm>{};
      for (final triple in triples) {
        if (triple.subject is BlankNodeTerm) {
          blankNodes.add(triple.subject as BlankNodeTerm);
        }
        if (triple.object is BlankNodeTerm) {
          blankNodes.add(triple.object as BlankNodeTerm);
        }
      }

      // Should be exactly 2 distinct blank nodes
      expect(blankNodes.length, equals(2));

      // Find the node with name "Node 1"
      final node1Triples =
          triples
              .where(
                (t) =>
                    t.predicate == IriTerm('http://example.org/name') &&
                    t.object == LiteralTerm.string("Node 1"),
              )
              .toList();

      expect(node1Triples.length, equals(1));
      final node1 = node1Triples[0].subject as BlankNodeTerm;

      // Find the node with name "Node 2"
      final node2Triples =
          triples
              .where(
                (t) =>
                    t.predicate == IriTerm('http://example.org/name') &&
                    t.object == LiteralTerm.string("Node 2"),
              )
              .toList();

      expect(node2Triples.length, equals(1));
      final node2 = node2Triples[0].subject as BlankNodeTerm;

      // Verify relationships
      final node1RelatedTo =
          triples
                  .firstWhere(
                    (t) =>
                        t.subject == node1 &&
                        t.predicate == IriTerm('http://example.org/relatedTo'),
                  )
                  .object
              as BlankNodeTerm;

      final node2RelatedTo =
          triples
                  .firstWhere(
                    (t) =>
                        t.subject == node2 &&
                        t.predicate == IriTerm('http://example.org/relatedTo'),
                  )
                  .object
              as BlankNodeTerm;

      // Check that relationships are consistent with identity
      expect(node1RelatedTo, equals(node2));
      expect(node2RelatedTo, equals(node1));
    });

    test('should handle empty blank node expressions', () {
      final parser = TurtleParser(
        '[] <http://example.org/predicate> "object" .',
      );
      final triples = parser.parse();

      expect(triples.length, equals(1));
      expect(triples[0].subject is BlankNodeTerm, isTrue);
      expect(
        triples[0].predicate,
        equals(IriTerm('http://example.org/predicate')),
      );
      expect(triples[0].object, equals(LiteralTerm.string('object')));
    });

    test('should handle empty blank node as object', () {
      final parser = TurtleParser(
        '<http://example.org/subject> <http://example.org/predicate> [] .',
      );
      final triples = parser.parse();

      expect(triples.length, equals(1));
      expect(triples[0].subject, equals(IriTerm('http://example.org/subject')));
      expect(
        triples[0].predicate,
        equals(IriTerm('http://example.org/predicate')),
      );
      expect(triples[0].object is BlankNodeTerm, isTrue);
    });

    test('should throw exception for invalid literal format', () {
      final parser = TurtleParser(
        '<http://example.org/subject> <http://example.org/predicate> "invalid literal .',
      );

      expect(() => parser.parse(), throwsA(isA<RdfSyntaxException>()));
    });

    test('should handle incomplete Unicode escape sequences correctly', () {
      final parser = TurtleParser(
        '<http://example.org/subject> <http://example.org/predicate> "Incomplete \\u123 escape" .',
      );

      final triples = parser.parse();
      expect(triples.length, equals(1));
      // The parser should treat incomplete sequences as literal characters
      expect(
        triples[0].object,
        equals(LiteralTerm.string('Incomplete \\u123 escape')),
      );
    });

    test('should handle invalid Unicode escape sequences correctly', () {
      final parser = TurtleParser(
        '<http://example.org/subject> <http://example.org/predicate> "Invalid \\uXYZW escape" .',
      );

      final triples = parser.parse();
      expect(triples.length, equals(1));
      // The parser should treat invalid sequences as literal characters
      expect(
        triples[0].object,
        equals(LiteralTerm.string('Invalid \\uXYZW escape')),
      );
    });

    test('should throw exception for invalid prefixed name format', () {
      final parser = TurtleParser('''
        @prefix ex: <http://example.org/> .
        <http://example.org/subject> <http://example.org/predicate> ex:local:name .
      ''');

      expect(() => parser.parse(), throwsA(isA<RdfSyntaxException>()));
    });

    test('should handle deeply nested blank nodes', () {
      final parser = TurtleParser('''
        @prefix ex: <http://example.org/> .
        ex:subject ex:predicate [
          ex:level1 [
            ex:level2 [
              ex:level3 "Deep value"
            ]
          ]
        ] .
      ''');

      final triples = parser.parse();

      // Should create:
      // 1. subject -> predicate -> bn1
      // 2. bn1 -> level1 -> bn2
      // 3. bn2 -> level2 -> bn3
      // 4. bn3 -> level3 -> "Deep value"
      expect(triples.length, equals(4));

      // Find the first blank node
      final subjectTriples =
          triples
              .where((t) => t.subject == IriTerm('http://example.org/subject'))
              .toList();
      expect(subjectTriples.length, equals(1));

      final bn1 = subjectTriples[0].object as BlankNodeTerm;

      // Find level1 triple
      final level1Triples =
          triples
              .where(
                (t) =>
                    t.subject == bn1 &&
                    t.predicate == IriTerm('http://example.org/level1'),
              )
              .toList();
      expect(level1Triples.length, equals(1));

      final bn2 = level1Triples[0].object as BlankNodeTerm;

      // Find level2 triple
      final level2Triples =
          triples
              .where(
                (t) =>
                    t.subject == bn2 &&
                    t.predicate == IriTerm('http://example.org/level2'),
              )
              .toList();
      expect(level2Triples.length, equals(1));

      final bn3 = level2Triples[0].object as BlankNodeTerm;

      // Find level3 triple
      final level3Triples =
          triples
              .where(
                (t) =>
                    t.subject == bn3 &&
                    t.predicate == IriTerm('http://example.org/level3'),
              )
              .toList();
      expect(level3Triples.length, equals(1));
      expect(level3Triples[0].object, equals(LiteralTerm.string('Deep value')));
    });

    test('should throw exception when expected token is missing', () {
      final parser = TurtleParser('''
        @prefix ex <http://example.org/> . # Missing colon after prefix
      ''');

      expect(() => parser.parse(), throwsA(isA<RdfSyntaxException>()));
    });

    test(
      'should handle complex blank node structure with multiple properties',
      () {
        final parser = TurtleParser('''
        @prefix ex: <http://example.org/> .
        ex:subject ex:predicate [
          ex:prop1 "value1";
          ex:prop2 "value2";
          ex:prop3 [
            ex:nestedProp "nestedValue"
          ];
          ex:prop4 "value4"
        ] .
      ''');

        final triples = parser.parse();

        // Should create:
        // 1. subject -> predicate -> bn1
        // 2. bn1 -> prop1 -> "value1"
        // 3. bn1 -> prop2 -> "value2"
        // 4. bn1 -> prop3 -> bn2
        // 5. bn2 -> nestedProp -> "nestedValue"
        // 6. bn1 -> prop4 -> "value4"
        expect(triples.length, equals(6));

        // Find the main blank node
        final outerBn =
            triples
                    .firstWhere(
                      (t) => t.subject == IriTerm('http://example.org/subject'),
                    )
                    .object
                as BlankNodeTerm;

        // Count properties on the main blank node
        final bnProps = triples.where((t) => t.subject == outerBn).toList();
        expect(bnProps.length, equals(4));

        // Verify prop3 points to another blank node
        final prop3Triple = triples.firstWhere(
          (t) =>
              t.subject == outerBn &&
              t.predicate == IriTerm('http://example.org/prop3'),
        );
        expect(prop3Triple.object is BlankNodeTerm, isTrue);

        // Verify the nested blank node properties
        final nestedBn = prop3Triple.object as BlankNodeTerm;
        final nestedTriple = triples.firstWhere((t) => t.subject == nestedBn);
        expect(
          nestedTriple.predicate,
          equals(IriTerm('http://example.org/nestedProp')),
        );
        expect(nestedTriple.object, equals(LiteralTerm.string('nestedValue')));
      },
    );

    test('should handle all common escape sequences in literals', () {
      final parser = TurtleParser('''
        <http://example.org/subject> <http://example.org/predicate> "\\b\\t\\n\\f\\r\\"\\\\" .
      ''');

      final triples = parser.parse();
      expect(triples.length, equals(1));
      expect(triples[0].object, equals(LiteralTerm.string('\b\t\n\f\r"\\')));
    });

    test('should handle terminating statement with blank node correctly', () {
      final parser = TurtleParser('''
        @prefix ex: <http://example.org/> .
        ex:subject1 ex:predicate1 "value1" .
        ex:subject2 ex:predicate2 [
          ex:nested "value"
        ] .
        ex:subject3 ex:predicate3 "value3" .
      ''');

      final triples = parser.parse();
      expect(triples.length, equals(4));

      // Verify the subjects
      expect(
        triples.any((t) => t.subject == IriTerm('http://example.org/subject1')),
        isTrue,
      );
      expect(
        triples.any((t) => t.subject == IriTerm('http://example.org/subject2')),
        isTrue,
      );
      expect(
        triples.any((t) => t.subject == IriTerm('http://example.org/subject3')),
        isTrue,
      );
    });

    test('should handle non-empty blank node expressions as subject', () {
      final parser = TurtleParser('''
        @prefix ex: <http://example.org/> .
        [ ex:property1 "value1" ; 
          ex:property2 "value2" ] 
          ex:mainPredicate "mainObject" .
      ''');

      final triples = parser.parse();

      // Should have 3 triples:
      // 1. blank_node -> ex:property1 -> "value1"
      // 2. blank_node -> ex:property2 -> "value2"
      // 3. blank_node -> ex:mainPredicate -> "mainObject"
      expect(triples.length, equals(3));

      // Find the blank node used as subject
      BlankNodeTerm? blankNode;
      for (final triple in triples) {
        if (triple.predicate == IriTerm('http://example.org/mainPredicate')) {
          blankNode = triple.subject as BlankNodeTerm;
          expect(triple.object, equals(LiteralTerm.string('mainObject')));
        }
      }

      // Make sure we found the blank node
      expect(blankNode, isNotNull);

      // Verify the blank node has the correct properties
      final blankNodeTriples =
          triples
              .where(
                (t) =>
                    t.subject == blankNode &&
                    t.predicate != IriTerm('http://example.org/mainPredicate'),
              )
              .toList();
      expect(blankNodeTriples.length, equals(2));

      // Check property1
      expect(
        blankNodeTriples.any(
          (t) =>
              t.predicate == IriTerm('http://example.org/property1') &&
              t.object == LiteralTerm.string('value1'),
        ),
        isTrue,
      );

      // Check property2
      expect(
        blankNodeTriples.any(
          (t) =>
              t.predicate == IriTerm('http://example.org/property2') &&
              t.object == LiteralTerm.string('value2'),
        ),
        isTrue,
      );
    });

    group('Multiline string literals', () {
      test('should parse triple-quoted multiline string literals', () {
        final parser = TurtleParser(
          '<http://example.com/foo> <http://example.com/bar> """Hello\nWorld""".',
        );
        final triples = parser.parse();
        expect(triples.length, equals(1));
        expect(triples[0].subject, equals(IriTerm('http://example.com/foo')));
        expect(triples[0].predicate, equals(IriTerm('http://example.com/bar')));
        expect(triples[0].object, equals(LiteralTerm.string('Hello\nWorld')));
      });

      test(
        'should parse triple-quoted string literals with embedded double quotes',
        () {
          final parser = TurtleParser(
            '<http://example.com/foo> <http://example.com/bar> """Contains "quoted" text""".',
          );
          final triples = parser.parse();
          expect(triples.length, equals(1));
          expect(triples[0].subject, equals(IriTerm('http://example.com/foo')));
          expect(
            triples[0].predicate,
            equals(IriTerm('http://example.com/bar')),
          );
          expect(
            triples[0].object,
            equals(LiteralTerm.string('Contains "quoted" text')),
          );
        },
      );

      test('should parse triple-quoted string literals with language tags', () {
        final parser = TurtleParser(
          '<http://example.com/foo> <http://example.com/bar> """Hello\nWorld"""@en.',
        );
        final triples = parser.parse();
        expect(triples.length, equals(1));
        expect(triples[0].subject, equals(IriTerm('http://example.com/foo')));
        expect(triples[0].predicate, equals(IriTerm('http://example.com/bar')));
        expect(
          triples[0].object,
          equals(LiteralTerm.withLanguage('Hello\nWorld', 'en')),
        );
      });

      test('should parse triple-quoted string literals with datatype', () {
        final parser = TurtleParser(
          '<http://example.com/foo> <http://example.com/bar> """Hello\nWorld"""^^<http://www.w3.org/2001/XMLSchema#string>.',
        );
        final triples = parser.parse();
        expect(triples.length, equals(1));
        expect(triples[0].subject, equals(IriTerm('http://example.com/foo')));
        expect(triples[0].predicate, equals(IriTerm('http://example.com/bar')));
        expect(
          triples[0].object,
          equals(LiteralTerm.typed('Hello\nWorld', 'string')),
        );
      });

      test('should parse empty triple-quoted string literals', () {
        final parser = TurtleParser(
          '<http://example.com/foo> <http://example.com/bar> """""".',
        );
        final triples = parser.parse();
        expect(triples.length, equals(1));
        expect(triples[0].subject, equals(IriTerm('http://example.com/foo')));
        expect(triples[0].predicate, equals(IriTerm('http://example.com/bar')));
        expect(triples[0].object, equals(LiteralTerm.string('')));
      });

      test(
        'should parse triple-quoted string literals with Unicode characters',
        () {
          final parser = TurtleParser(
            '<http://example.com/foo> <http://example.com/bar> """Unicode: \\u00A9 and Emoji: \\U0001F600""".',
          );
          final triples = parser.parse();
          expect(triples.length, equals(1));
          expect(triples[0].subject, equals(IriTerm('http://example.com/foo')));
          expect(
            triples[0].predicate,
            equals(IriTerm('http://example.com/bar')),
          );
          expect(
            triples[0].object,
            equals(LiteralTerm.string('Unicode: © and Emoji: 😀')),
          );
        },
      );

      test('should parse complex multiline RDFS comment with formatting', () {
        final parser = TurtleParser('''
          @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
          
          <http://example.org/term> rdfs:comment """This is a multiline
          comment with some *formatting* and
          line breaks that should be preserved.
          
          It even includes a blank line.""" .
        ''');

        final triples = parser.parse();
        expect(triples.length, equals(1));
        expect(triples[0].subject, equals(IriTerm('http://example.org/term')));
        expect(
          triples[0].predicate,
          equals(IriTerm('http://www.w3.org/2000/01/rdf-schema#comment')),
        );

        final expectedComment = '''This is a multiline
          comment with some *formatting* and
          line breaks that should be preserved.
          
          It even includes a blank line.''';
        expect(triples[0].object, equals(LiteralTerm.string(expectedComment)));
      });

      test(
        'should handle triple-quoted string literals within complex structures',
        () {
          final parser = TurtleParser('''
          @prefix ex: <http://example.org/> .
          
          ex:subject ex:predicate [
            ex:title "Simple title" ;
            ex:description """This is a longer
            multiline description with "quotes"
            and multiple lines""" ;
            ex:notes """More notes
            with details"""
          ] .
        ''');

          final triples = parser.parse();
          expect(
            triples.length,
            equals(4),
          ); // subject-predicate-blanknode + 3 properties of blanknode

          // Find the blank node
          final subjectTriple = triples.firstWhere(
            (t) => t.subject == IriTerm('http://example.org/subject'),
          );
          final blankNode = subjectTriple.object as BlankNodeTerm;

          // Find the description triple
          final descriptionTriple = triples.firstWhere(
            (t) =>
                t.subject == blankNode &&
                t.predicate == IriTerm('http://example.org/description'),
          );

          final expectedDescription = '''This is a longer
            multiline description with "quotes"
            and multiple lines''';
          expect(
            descriptionTriple.object,
            equals(LiteralTerm.string(expectedDescription)),
          );

          // Find the notes triple
          final notesTriple = triples.firstWhere(
            (t) =>
                t.subject == blankNode &&
                t.predicate == IriTerm('http://example.org/notes'),
          );

          final expectedNotes = '''More notes
            with details''';
          expect(notesTriple.object, equals(LiteralTerm.string(expectedNotes)));
        },
      );

      test(
        'should parse an RDFS vocabulary definition with multiline comments',
        () {
          final parser = TurtleParser('''
          @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
          @prefix owl: <http://www.w3.org/2002/07/owl#> .
          @prefix xsd: <http://www.w3.org/2001/XMLSchema#> .
          @prefix ex: <http://example.org/vocabulary#> .
          
          ex:Person a rdfs:Class ;
            rdfs:label "Person"@en ;
            rdfs:comment """A person is defined as a human being 
            regarded as an individual with various properties
            and relationships."""@en .
            
          ex:name a owl:DatatypeProperty ;
            rdfs:label "name"@en ;
            rdfs:comment """The name of a person.
            Every person has a name."""@en ;
            rdfs:domain ex:Person ;
            rdfs:range xsd:string .
        ''');

          final triples = parser.parse();

          // Find the rdfs:comment for Person
          final personCommentTriple = triples.firstWhere(
            (t) =>
                t.subject == IriTerm('http://example.org/vocabulary#Person') &&
                t.predicate ==
                    IriTerm('http://www.w3.org/2000/01/rdf-schema#comment'),
          );

          final expectedPersonComment = '''A person is defined as a human being 
            regarded as an individual with various properties
            and relationships.''';

          expect(
            personCommentTriple.object,
            equals(LiteralTerm.withLanguage(expectedPersonComment, 'en')),
          );

          // Find the rdfs:comment for name property
          final nameCommentTriple = triples.firstWhere(
            (t) =>
                t.subject == IriTerm('http://example.org/vocabulary#name') &&
                t.predicate ==
                    IriTerm('http://www.w3.org/2000/01/rdf-schema#comment'),
          );

          final expectedNameComment = '''The name of a person.
            Every person has a name.''';

          expect(
            nameCommentTriple.object,
            equals(LiteralTerm.withLanguage(expectedNameComment, 'en')),
          );
        },
      );
    });

    group('Parsing Flags', () {
      test('should handle identifiers without colon when flag is enabled', () {
        // Setup: Enable the allowIdentifiersWithoutColon flag
        final parserWithFlag = TurtleParser(
          'abc <http://example.org/predicate> "value" .',
          parsingFlags: {TurtleParsingFlag.allowIdentifiersWithoutColon},
          baseUri: 'http://mytest.org/',
        );

        // Execute: Parse the Turtle content
        final triplesWithFlag = parserWithFlag.parse();

        // Verify: The parser with flag should treat 'abc' as a prefixed name
        expect(triplesWithFlag.length, equals(1));
        expect(triplesWithFlag[0].subject, isA<IriTerm>());
        expect(
          triplesWithFlag[0].predicate,
          equals(IriTerm('http://example.org/predicate')),
        );
        expect(
          triplesWithFlag[0].subject,
          equals(IriTerm('http://mytest.org/abc')),
        );
        expect(triplesWithFlag[0].object, equals(LiteralTerm.string('value')));
      });

      test('should handle identifiers without colon when flag is enabled', () {
        // Setup: Enable the allowIdentifiersWithoutColon flag
        final parserWithFlag = TurtleParser(
          'abc <http://example.org/predicate> "value" .',
          parsingFlags: {TurtleParsingFlag.allowIdentifiersWithoutColon},
          // no baseUri specified - this should fail
          // baseUri: 'http://mytest.org/',
        );

        // Execute & Verify: Should throw exception without base URI
        expect(
          () => parserWithFlag.parse(),
          throwsA(isA<RdfSyntaxException>()),
        );
      });
      test(
        'should handle identifiers without colon when flag is enabled, base from turtle overrides baseUri',
        () {
          // Setup: Enable the allowIdentifiersWithoutColon flag
          final parserWithFlag = TurtleParser(
            '@base <http://mytest3.org/base/> .\n'
            'abc <http://example.org/predicate> "value" .',
            parsingFlags: {TurtleParsingFlag.allowIdentifiersWithoutColon},
            baseUri: 'http://mytest.org/',
          );

          // Execute: Parse the Turtle content
          final triplesWithFlag = parserWithFlag.parse();

          // Verify: The parser with flag should treat 'abc' as a prefixed name
          expect(triplesWithFlag.length, equals(1));
          expect(triplesWithFlag[0].subject, isA<IriTerm>());
          expect(
            triplesWithFlag[0].predicate,
            equals(IriTerm('http://example.org/predicate')),
          );
          expect(
            triplesWithFlag[0].subject,
            equals(IriTerm('http://mytest3.org/base/abc')),
          );
          expect(
            triplesWithFlag[0].object,
            equals(LiteralTerm.string('value')),
          );
        },
      );
      test(
        'should handle identifiers without colon when flag is enabled, base from turtle',
        () {
          // Setup: Enable the allowIdentifiersWithoutColon flag
          final parserWithFlag = TurtleParser(
            '@base <http://mytest3.org/base/> .\n'
            'abc <http://example.org/predicate> "value" .',
            parsingFlags: {TurtleParsingFlag.allowIdentifiersWithoutColon},
          );

          // Execute: Parse the Turtle content
          final triplesWithFlag = parserWithFlag.parse();

          // Verify: The parser with flag should treat 'abc' as a prefixed name
          expect(triplesWithFlag.length, equals(1));
          expect(triplesWithFlag[0].subject, isA<IriTerm>());
          expect(
            triplesWithFlag[0].predicate,
            equals(IriTerm('http://example.org/predicate')),
          );
          expect(
            triplesWithFlag[0].subject,
            equals(IriTerm('http://mytest3.org/base/abc')),
          );
          expect(
            triplesWithFlag[0].object,
            equals(LiteralTerm.string('value')),
          );
        },
      );
      test(
        'should reject identifiers without colon when flag is not enabled',
        () {
          // Setup: Parser without the flag
          final parserWithoutFlag = TurtleParser(
            'abc <http://example.org/predicate> "value" .',
          );

          // Execute & Verify: Without the flag, the parse should throw an exception
          expect(
            () => parserWithoutFlag.parse(),
            throwsA(isA<RdfSyntaxException>()),
          );
        },
      );

      test('should handle objects without colon when flag is enabled', () {
        // Setup: Enable the allowIdentifiersWithoutColon flag
        final parserWithFlag = TurtleParser(
          '<http://example.org/subject> <http://example.org/predicate> abc .',
          parsingFlags: {TurtleParsingFlag.allowIdentifiersWithoutColon},
          baseUri: 'http://mytest2.org/',
        );

        // Execute: Parse the Turtle content
        final triplesWithFlag = parserWithFlag.parse();

        // Verify: The parser with flag should treat 'abc' as a prefixed name object
        expect(triplesWithFlag.length, equals(1));
        expect(
          triplesWithFlag[0].subject,
          equals(IriTerm('http://example.org/subject')),
        );
        expect(
          triplesWithFlag[0].predicate,
          equals(IriTerm('http://example.org/predicate')),
        );
        expect(
          triplesWithFlag[0].object,
          equals(IriTerm('http://mytest2.org/abc')),
        );
        expect(triplesWithFlag[0].object, isA<IriTerm>());
      });
      test(
        'should handle objects without colon when flag is enabled, base missing',
        () {
          // Setup: Enable the allowIdentifiersWithoutColon flag
          final parserWithFlag = TurtleParser(
            '<http://example.org/subject> <http://example.org/predicate> abc .',
            parsingFlags: {TurtleParsingFlag.allowIdentifiersWithoutColon},
          );

          // Execute & Verify: Should throw exception without base URI
          expect(
            () => parserWithFlag.parse(),
            throwsA(isA<RdfSyntaxException>()),
          );
        },
      );

      test(
        'should handle objects without colon when flag is enabled, base from turtle',
        () {
          // Setup: Enable the allowIdentifiersWithoutColon flag
          final parserWithFlag = TurtleParser(
            '@base <http://mytest3.org/base/> .\n'
            '<http://example.org/subject> <http://example.org/predicate> abc .',
            parsingFlags: {TurtleParsingFlag.allowIdentifiersWithoutColon},
          );

          // Execute: Parse the Turtle content
          final triplesWithFlag = parserWithFlag.parse();

          // Verify: The parser with flag should treat 'abc' as a prefixed name object
          expect(triplesWithFlag.length, equals(1));
          expect(
            triplesWithFlag[0].subject,
            equals(IriTerm('http://example.org/subject')),
          );
          expect(
            triplesWithFlag[0].predicate,
            equals(IriTerm('http://example.org/predicate')),
          );
          expect(
            triplesWithFlag[0].object,
            equals(IriTerm('http://mytest3.org/base/abc')),
          );
          expect(triplesWithFlag[0].object, isA<IriTerm>());
        },
      );

      test(
        'should handle objects without colon when flag is enabled, base from turtle overrides baseUri',
        () {
          // Setup: Enable the allowIdentifiersWithoutColon flag
          final parserWithFlag = TurtleParser(
            '@base <http://mytest3.org/base/> .\n'
            '<http://example.org/subject> <http://example.org/predicate> abc .',
            parsingFlags: {TurtleParsingFlag.allowIdentifiersWithoutColon},
            baseUri: 'http://mytest2.org/',
          );

          // Execute: Parse the Turtle content
          final triplesWithFlag = parserWithFlag.parse();

          // Verify: The parser with flag should treat 'abc' as a prefixed name object
          expect(triplesWithFlag.length, equals(1));
          expect(
            triplesWithFlag[0].subject,
            equals(IriTerm('http://example.org/subject')),
          );
          expect(
            triplesWithFlag[0].predicate,
            equals(IriTerm('http://example.org/predicate')),
          );
          expect(
            triplesWithFlag[0].object,
            equals(IriTerm('http://mytest3.org/base/abc')),
          );
          expect(triplesWithFlag[0].object, isA<IriTerm>());
        },
      );

      test(
        'should handle multiple identifiers without colon when flag is enabled',
        () {
          // Setup: Enable the allowIdentifiersWithoutColon flag
          final parserWithFlag = TurtleParser(
            '''
          abc def ghi .
          xyz abc "test" .
        ''',
            parsingFlags: {TurtleParsingFlag.allowIdentifiersWithoutColon},
            baseUri: "http://example.com/",
          );

          // Execute: Parse the Turtle content
          final triplesWithFlag = parserWithFlag.parse();

          // Verify: The parser with flag should process both triples with identifiers without colons
          expect(triplesWithFlag.length, equals(2));
        },
      );

      test('should handle allowDigitInLocalName flag', () {
        // Setup: Enable the allowDigitInLocalName flag
        final parserWithFlag = TurtleParser(
          '''
          @prefix mytest: <https://mytest.org/> .
          <http://example.org/product> a mytest:3DModel .
        ''',
          parsingFlags: {TurtleParsingFlag.allowDigitInLocalName},
        );

        // Execute: Parse the Turtle content
        final triplesWithFlag = parserWithFlag.parse();

        // Verify: The parser with flag should allow digits at start of local name
        expect(triplesWithFlag.length, equals(1));
        expect(
          triplesWithFlag[0].subject,
          equals(IriTerm('http://example.org/product')),
        );
        expect(
          triplesWithFlag[0].predicate,
          equals(IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#type')),
        );
        expect(
          triplesWithFlag[0].object,
          equals(IriTerm('https://mytest.org/3DModel')),
        );
      });

      test(
        'should reject digits at start of local name when flag is not enabled',
        () {
          // Setup: Parser without the flag
          final parserWithoutFlag = TurtleParser('''
          @prefix schema: <https://schema.org/> .
          <http://example.org/product> a schema:3DModel .
        ''');

          // Execute & Verify: Without the flag, the parse should throw an exception
          expect(
            () => parserWithoutFlag.parse(),
            throwsA(isA<RdfSyntaxException>()),
          );
        },
      );

      test('should handle allowMissingDotAfterPrefix flag', () {
        // Setup: Enable the allowMissingDotAfterPrefix flag
        final parserWithFlag = TurtleParser(
          '''
          @prefix ex: <http://example.org/> 
          ex:subject ex:predicate "value" .
        ''',
          parsingFlags: {TurtleParsingFlag.allowMissingDotAfterPrefix},
        );

        // Execute: Parse the Turtle content
        final triplesWithFlag = parserWithFlag.parse();

        // Verify: The parser with flag should process the triple despite missing dot after prefix
        expect(triplesWithFlag.length, equals(1));
        expect(
          triplesWithFlag[0].subject,
          equals(IriTerm('http://example.org/subject')),
        );
        expect(
          triplesWithFlag[0].predicate,
          equals(IriTerm('http://example.org/predicate')),
        );
        expect(triplesWithFlag[0].object, equals(LiteralTerm.string('value')));
      });

      test('should reject missing dot after prefix when flag is not enabled', () {
        // Setup: Parser without the flag
        final parserWithoutFlag = TurtleParser('''
          @prefix ex: <http://example.org/> 
          ex:subject ex:predicate "value" .
        ''');

        // Execute & Verify: Without the flag, the parse should throw an exception
        expect(
          () => parserWithoutFlag.parse(),
          throwsA(isA<RdfSyntaxException>()),
        );
      });

      test('should handle autoAddCommonPrefixes flag', () {
        // Setup: Enable the autoAddCommonPrefixes flag
        final parserWithFlag = TurtleParser(
          '<http://example.org/subject> a rdf:List .',
          parsingFlags: {TurtleParsingFlag.autoAddCommonPrefixes},
        );

        // Execute: Parse the Turtle content
        final triplesWithFlag = parserWithFlag.parse();

        // Verify: The parser with flag should automatically add the rdf prefix
        expect(triplesWithFlag.length, equals(1));
        expect(
          triplesWithFlag[0].subject,
          equals(IriTerm('http://example.org/subject')),
        );
        expect(
          triplesWithFlag[0].predicate,
          equals(IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#type')),
        );
        expect(
          triplesWithFlag[0].object,
          equals(IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#List')),
        );
      });

      test(
        'should reject undefined prefixes when autoAddCommonPrefixes is not enabled',
        () {
          // Setup: Parser without the flag
          final parserWithoutFlag = TurtleParser(
            '<http://example.org/subject> a rdf:List .',
          );

          // Execute & Verify: Without the flag, the parse should throw an exception
          expect(
            () => parserWithoutFlag.parse(),
            throwsA(isA<RdfSyntaxException>()),
          );
        },
      );

      test('should handle allowPrefixWithoutAtSign flag', () {
        // Setup: Enable the allowPrefixWithoutAtSign flag
        final parserWithFlag = TurtleParser(
          '''
          prefix ex: <http://example.org/> .
          ex:subject ex:predicate "value" .
        ''',
          parsingFlags: {TurtleParsingFlag.allowPrefixWithoutAtSign},
        );

        // Execute: Parse the Turtle content
        final triplesWithFlag = parserWithFlag.parse();

        // Verify: The parser with flag should process the prefix without @ sign
        expect(triplesWithFlag.length, equals(1));
        expect(
          triplesWithFlag[0].subject,
          equals(IriTerm('http://example.org/subject')),
        );
        expect(
          triplesWithFlag[0].predicate,
          equals(IriTerm('http://example.org/predicate')),
        );
        expect(triplesWithFlag[0].object, equals(LiteralTerm.string('value')));
      });

      test('should reject prefix without @ sign when flag is not enabled', () {
        // Setup: Parser without the flag
        final parserWithoutFlag = TurtleParser('''
          prefix ex: <http://example.org/> .
          ex:subject ex:predicate "value" .
        ''');

        // Execute & Verify: Without the flag, the parse should throw an exception
        expect(
          () => parserWithoutFlag.parse(),
          throwsA(isA<RdfSyntaxException>()),
        );
      });

      test('should handle allowMissingFinalDot flag', () {
        // Setup: Enable the allowMissingFinalDot flag
        final parserWithFlag = TurtleParser(
          '<http://example.org/subject> <http://example.org/predicate> "value"',
          parsingFlags: {TurtleParsingFlag.allowMissingFinalDot},
        );

        // Execute: Parse the Turtle content
        final triplesWithFlag = parserWithFlag.parse();

        // Verify: The parser with flag should process the triple despite missing final dot
        expect(triplesWithFlag.length, equals(1));
        expect(
          triplesWithFlag[0].subject,
          equals(IriTerm('http://example.org/subject')),
        );
        expect(
          triplesWithFlag[0].predicate,
          equals(IriTerm('http://example.org/predicate')),
        );
        expect(triplesWithFlag[0].object, equals(LiteralTerm.string('value')));
      });

      test('should reject missing final dot when flag is not enabled', () {
        // Setup: Parser without the flag
        final parserWithoutFlag = TurtleParser(
          '<http://example.org/subject> <http://example.org/predicate> "value"',
        );

        // Execute & Verify: Without the flag, the parse should throw an exception
        expect(
          () => parserWithoutFlag.parse(),
          throwsA(isA<RdfSyntaxException>()),
        );
      });

      test('should reject malformed collections when flag is not enabled', () {
        // Setup: Parser without the flag
        final parserWithoutFlag = TurtleParser(
          '<http://example.org/subject> <http://example.org/predicate> ( "item1" "item2" .',
        );

        // Execute & Verify: Without the flag, the parse should throw an exception
        expect(
          () => parserWithoutFlag.parse(),
          throwsA(isA<RdfSyntaxException>()),
        );
      });

      test('should handle multiple flags together', () {
        // Setup: Enable multiple flags
        final parserWithMultipleFlags = TurtleParser(
          '''
          prefix ex: <http://example.org/> .
          abc def ghi .
          <http://example.org/subject> ex:predicate schema:3DModel .
        ''',
          baseUri: 'http://mytest.org/',
          parsingFlags: {
            TurtleParsingFlag.allowIdentifiersWithoutColon,
            TurtleParsingFlag.allowPrefixWithoutAtSign,
            TurtleParsingFlag.allowMissingFinalDot,
            TurtleParsingFlag.allowDigitInLocalName,
            TurtleParsingFlag.autoAddCommonPrefixes,
          },
        );

        // Execute: Parse the Turtle content
        final triples = parserWithMultipleFlags.parse();

        // Verify: The parser should handle all relaxed syntax features
        expect(triples.length, equals(2));
      });
    });

    group('RDF Collections', () {
      test('should parse an empty collection', () {
        final parser = TurtleParser(
          '<http://example.org/subject> <http://example.org/predicate> () .',
        );
        final triples = parser.parse();

        expect(triples.length, equals(1));
        expect(
          triples[0].subject,
          equals(IriTerm('http://example.org/subject')),
        );
        expect(
          triples[0].predicate,
          equals(IriTerm('http://example.org/predicate')),
        );
        expect(
          triples[0].object,
          equals(IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#nil')),
        );
      });

      test('should parse a simple collection with string literals', () {
        final parser = TurtleParser(
          '<http://example.org/subject> <http://example.org/predicate> ("item1" "item2" "item3") .',
        );
        final triples = parser.parse();

        // Should generate:
        // 1. subject predicate list1
        // 2. list1 rdf:first "item1"
        // 3. list1 rdf:rest list2
        // 4. list2 rdf:first "item2"
        // 5. list2 rdf:rest list3
        // 6. list3 rdf:first "item3"
        // 7. list3 rdf:rest rdf:nil
        expect(triples.length, equals(7));

        // Check the main triple pointing to the collection head
        final mainTriple = triples.firstWhere(
          (t) => t.subject == IriTerm('http://example.org/subject'),
        );
        expect(
          mainTriple.predicate,
          equals(IriTerm('http://example.org/predicate')),
        );
        expect(mainTriple.object, isA<BlankNodeTerm>());

        // Get the head of the list
        final listHead = mainTriple.object as BlankNodeTerm;

        // Check first item
        final firstItemTriple = triples.firstWhere(
          (t) =>
              t.subject == listHead &&
              t.predicate ==
                  IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#first'),
        );
        expect(firstItemTriple.object, equals(LiteralTerm.string('item1')));

        // Find the rest link from the first item
        final firstRestTriple = triples.firstWhere(
          (t) =>
              t.subject == listHead &&
              t.predicate ==
                  IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#rest'),
        );
        expect(firstRestTriple.object, isA<BlankNodeTerm>());

        // Find the second item
        final secondNode = firstRestTriple.object as BlankNodeTerm;
        final secondItemTriple = triples.firstWhere(
          (t) =>
              t.subject == secondNode &&
              t.predicate ==
                  IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#first'),
        );
        expect(secondItemTriple.object, equals(LiteralTerm.string('item2')));

        // Find the rest link from the second item
        final secondRestTriple = triples.firstWhere(
          (t) =>
              t.subject == secondNode &&
              t.predicate ==
                  IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#rest'),
        );
        expect(secondRestTriple.object, isA<BlankNodeTerm>());

        // Find the third item
        final thirdNode = secondRestTriple.object as BlankNodeTerm;
        final thirdItemTriple = triples.firstWhere(
          (t) =>
              t.subject == thirdNode &&
              t.predicate ==
                  IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#first'),
        );
        expect(thirdItemTriple.object, equals(LiteralTerm.string('item3')));

        // Find the rest link from the third item (should be rdf:nil)
        final thirdRestTriple = triples.firstWhere(
          (t) =>
              t.subject == thirdNode &&
              t.predicate ==
                  IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#rest'),
        );
        expect(
          thirdRestTriple.object,
          equals(IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#nil')),
        );
      });

      test('should parse a collection with mixed content types', () {
        final parser = TurtleParser('''
          @prefix ex: <http://example.org/> .
          @prefix xsd: <http://www.w3.org/2001/XMLSchema#> .
          ex:subject ex:predicate (
            "a string"
            123
            <http://example.org/resource>
            true
            "2023-05-01"^^xsd:date
          ) .
        ''');
        final triples = parser.parse();

        // Should be 11 triples: 1 for the main triple + (2 * 5) for the list structure
        expect(triples.length, equals(11));

        // Find all first triples to check the list items
        final firstTriples =
            triples
                .where(
                  (t) =>
                      t.predicate ==
                      IriTerm(
                        'http://www.w3.org/1999/02/22-rdf-syntax-ns#first',
                      ),
                )
                .toList();
        expect(firstTriples.length, equals(5));

        // Check each list item's type
        expect(firstTriples[0].object, equals(LiteralTerm.string('a string')));
        expect(
          firstTriples[1].object,
          equals(LiteralTerm.typed('123', 'integer')),
        );
        expect(
          firstTriples[2].object,
          equals(IriTerm('http://example.org/resource')),
        );
        expect(
          firstTriples[3].object,
          equals(LiteralTerm.typed('true', 'boolean')),
        );
        expect(
          firstTriples[4].object,
          equals(LiteralTerm.typed('2023-05-01', 'date')),
        );
      });

      test('should parse nested collections', () {
        final parser = TurtleParser('''
          @prefix ex: <http://example.org/> .
          ex:subject ex:predicate (
            "outer1"
            ("inner1" "inner2")
            "outer2"
          ) .
        ''');
        final triples = parser.parse();

        // Should be 13 triples:
        // 1 for main triple
        // 6 for the outer list (3 items * 2 triples per item)
        // 6 for the inner list (2 items * 2 triples per item )
        expect(triples.length, equals(11));

        // Find the main triple
        final mainTriple = triples.firstWhere(
          (t) => t.subject == IriTerm('http://example.org/subject'),
        );
        final outerListHead = mainTriple.object as BlankNodeTerm;

        // Find the first item in the outer list
        final firstOuterTriple = triples.firstWhere(
          (t) =>
              t.subject == outerListHead &&
              t.predicate ==
                  IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#first'),
        );
        expect(firstOuterTriple.object, equals(LiteralTerm.string('outer1')));

        // Find the rest node of the outer list
        final firstRestTriple = triples.firstWhere(
          (t) =>
              t.subject == outerListHead &&
              t.predicate ==
                  IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#rest'),
        );
        final secondOuterNode = firstRestTriple.object as BlankNodeTerm;

        // Find the second item (the nested list)
        final secondOuterTriple = triples.firstWhere(
          (t) =>
              t.subject == secondOuterNode &&
              t.predicate ==
                  IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#first'),
        );

        // The second item should be a blank node (head of inner list)
        expect(secondOuterTriple.object, isA<BlankNodeTerm>());
        final innerListHead = secondOuterTriple.object as BlankNodeTerm;

        // Find the first inner list item
        final firstInnerTriple = triples.firstWhere(
          (t) =>
              t.subject == innerListHead &&
              t.predicate ==
                  IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#first'),
        );
        expect(firstInnerTriple.object, equals(LiteralTerm.string('inner1')));

        // Find the second inner list item
        final innerRestTriple = triples.firstWhere(
          (t) =>
              t.subject == innerListHead &&
              t.predicate ==
                  IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#rest'),
        );
        final secondInnerNode = innerRestTriple.object as BlankNodeTerm;

        final secondInnerTriple = triples.firstWhere(
          (t) =>
              t.subject == secondInnerNode &&
              t.predicate ==
                  IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#first'),
        );
        expect(secondInnerTriple.object, equals(LiteralTerm.string('inner2')));

        // Check that the inner list ends with rdf:nil
        final innerEndTriple = triples.firstWhere(
          (t) =>
              t.subject == secondInnerNode &&
              t.predicate ==
                  IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#rest'),
        );
        expect(
          innerEndTriple.object,
          equals(IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#nil')),
        );
      });

      test('should parse collection with blank node elements', () {
        final parser = TurtleParser('''
          @prefix ex: <http://example.org/> .
          ex:subject ex:predicate (
            [ ex:name "Named item" ]
            []
          ) .
        ''');
        final triples = parser.parse();

        // Should have triples for:
        // 1. subject predicate listHead
        // 2. listHead rdf:first blankNode1
        // 3. blankNode1 ex:name "Named item"
        // 4. listHead rdf:rest listNode2
        // 5. listNode2 rdf:first blankNode2
        // 6. listNode2 rdf:rest rdf:nil
        expect(triples.length, equals(6));

        // Find main triple
        final mainTriple = triples.firstWhere(
          (t) => t.subject == IriTerm('http://example.org/subject'),
        );
        final listHead = mainTriple.object as BlankNodeTerm;

        // Find first item (a blank node with ex:name property)
        final firstItemTriple = triples.firstWhere(
          (t) =>
              t.subject == listHead &&
              t.predicate ==
                  IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#first'),
        );
        final firstBlankNode = firstItemTriple.object as BlankNodeTerm;

        // Check that this blank node has the ex:name property
        final nameTriple = triples.firstWhere(
          (t) =>
              t.subject == firstBlankNode &&
              t.predicate == IriTerm('http://example.org/name'),
        );
        expect(nameTriple.object, equals(LiteralTerm.string('Named item')));

        // Find second item (an empty blank node)
        final restTriple = triples.firstWhere(
          (t) =>
              t.subject == listHead &&
              t.predicate ==
                  IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#rest'),
        );
        final secondListNode = restTriple.object as BlankNodeTerm;

        final secondItemTriple = triples.firstWhere(
          (t) =>
              t.subject == secondListNode &&
              t.predicate ==
                  IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#first'),
        );
        expect(secondItemTriple.object, isA<BlankNodeTerm>());
      });

      test('should handle collections in complex graph structures', () {
        final parser = TurtleParser('''
          @prefix ex: <http://example.org/> .
          @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
          
          ex:subject ex:property [
            ex:items ("item1" "item2");
            ex:name "A collection container"
          ] .
        ''');
        final triples = parser.parse();

        // Find the blank node that holds the collection
        final mainTriple = triples.firstWhere(
          (t) => t.subject == IriTerm('http://example.org/subject'),
        );
        final containerNode = mainTriple.object as BlankNodeTerm;

        // Find the triple connecting the container to the collection
        final collectionTriple = triples.firstWhere(
          (t) =>
              t.subject == containerNode &&
              t.predicate == IriTerm('http://example.org/items'),
        );

        // Get the collection head
        final collectionHead = collectionTriple.object as BlankNodeTerm;

        // Verify the first item in the collection
        final firstItemTriple = triples.firstWhere(
          (t) =>
              t.subject == collectionHead &&
              t.predicate ==
                  IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#first'),
        );
        expect(firstItemTriple.object, equals(LiteralTerm.string('item1')));

        // Also check the name property of the container
        final nameTriple = triples.firstWhere(
          (t) =>
              t.subject == containerNode &&
              t.predicate == IriTerm('http://example.org/name'),
        );
        expect(
          nameTriple.object,
          equals(LiteralTerm.string('A collection container')),
        );
      });
    });
  });
}
