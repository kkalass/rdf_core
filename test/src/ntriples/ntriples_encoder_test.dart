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
      final subject = const IriTerm('http://example.org/subject');
      final predicate = const IriTerm('http://example.org/predicate');
      final object = const IriTerm('http://example.org/object');
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
      final predicate = const IriTerm('http://example.org/predicate');
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
      final subject = const IriTerm('http://example.org/subject');
      final predicate = const IriTerm('http://example.org/predicate');
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
      final subject = const IriTerm('http://example.org/subject');
      final predicate = const IriTerm('http://example.org/predicate');
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
      final subject = const IriTerm('http://example.org/subject');
      final predicate = const IriTerm('http://example.org/predicate');
      // Create a typed literal using the correct term constructor
      final object = LiteralTerm(
        '42',
        datatype: const IriTerm('http://www.w3.org/2001/XMLSchema#integer'),
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
      final subject = const IriTerm('http://example.org/subject');
      final predicate = const IriTerm('http://example.org/predicate');

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
      final subject = const IriTerm('http://example.org/subject');
      final predicate = const IriTerm('http://example.org/predicate');
      final object =
          const IriTerm('http://example.org/path>with<special>chars');
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
      final subject1 = const IriTerm('http://example.org/subject1');
      final predicate1 = const IriTerm('http://example.org/predicate1');
      final object1 = const IriTerm('http://example.org/object1');

      final subject2 = const IriTerm('http://example.org/subject2');
      final predicate2 = const IriTerm('http://example.org/predicate2');
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

    test('maintains consistent blank node labels and uses sequential numbering',
        () {
      // Create multiple blank nodes, some used multiple times
      final blankNode1 = BlankNodeTerm();
      final blankNode2 = BlankNodeTerm();
      final blankNode3 = BlankNodeTerm();

      final predicate1 = const IriTerm('http://example.org/predicate1');
      final predicate2 = const IriTerm('http://example.org/predicate2');
      final subject = const IriTerm('http://example.org/subject');

      // Create triples where same blank nodes appear multiple times
      final graph = RdfGraph.fromTriples([
        Triple(blankNode1, predicate1, LiteralTerm.string('value1')),
        Triple(blankNode1, predicate2,
            LiteralTerm.string('value2')), // same blank node again
        Triple(
            blankNode2, predicate1, blankNode1), // blankNode1 appears as object
        Triple(subject, predicate1,
            blankNode1), // blankNode1 appears as object again
        Triple(blankNode3, predicate1, LiteralTerm.string('value3')),
      ]);

      final ntriples = rdf.encode(graph, contentType: 'application/n-triples');
      final lines = ntriples.trim().split('\n');

      // Verify we have 5 lines (one per triple)
      expect(lines.length, equals(5));

      // Extract all blank node references from the output
      final blankNodePattern = RegExp(r'_:(b\d+)');
      final blankNodeReferences = <String>[];

      for (final line in lines) {
        final matches = blankNodePattern.allMatches(line);
        for (final match in matches) {
          blankNodeReferences.add(match.group(1)!);
        }
      }

      // Should have 7 blank node references total (some nodes appear multiple times)
      expect(blankNodeReferences.length, equals(6));

      // Check that labels follow sequential numbering (b0, b1, b2)
      final uniqueLabels = blankNodeReferences.toSet().toList()..sort();
      expect(uniqueLabels, equals(['b0', 'b1', 'b2']));

      // Verify consistency: count occurrences of each label
      final labelCounts = <String, int>{};
      for (final label in blankNodeReferences) {
        labelCounts[label] = (labelCounts[label] ?? 0) + 1;
      }

      // blankNode1 should appear 4 times (as subject twice, as object twice)
      // blankNode2 should appear 1 time (as subject once)
      // blankNode3 should appear 1 time (as subject once)
      // We can't know which physical blank node maps to which label, but we know the counts
      final counts = labelCounts.values.toList()..sort();
      expect(counts, equals([1, 1, 4]));

      // Verify specific consistency: same blank node always gets same label
      // Find which label corresponds to the blank node that appears 4 times
      final frequentLabel =
          labelCounts.entries.firstWhere((entry) => entry.value == 4).key;

      // Count how many lines contain this frequent label
      int linesWithFrequentLabel = 0;
      for (final line in lines) {
        if (line.contains('_:$frequentLabel')) {
          linesWithFrequentLabel++;
        }
      }

      // The frequent blank node should appear in exactly 4 lines
      expect(linesWithFrequentLabel, equals(4));
    });
  });
}
