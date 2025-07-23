import 'package:rdf_core/src/vocab/iri_compaction.dart';
import 'package:test/test.dart';
import 'package:rdf_core/src/graph/rdf_graph.dart';
import 'package:rdf_core/src/graph/rdf_term.dart';
import 'package:rdf_core/src/graph/triple.dart';
import 'package:rdf_core/src/turtle/turtle_encoder.dart';

String encodeLiteral(LiteralTerm langTerm) =>
    TurtleEncoder().writeTerm(langTerm,
        iriRole: IriRole.object,
        compactedIris: IriCompactionResult(prefixes: {}, compactIris: {}),
        blankNodeLabels: {});

void main() {
  group('RdfGraph', () {
    test('langTerm', () {
      final langTerm = LiteralTerm.withLanguage('Hello', 'en');
      expect(encodeLiteral(langTerm), equals('"Hello"@en'));
    });

    test('illegal langTerm', () {
      expect(
        () => LiteralTerm(
          'Hello',
          datatype: IriTerm("http://example.com/foo"),
          language: 'en',
        ),
        throwsA(
          isA<AssertionError>().having(
            (e) => e.message,
            'message',
            'Language-tagged literals must use rdf:langString datatype, and rdf:langString must have a language tag',
          ),
        ),
      );
    });

    test('legal langTerm alternative construction', () {
      var baseIri = "http://www.w3.org/1999/02/22-rdf-syntax-ns#";
      var type = "langString";
      final langTerm = LiteralTerm(
        'Hello',
        datatype: IriTerm("$baseIri$type"),
        language: 'en',
      );
      expect(encodeLiteral(langTerm), equals('"Hello"@en'));
    });

    // Tests for the new immutable RdfGraph implementation
    group('Immutable RdfGraph', () {
      test('should create empty graph', () {
        final graph = RdfGraph();
        expect(graph.isEmpty, isTrue);
        expect(graph.size, equals(0));
      });

      test('should create graph with initial triples', () {
        final triple = Triple(
          IriTerm('http://example.com/foo'),
          IriTerm('http://example.com/bar'),
          LiteralTerm.string('baz'),
        );

        final graph = RdfGraph(triples: [triple]);
        expect(graph.isEmpty, isFalse);
        expect(graph.size, equals(1));
        expect(graph.triples, contains(triple));
      });

      test('should add triples immutably with withTriple', () {
        final triple1 = Triple(
          IriTerm('http://example.com/foo'),
          IriTerm('http://example.com/bar'),
          LiteralTerm.string('baz'),
        );

        final triple2 = Triple(
          IriTerm('http://example.com/foo'),
          IriTerm('http://example.com/qux'),
          LiteralTerm.string('quux'),
        );

        final graph1 = RdfGraph();
        final graph2 = graph1.withTriple(triple1);
        final graph3 = graph2.withTriple(triple2);

        // Original graph should remain empty
        expect(graph1.isEmpty, isTrue);

        // Second graph should have only triple1
        expect(graph2.size, equals(1));
        expect(graph2.triples, contains(triple1));
        expect(graph2.triples, isNot(contains(triple2)));

        // Third graph should have both triples
        expect(graph3.size, equals(2));
        expect(graph3.triples, contains(triple1));
        expect(graph3.triples, contains(triple2));
      });

      test('should add multiple triples immutably with withTriples', () {
        final triple1 = Triple(
          IriTerm('http://example.com/foo'),
          IriTerm('http://example.com/bar'),
          LiteralTerm.string('baz'),
        );

        final triple2 = Triple(
          IriTerm('http://example.com/foo'),
          IriTerm('http://example.com/qux'),
          LiteralTerm.string('quux'),
        );

        final graph1 = RdfGraph();
        final graph2 = graph1.withTriples([triple1, triple2]);

        // Original graph should remain empty
        expect(graph1.isEmpty, isTrue);

        // New graph should have both triples
        expect(graph2.size, equals(2));
        expect(graph2.triples, contains(triple1));
        expect(graph2.triples, contains(triple2));
      });

      test('should find triples by pattern', () {
        final triple1 = Triple(
          IriTerm('http://example.com/foo'),
          IriTerm('http://example.com/bar'),
          LiteralTerm.string('baz'),
        );

        final triple2 = Triple(
          IriTerm('http://example.com/foo'),
          IriTerm('http://example.com/qux'),
          LiteralTerm.string('quux'),
        );

        final triple3 = Triple(
          IriTerm('http://example.com/bar'),
          IriTerm('http://example.com/bar'),
          LiteralTerm.string('baz'),
        );

        final graph = RdfGraph()
            .withTriple(triple1)
            .withTriple(triple2)
            .withTriple(triple3);

        // Find by subject
        var triples = graph.findTriples(
          subject: IriTerm('http://example.com/foo'),
        );
        expect(triples.length, equals(2));
        expect(triples, contains(triple1));
        expect(triples, contains(triple2));

        // Find by predicate
        triples = graph.findTriples(
          predicate: IriTerm('http://example.com/bar'),
        );
        expect(triples.length, equals(2));
        expect(triples, contains(triple1));
        expect(triples, contains(triple3));

        // Find by object
        triples = graph.findTriples(object: LiteralTerm.string('baz'));
        expect(triples.length, equals(2));
        expect(triples, contains(triple1));
        expect(triples, contains(triple3));

        // Find by subject and predicate
        triples = graph.findTriples(
          subject: IriTerm('http://example.com/foo'),
          predicate: IriTerm('http://example.com/bar'),
        );
        expect(triples.length, equals(1));
        expect(triples[0], equals(triple1));
      });

      test('should get objects for subject and predicate', () {
        final subject = IriTerm('http://example.com/foo');
        final predicate = IriTerm('http://example.com/bar');
        final object1 = LiteralTerm.string('baz');
        final object2 = LiteralTerm.string('qux');

        final graph = RdfGraph()
            .withTriple(Triple(subject, predicate, object1))
            .withTriple(Triple(subject, predicate, object2));

        final objects = graph.getObjects(subject, predicate);
        expect(objects.length, equals(2));
        expect(objects, contains(object1));
        expect(objects, contains(object2));
      });

      test('should get subjects for predicate and object', () {
        final subject1 = IriTerm('http://example.com/foo');
        final subject2 = IriTerm('http://example.com/bar');
        final predicate = IriTerm('http://example.com/baz');
        final object = LiteralTerm.string('qux');

        final graph = RdfGraph()
            .withTriple(Triple(subject1, predicate, object))
            .withTriple(Triple(subject2, predicate, object));

        final subjects = graph.getSubjects(predicate, object);
        expect(subjects.length, equals(2));
        expect(subjects, contains(subject1));
        expect(subjects, contains(subject2));
      });

      test('should filter triples with withoutMatching', () {
        final triple1 = Triple(
          IriTerm('http://example.com/foo'),
          IriTerm('http://example.com/bar'),
          LiteralTerm.string('baz'),
        );

        final triple2 = Triple(
          IriTerm('http://example.com/foo'),
          IriTerm('http://example.com/qux'),
          LiteralTerm.string('quux'),
        );

        final triple3 = Triple(
          IriTerm('http://example.com/bar'),
          IriTerm('http://example.com/bar'),
          LiteralTerm.string('baz'),
        );

        final graph = RdfGraph()
            .withTriple(triple1)
            .withTriple(triple2)
            .withTriple(triple3);

        // Filter by subject
        final filteredBySubject = graph.withoutMatching(
          subject: IriTerm('http://example.com/foo'),
        );
        expect(filteredBySubject.size, equals(1));
        expect(filteredBySubject.triples, contains(triple3));

        // Filter by predicate
        final filteredByPredicate = graph.withoutMatching(
          predicate: IriTerm('http://example.com/bar'),
        );
        expect(filteredByPredicate.size, equals(1));
        expect(filteredByPredicate.triples, contains(triple2));

        // Filter by object
        final filteredByObject = graph.withoutMatching(
          object: LiteralTerm.string('baz'),
        );
        expect(filteredByObject.size, equals(1));
        expect(filteredByObject.triples, contains(triple2));
      });

      test(
        'withoutMatching should return a copy of the graph when no parameters provided',
        () {
          final triple1 = Triple(
            IriTerm('http://example.com/foo'),
            IriTerm('http://example.com/bar'),
            LiteralTerm.string('baz'),
          );

          final triple2 = Triple(
            IriTerm('http://example.com/bar'),
            IriTerm('http://example.com/qux'),
            LiteralTerm.string('quux'),
          );

          final originalGraph =
              RdfGraph().withTriple(triple1).withTriple(triple2);

          // Call withoutMatching with no parameters
          final resultGraph = originalGraph.withoutMatching();

          // The result should be equivalent to the original graph
          expect(resultGraph.size, equals(originalGraph.size));
          expect(resultGraph.triples, containsAll(originalGraph.triples));
          expect(originalGraph.triples, containsAll(resultGraph.triples));

          // Since they have the same triples, they should be equal
          expect(resultGraph, equals(originalGraph));

          // But they should be different instances (immutability check)
          expect(identical(resultGraph, originalGraph), isFalse);
        },
      );

      test('should merge graphs immutably', () {
        final triple1 = Triple(
          IriTerm('http://example.com/foo'),
          IriTerm('http://example.com/bar'),
          LiteralTerm.string('baz'),
        );

        final triple2 = Triple(
          IriTerm('http://example.com/foo'),
          IriTerm('http://example.com/qux'),
          LiteralTerm.string('quux'),
        );

        final graph1 = RdfGraph().withTriple(triple1);
        final graph2 = RdfGraph().withTriple(triple2);

        final mergedGraph = graph1.merge(graph2);

        // Original graphs should remain unchanged
        expect(graph1.size, equals(1));
        expect(graph1.triples, contains(triple1));
        expect(graph1.triples, isNot(contains(triple2)));

        expect(graph2.size, equals(1));
        expect(graph2.triples, contains(triple2));
        expect(graph2.triples, isNot(contains(triple1)));

        // Merged graph should have both triples
        expect(mergedGraph.size, equals(2));
        expect(mergedGraph.triples, contains(triple1));
        expect(mergedGraph.triples, contains(triple2));
      });

      test('should implement equality correctly', () {
        final triple1 = Triple(
          IriTerm('http://example.com/foo'),
          IriTerm('http://example.com/bar'),
          LiteralTerm.string('baz'),
        );

        final triple2 = Triple(
          IriTerm('http://example.com/foo'),
          IriTerm('http://example.com/qux'),
          LiteralTerm.string('quux'),
        );

        final graph1 = RdfGraph().withTriple(triple1).withTriple(triple2);

        final graph2 = RdfGraph().withTriple(triple2).withTriple(triple1);

        // Same triples in different order should be equal
        expect(graph1 == graph2, isTrue);
        expect(graph1.hashCode, equals(graph2.hashCode));

        // Different graphs should not be equal
        final graph3 = RdfGraph().withTriple(triple1);
        expect(graph1 == graph3, isFalse);
      });

      test('equality should be false for different types', () {
        final graph = RdfGraph();
        // ignore: unrelated_type_equality_checks
        expect(graph == 'not a graph', isFalse);
      });

      test('identical graphs should be equal', () {
        final graph = RdfGraph();
        expect(graph == graph, isTrue);
      });
    });

    // Legacy tests for compatibility verification
    group('Legacy Compatibility', () {
      test('should handle a complete profile', () {
        final profileTriple = Triple(
          IriTerm('https://example.com/profile#me'),
          IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#type'),
          IriTerm('http://www.w3.org/ns/solid/terms#Profile'),
        );
        final storageTriple1 = Triple(
          IriTerm('https://example.com/profile#me'),
          IriTerm('http://www.w3.org/ns/solid/terms#storage'),
          IriTerm('https://example.com/storage/'),
        );
        final storageTriple2 = Triple(
          IriTerm('https://example.com/profile#me'),
          IriTerm('http://www.w3.org/ns/pim/space#storage'),
          IriTerm('https://example.com/storage/'),
        );

        final graph = RdfGraph()
            .withTriple(profileTriple)
            .withTriple(storageTriple1)
            .withTriple(storageTriple2);

        // Find all storage URLs
        final storageTriples = graph
            .findTriples(subject: IriTerm('https://example.com/profile#me'))
            .where(
              (triple) =>
                  triple.predicate ==
                      IriTerm('http://www.w3.org/ns/solid/terms#storage') ||
                  triple.predicate ==
                      IriTerm('http://www.w3.org/ns/pim/space#storage'),
            );

        expect(storageTriples.length, equals(2));
        expect(
          storageTriples.map((t) => t.object),
          everyElement(equals(IriTerm('https://example.com/storage/'))),
        );
      });
    });
  });
}
