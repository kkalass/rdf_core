// Tests for the N-Triples decoder implementation

import 'package:rdf_core/rdf_core.dart';
import 'package:test/test.dart';

void main() {
  group('NTriplesDecoder', () {
    late RdfCore rdf;

    setUp(() {
      rdf = RdfCore.withStandardCodecs();
    });

    test('decodes empty document', () {
      final input = '';
      final graph = rdf.decode(input, contentType: 'application/n-triples');
      expect(graph.isEmpty, isTrue);
    });

    test('decodes document with comments and empty lines', () {
      final input = '''
# This is a comment
  # This is an indented comment

<http://example.org/subject> <http://example.org/predicate> <http://example.org/object> .

# Another comment
''';
      final graph = rdf.decode(input, contentType: 'application/n-triples');
      expect(graph.triples.length, equals(1));
      final triple = graph.triples.first;
      expect(
        (triple.subject as IriTerm).iri,
        equals('http://example.org/subject'),
      );
      expect(
        (triple.predicate as IriTerm).iri,
        equals('http://example.org/predicate'),
      );
      expect(
        (triple.object as IriTerm).iri,
        equals('http://example.org/object'),
      );
    });

    test('decodes multiple triples', () {
      final input = '''
<http://example.org/subject1> <http://example.org/predicate1> <http://example.org/object1> .
<http://example.org/subject2> <http://example.org/predicate2> <http://example.org/object2> .
<http://example.org/subject3> <http://example.org/predicate3> <http://example.org/object3> .
''';
      final graph = rdf.decode(input, contentType: 'application/n-triples');
      expect(graph.triples.length, equals(3));
    });

    test('decodes blank nodes', () {
      final input = '''
_:b1 <http://example.org/predicate> <http://example.org/object> .
<http://example.org/subject> <http://example.org/predicate> _:b2 .
''';
      final graph = rdf.decode(input, contentType: 'application/n-triples');
      expect(graph.triples.length, equals(2));

      // Check that blank nodes are decoded correctly
      final triple1 = graph.triples.elementAt(0);
      final triple2 = graph.triples.elementAt(1);

      expect(triple1.subject, isA<BlankNodeTerm>());
      expect(triple2.object, isA<BlankNodeTerm>());
    });

    test('decodes literals with language tags', () {
      final input = '''
<http://example.org/subject> <http://example.org/predicate> "Plain literal" .
<http://example.org/subject> <http://example.org/predicate> "English"@en .
<http://example.org/subject> <http://example.org/predicate> "Deutsch"@de .
''';
      final graph = rdf.decode(input, contentType: 'application/n-triples');
      expect(graph.triples.length, equals(3));

      final triple1 = graph.triples.elementAt(0);
      final triple2 = graph.triples.elementAt(1);
      final triple3 = graph.triples.elementAt(2);

      expect(triple1.object, isA<LiteralTerm>());
      expect((triple1.object as LiteralTerm).value, equals('Plain literal'));
      expect((triple1.object as LiteralTerm).language, isNull);

      expect(triple2.object, isA<LiteralTerm>());
      expect((triple2.object as LiteralTerm).value, equals('English'));
      expect((triple2.object as LiteralTerm).language, equals('en'));

      expect(triple3.object, isA<LiteralTerm>());
      expect((triple3.object as LiteralTerm).value, equals('Deutsch'));
      expect((triple3.object as LiteralTerm).language, equals('de'));
    });

    test('decodes literals with datatypes', () {
      final input = '''
<http://example.org/subject> <http://example.org/predicate> "42"^^<http://www.w3.org/2001/XMLSchema#integer> .
<http://example.org/subject> <http://example.org/predicate> "true"^^<http://www.w3.org/2001/XMLSchema#boolean> .
''';
      final graph = rdf.decode(input, contentType: 'application/n-triples');
      expect(graph.triples.length, equals(2));

      final triple1 = graph.triples.elementAt(0);
      final triple2 = graph.triples.elementAt(1);

      expect(triple1.object, isA<LiteralTerm>());
      expect((triple1.object as LiteralTerm).value, equals('42'));
      expect(
        (triple1.object as LiteralTerm).datatype.iri,
        equals('http://www.w3.org/2001/XMLSchema#integer'),
      );

      expect(triple2.object, isA<LiteralTerm>());
      expect((triple2.object as LiteralTerm).value, equals('true'));
      expect(
        (triple2.object as LiteralTerm).datatype.iri,
        equals('http://www.w3.org/2001/XMLSchema#boolean'),
      );
    });

    test('decodes escaped characters in literals', () {
      final input = '''
<http://example.org/subject> <http://example.org/predicate> "Line 1\\nLine 2" .
<http://example.org/subject> <http://example.org/predicate> "Tab\\tCharacter" .
<http://example.org/subject> <http://example.org/predicate> "Quote \\"inside\\" string" .
''';
      final graph = rdf.decode(input, contentType: 'application/n-triples');
      expect(graph.triples.length, equals(3));

      final triple1 = graph.triples.elementAt(0);
      final triple2 = graph.triples.elementAt(1);
      final triple3 = graph.triples.elementAt(2);

      expect(triple1.object, isA<LiteralTerm>());
      expect((triple1.object as LiteralTerm).value, equals('Line 1\nLine 2'));

      expect(triple2.object, isA<LiteralTerm>());
      expect((triple2.object as LiteralTerm).value, equals('Tab\tCharacter'));

      expect(triple3.object, isA<LiteralTerm>());
      expect(
        (triple3.object as LiteralTerm).value,
        equals('Quote "inside" string'),
      );
    });

    test('throws error on invalid triples', () {
      // Missing period
      expect(
        () => rdf.decode(
          '<http://example.org/subject> <http://example.org/predicate> <http://example.org/object>',
          contentType: 'application/n-triples',
        ),
        throwsA(isA<RdfDecoderException>()),
      );

      // Invalid subject (string literal not allowed)
      expect(
        () => rdf.decode(
          '"subject" <http://example.org/predicate> <http://example.org/object> .',
          contentType: 'application/n-triples',
        ),
        throwsA(isA<RdfDecoderException>()),
      );

      // Invalid predicate (blank node not allowed)
      expect(
        () => rdf.decode(
          '<http://example.org/subject> _:predicate <http://example.org/object> .',
          contentType: 'application/n-triples',
        ),
        throwsA(isA<RdfDecoderException>()),
      );
    });

    test('auto-detects N-Triples format', () {
      final input = '''
<http://example.org/subject> <http://example.org/predicate> <http://example.org/object> .
<http://example.org/subject> <http://example.org/predicate> "Literal value" .
''';

      // Decode without specifying content type
      final graph = rdf.decode(input);
      expect(graph.triples.length, equals(2));
    });
  });
}
