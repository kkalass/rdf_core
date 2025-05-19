// Tests for the N-Triples endoder implementation

import 'package:rdf_core/rdf_core.dart';
import 'package:test/test.dart';

void main() {
  group('NTriplesEndoder', () {
    late RdfCore rdf;

    setUp(() {
      rdf = RdfCore.withStandardCodecs();
    });

    test('endodes empty graph', () {
      final graph = RdfGraph();
      final ntriples = rdf.encode(graph, contentType: 'application/n-triples');
      expect(ntriples.trim(), isEmpty);
    });

    test('endodes simple IRI triple', () {
      final subject = IriTerm('http://example.org/subject');
      final predicate = IriTerm('http://example.org/predicate');
      final object = IriTerm('http://example.org/object');
      final triple = Triple(subject, predicate, object);
      final graph = RdfGraph.fromTriples([triple]);

      final ntriples = rdf.encode(graph, contentType: 'application/n-triples');
      expect(ntriples, contains('<http://example.org/subject>'));
      expect(ntriples, contains('<http://example.org/predicate>'));
      expect(ntriples, contains('<http://example.org/object>'));
      expect(ntriples, contains('.'));
    });

    test('endodes triple with blank nodes', () {
      final subject = BlankNodeTerm();
      final predicate = IriTerm('http://example.org/predicate');
      final object = BlankNodeTerm();
      final triple = Triple(subject, predicate, object);
      final graph = RdfGraph.fromTriples([triple]);

      final ntriples = rdf.encode(graph, contentType: 'application/n-triples');
      expect(
        ntriples,
        matches(r'_:b\d+ <http://example\.org/predicate> _:b\d+ \.\n'),
      );
    });

    test('endodes triple with simple literal', () {
      final subject = IriTerm('http://example.org/subject');
      final predicate = IriTerm('http://example.org/predicate');
      final object = LiteralTerm.string('Simple literal');
      final triple = Triple(subject, predicate, object);
      final graph = RdfGraph.fromTriples([triple]);

      final ntriples = rdf.encode(graph, contentType: 'application/n-triples');
      expect(
        ntriples,
        contains(
          '<http://example.org/subject> <http://example.org/predicate> "Simple literal" .',
        ),
      );
    });

    test('endodes triple with language-tagged literal', () {
      final subject = IriTerm('http://example.org/subject');
      final predicate = IriTerm('http://example.org/predicate');
      final object = LiteralTerm.withLanguage('English text', 'en');
      final triple = Triple(subject, predicate, object);
      final graph = RdfGraph.fromTriples([triple]);

      final ntriples = rdf.encode(graph, contentType: 'application/n-triples');
      expect(
        ntriples,
        contains(
          '<http://example.org/subject> <http://example.org/predicate> "English text"@en .',
        ),
      );
    });

    test('endodes triple with datatyped literal', () {
      final subject = IriTerm('http://example.org/subject');
      final predicate = IriTerm('http://example.org/predicate');
      // Create a typed literal using the correct term constructor
      final object = LiteralTerm(
        '42',
        datatype: IriTerm('http://www.w3.org/2001/XMLSchema#integer'),
      );
      final triple = Triple(subject, predicate, object);
      final graph = RdfGraph.fromTriples([triple]);

      final ntriples = rdf.encode(graph, contentType: 'application/n-triples');
      expect(
        ntriples,
        contains(
          '<http://example.org/subject> <http://example.org/predicate> "42"^^<http://www.w3.org/2001/XMLSchema#integer> .',
        ),
      );
    });

    test('escapes special characters in literals', () {
      final subject = IriTerm('http://example.org/subject');
      final predicate = IriTerm('http://example.org/predicate');

      // Test newlines, tabs, quotes, etc.
      final object = LiteralTerm.string(
        'Line 1\nLine 2\tTabbed\r\nWindows"Quote"',
      );
      final triple = Triple(subject, predicate, object);
      final graph = RdfGraph.fromTriples([triple]);

      final ntriples = rdf.encode(graph, contentType: 'application/n-triples');
      expect(
        ntriples,
        contains(
          '<http://example.org/subject> <http://example.org/predicate> "Line 1\\nLine 2\\tTabbed\\r\\nWindows\\"Quote\\"" .',
        ),
      );
    });

    test('escapes special characters in IRIs', () {
      // IRIs with characters that need escaping
      final subject = IriTerm('http://example.org/subject');
      final predicate = IriTerm('http://example.org/predicate');
      final object = IriTerm('http://example.org/path>with<special>chars');
      final triple = Triple(subject, predicate, object);
      final graph = RdfGraph.fromTriples([triple]);

      final ntriples = rdf.encode(graph, contentType: 'application/n-triples');
      expect(
        ntriples,
        contains(
          '<http://example.org/subject> <http://example.org/predicate> <http://example.org/path\\>with\\<special\\>chars> .',
        ),
      );
    });

    test('endodes multiple triples', () {
      final subject1 = IriTerm('http://example.org/subject1');
      final predicate1 = IriTerm('http://example.org/predicate1');
      final object1 = IriTerm('http://example.org/object1');

      final subject2 = IriTerm('http://example.org/subject2');
      final predicate2 = IriTerm('http://example.org/predicate2');
      final object2 = LiteralTerm.string('Object 2');

      final graph = RdfGraph.fromTriples([
        Triple(subject1, predicate1, object1),
        Triple(subject2, predicate2, object2),
      ]);

      final ntriples = rdf.encode(graph, contentType: 'application/n-triples');
      expect(
        ntriples,
        contains(
          '<http://example.org/subject1> <http://example.org/predicate1> <http://example.org/object1> .',
        ),
      );
      expect(
        ntriples,
        contains(
          '<http://example.org/subject2> <http://example.org/predicate2> "Object 2" .',
        ),
      );
    });

    test('round-trip parsing and serialization', () {
      final originalNTriples = '''
<http://example.org/subject1> <http://example.org/predicate1> <http://example.org/object1> .
<http://example.org/subject2> <http://example.org/predicate2> "Simple literal" .
<http://example.org/subject3> <http://example.org/predicate3> "English"@en .
<http://example.org/subject4> <http://example.org/predicate4> "42"^^<http://www.w3.org/2001/XMLSchema#integer> .
''';

      // Decode the original N-Triples
      final graph = rdf.decode(
        originalNTriples,
        contentType: 'application/n-triples',
      );

      // Endode back to N-Triples
      final endodedNTriples = rdf.encode(
        graph,
        contentType: 'application/n-triples',
      );

      // Decode the endoded result again
      final redecodedGraph = rdf.decode(
        endodedNTriples,
        contentType: 'application/n-triples',
      );

      // The number of triples should be the same
      expect(redecodedGraph.triples.length, equals(graph.triples.length));

      // Check for IRI subjects, typed literals, and language-tagged literals
      final iriSubjectCount =
          graph.triples.where((t) => t.subject is IriTerm).length;
      final redecodedIriSubjectCount =
          redecodedGraph.triples.where((t) => t.subject is IriTerm).length;
      expect(iriSubjectCount, equals(redecodedIriSubjectCount));

      final literalObjectCount =
          graph.triples.where((t) => t.object is LiteralTerm).length;
      final redecodedLiteralObjectCount =
          redecodedGraph.triples.where((t) => t.object is LiteralTerm).length;
      expect(literalObjectCount, equals(redecodedLiteralObjectCount));

      // Check for language-tagged literals
      final langLiteralCount = graph.triples
          .where(
            (t) =>
                t.object is LiteralTerm &&
                (t.object as LiteralTerm).language != null,
          )
          .length;
      final redecodedLangLiteralCount = redecodedGraph.triples
          .where(
            (t) =>
                t.object is LiteralTerm &&
                (t.object as LiteralTerm).language != null,
          )
          .length;
      expect(langLiteralCount, equals(redecodedLangLiteralCount));
    });
  });
}
