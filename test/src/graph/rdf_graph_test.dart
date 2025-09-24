import 'package:rdf_core/src/iri_compaction.dart';
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
          datatype: const IriTerm("http://example.com/foo"),
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
        datatype: IriTerm.validated("$baseIri$type"),
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
          const IriTerm('http://example.com/foo'),
          const IriTerm('http://example.com/bar'),
          LiteralTerm.string('baz'),
        );

        final graph = RdfGraph(triples: [triple]);
        expect(graph.isEmpty, isFalse);
        expect(graph.size, equals(1));
        expect(graph.triples, contains(triple));
      });

      test('should add triples immutably with withTriple', () {
        final triple1 = Triple(
          const IriTerm('http://example.com/foo'),
          const IriTerm('http://example.com/bar'),
          LiteralTerm.string('baz'),
        );

        final triple2 = Triple(
          const IriTerm('http://example.com/foo'),
          const IriTerm('http://example.com/qux'),
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
          const IriTerm('http://example.com/foo'),
          const IriTerm('http://example.com/bar'),
          LiteralTerm.string('baz'),
        );

        final triple2 = Triple(
          const IriTerm('http://example.com/foo'),
          const IriTerm('http://example.com/qux'),
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
          const IriTerm('http://example.com/foo'),
          const IriTerm('http://example.com/bar'),
          LiteralTerm.string('baz'),
        );

        final triple2 = Triple(
          const IriTerm('http://example.com/foo'),
          const IriTerm('http://example.com/qux'),
          LiteralTerm.string('quux'),
        );

        final triple3 = Triple(
          const IriTerm('http://example.com/bar'),
          const IriTerm('http://example.com/bar'),
          LiteralTerm.string('baz'),
        );

        final graph = RdfGraph()
            .withTriple(triple1)
            .withTriple(triple2)
            .withTriple(triple3);

        // Find by subject
        var triples = graph.findTriples(
          subject: const IriTerm('http://example.com/foo'),
        );
        expect(triples.length, equals(2));
        expect(triples, contains(triple1));
        expect(triples, contains(triple2));

        // Find by predicate
        triples = graph.findTriples(
          predicate: const IriTerm('http://example.com/bar'),
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
          subject: const IriTerm('http://example.com/foo'),
          predicate: const IriTerm('http://example.com/bar'),
        );
        expect(triples.length, equals(1));
        expect(triples[0], equals(triple1));
      });

      test('should get objects for subject and predicate', () {
        final subject = const IriTerm('http://example.com/foo');
        final predicate = const IriTerm('http://example.com/bar');
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
        final subject1 = const IriTerm('http://example.com/foo');
        final subject2 = const IriTerm('http://example.com/bar');
        final predicate = const IriTerm('http://example.com/baz');
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
          const IriTerm('http://example.com/foo'),
          const IriTerm('http://example.com/bar'),
          LiteralTerm.string('baz'),
        );

        final triple2 = Triple(
          const IriTerm('http://example.com/foo'),
          const IriTerm('http://example.com/qux'),
          LiteralTerm.string('quux'),
        );

        final triple3 = Triple(
          const IriTerm('http://example.com/bar'),
          const IriTerm('http://example.com/bar'),
          LiteralTerm.string('baz'),
        );

        final graph = RdfGraph()
            .withTriple(triple1)
            .withTriple(triple2)
            .withTriple(triple3);

        // Filter by subject
        final filteredBySubject = graph.withoutMatching(
          subject: const IriTerm('http://example.com/foo'),
        );
        expect(filteredBySubject.size, equals(1));
        expect(filteredBySubject.triples, contains(triple3));

        // Filter by predicate
        final filteredByPredicate = graph.withoutMatching(
          predicate: const IriTerm('http://example.com/bar'),
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
            const IriTerm('http://example.com/foo'),
            const IriTerm('http://example.com/bar'),
            LiteralTerm.string('baz'),
          );

          final triple2 = Triple(
            const IriTerm('http://example.com/bar'),
            const IriTerm('http://example.com/qux'),
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
          const IriTerm('http://example.com/foo'),
          const IriTerm('http://example.com/bar'),
          LiteralTerm.string('baz'),
        );

        final triple2 = Triple(
          const IriTerm('http://example.com/foo'),
          const IriTerm('http://example.com/qux'),
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
          const IriTerm('http://example.com/foo'),
          const IriTerm('http://example.com/bar'),
          LiteralTerm.string('baz'),
        );

        final triple2 = Triple(
          const IriTerm('http://example.com/foo'),
          const IriTerm('http://example.com/qux'),
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

      test('should configure indexing with withOptions', () {
        final triple = Triple(
          const IriTerm('http://example.com/foo'),
          const IriTerm('http://example.com/bar'),
          LiteralTerm.string('baz'),
        );

        final originalGraph = RdfGraph(triples: [triple], enableIndexing: true);

        // Change indexing setting
        final disabledIndexGraph =
            originalGraph.withOptions(enableIndexing: false);
        expect(disabledIndexGraph.indexingEnabled, isFalse);
        expect(disabledIndexGraph.size, equals(1));
        expect(disabledIndexGraph.triples, contains(triple));

        // Change back to enabled
        final enabledIndexGraph =
            disabledIndexGraph.withOptions(enableIndexing: true);
        expect(enabledIndexGraph.indexingEnabled, isTrue);
        expect(enabledIndexGraph.size, equals(1));
        expect(enabledIndexGraph.triples, contains(triple));

        // No change should return same instance
        final sameGraph = originalGraph.withOptions(enableIndexing: true);
        expect(identical(sameGraph, originalGraph), isTrue);

        // Null parameter should preserve current setting
        final preservedGraph = originalGraph.withOptions();
        expect(preservedGraph.indexingEnabled,
            equals(originalGraph.indexingEnabled));
      });

      test('should check triple existence with hasTriples', () {
        final triple1 = Triple(
          const IriTerm('http://example.com/john'),
          const IriTerm('http://xmlns.com/foaf/0.1/name'),
          LiteralTerm.string('John Smith'),
        );

        final triple2 = Triple(
          const IriTerm('http://example.com/jane'),
          const IriTerm('http://xmlns.com/foaf/0.1/name'),
          LiteralTerm.string('Jane Doe'),
        );

        final triple3 = Triple(
          const IriTerm('http://example.com/john'),
          const IriTerm('http://xmlns.com/foaf/0.1/knows'),
          const IriTerm('http://example.com/jane'),
        );

        final emptyGraph = RdfGraph();
        final graph = RdfGraph()
            .withTriple(triple1)
            .withTriple(triple2)
            .withTriple(triple3);

        // Empty graph checks
        expect(emptyGraph.hasTriples(), isFalse);
        expect(
            emptyGraph.hasTriples(
                subject: const IriTerm('http://example.com/john')),
            isFalse);

        // Non-empty graph checks
        expect(graph.hasTriples(), isTrue);

        // Check by subject
        expect(
            graph.hasTriples(subject: const IriTerm('http://example.com/john')),
            isTrue);
        expect(
            graph.hasTriples(subject: const IriTerm('http://example.com/jane')),
            isTrue);
        expect(
            graph.hasTriples(subject: const IriTerm('http://example.com/bob')),
            isFalse);

        // Check by predicate
        expect(
            graph.hasTriples(
                predicate: const IriTerm('http://xmlns.com/foaf/0.1/name')),
            isTrue);
        expect(
            graph.hasTriples(
                predicate: const IriTerm('http://xmlns.com/foaf/0.1/knows')),
            isTrue);
        expect(
            graph.hasTriples(
                predicate: const IriTerm('http://xmlns.com/foaf/0.1/age')),
            isFalse);

        // Check by object
        expect(
            graph.hasTriples(object: LiteralTerm.string('John Smith')), isTrue);
        expect(
            graph.hasTriples(object: const IriTerm('http://example.com/jane')),
            isTrue);
        expect(graph.hasTriples(object: LiteralTerm.string('Bob Johnson')),
            isFalse);

        // Check by combination
        expect(
            graph.hasTriples(
              subject: const IriTerm('http://example.com/john'),
              predicate: const IriTerm('http://xmlns.com/foaf/0.1/name'),
            ),
            isTrue);

        expect(
            graph.hasTriples(
              subject: const IriTerm('http://example.com/john'),
              predicate: const IriTerm('http://xmlns.com/foaf/0.1/name'),
              object: LiteralTerm.string('John Smith'),
            ),
            isTrue);

        expect(
            graph.hasTriples(
              subject: const IriTerm('http://example.com/john'),
              predicate: const IriTerm('http://xmlns.com/foaf/0.1/name'),
              object: LiteralTerm.string('Jane Doe'),
            ),
            isFalse);
      });

      test('should get unique subjects, predicates, and objects', () {
        final subject1 = const IriTerm('http://example.com/john');
        final subject2 = const IriTerm('http://example.com/jane');
        final predicate1 = const IriTerm('http://xmlns.com/foaf/0.1/name');
        final predicate2 = const IriTerm('http://xmlns.com/foaf/0.1/knows');
        final object1 = LiteralTerm.string('John Smith');
        final object2 = LiteralTerm.string('Jane Doe');

        final graph = RdfGraph()
            .withTriple(Triple(subject1, predicate1, object1))
            .withTriple(Triple(subject2, predicate1, object2))
            .withTriple(Triple(subject1, predicate2, subject2))
            .withTriple(Triple(subject1, predicate1, object1)); // Duplicate

        // Test subjects
        final subjects = graph.subjects;
        expect(subjects.length, equals(2));
        expect(subjects, contains(subject1));
        expect(subjects, contains(subject2));

        // Test predicates
        final predicates = graph.predicates;
        expect(predicates.length, equals(2));
        expect(predicates, contains(predicate1));
        expect(predicates, contains(predicate2));

        // Test objects
        final objects = graph.objects;
        expect(objects.length,
            equals(3)); // object1, object2, subject2 (used as object)
        expect(objects, contains(object1));
        expect(objects, contains(object2));
        expect(
            objects, contains(subject2)); // subject2 is also used as an object
      });

      test(
          'should handle empty graph for subjects, predicates, objects getters',
          () {
        final emptyGraph = RdfGraph();

        expect(emptyGraph.subjects, isEmpty);
        expect(emptyGraph.predicates, isEmpty);
        expect(emptyGraph.objects, isEmpty);
      });

      test(
          'should work with indexing disabled for subjects, predicates, objects getters',
          () {
        final subject = const IriTerm('http://example.com/john');
        final predicate = const IriTerm('http://xmlns.com/foaf/0.1/name');
        final object = LiteralTerm.string('John Smith');

        final indexedGraph = RdfGraph(
            triples: [Triple(subject, predicate, object)],
            enableIndexing: true);
        final unindexedGraph = indexedGraph.withOptions(enableIndexing: false);

        // Results should be the same regardless of indexing
        expect(indexedGraph.subjects, equals(unindexedGraph.subjects));
        expect(indexedGraph.predicates, equals(unindexedGraph.predicates));
        expect(indexedGraph.objects, equals(unindexedGraph.objects));

        expect(unindexedGraph.subjects, contains(subject));
        expect(unindexedGraph.predicates, contains(predicate));
        expect(unindexedGraph.objects, contains(object));
      });

      test('should create subgraphs with pattern matching', () {
        final john = const IriTerm('http://example.com/john');
        final jane = const IriTerm('http://example.com/jane');
        final name = const IriTerm('http://xmlns.com/foaf/0.1/name');
        final knows = const IriTerm('http://xmlns.com/foaf/0.1/knows');
        final email = const IriTerm('http://xmlns.com/foaf/0.1/email');

        final johnName = LiteralTerm.string('John Smith');
        final janeName = LiteralTerm.string('Jane Doe');
        final johnEmail = LiteralTerm.string('john@example.com');

        final graph = RdfGraph()
            .withTriple(Triple(john, name, johnName))
            .withTriple(Triple(jane, name, janeName))
            .withTriple(Triple(john, knows, jane))
            .withTriple(Triple(john, email, johnEmail));

        // Test subject-only filtering
        final johnGraph = graph.matching(subject: john);
        expect(johnGraph.size, equals(3));
        expect(johnGraph.hasTriples(subject: john, predicate: name), isTrue);
        expect(johnGraph.hasTriples(subject: john, predicate: knows), isTrue);
        expect(johnGraph.hasTriples(subject: john, predicate: email), isTrue);
        expect(johnGraph.hasTriples(subject: jane), isFalse);

        // Test predicate-only filtering
        final nameGraph = graph.matching(predicate: name);
        expect(nameGraph.size, equals(2));
        expect(nameGraph.hasTriples(subject: john, predicate: name), isTrue);
        expect(nameGraph.hasTriples(subject: jane, predicate: name), isTrue);
        expect(nameGraph.hasTriples(predicate: knows), isFalse);

        // Test subject + predicate filtering
        final johnNameGraph = graph.matching(subject: john, predicate: name);
        expect(johnNameGraph.size, equals(1));
        expect(
            johnNameGraph.hasTriples(subject: john, predicate: name), isTrue);
        expect(
            johnNameGraph.hasTriples(subject: john, predicate: knows), isFalse);

        // Test object filtering
        final janeObjectGraph = graph.matching(object: jane);
        expect(janeObjectGraph.size, equals(1));
        expect(janeObjectGraph.hasTriples(subject: john, predicate: knows),
            isTrue);
      });

      test('should return empty subgraph for non-matching patterns', () {
        final john = const IriTerm('http://example.com/john');
        final name = const IriTerm('http://xmlns.com/foaf/0.1/name');
        final nonExistent = const IriTerm('http://example.com/nonexistent');

        final graph = RdfGraph()
            .withTriple(Triple(john, name, LiteralTerm.string('John Smith')));

        // Non-existent subject
        final emptyGraph1 = graph.matching(subject: nonExistent);
        expect(emptyGraph1.isEmpty, isTrue);

        // Non-existent predicate
        final emptyGraph2 = graph.matching(predicate: nonExistent);
        expect(emptyGraph2.isEmpty, isTrue);

        // Non-existent subject + predicate combination
        final emptyGraph3 =
            graph.matching(subject: john, predicate: nonExistent);
        expect(emptyGraph3.isEmpty, isTrue);
      });

      test(
          'should optimize subgraph with index reuse for subject-based filtering',
          () {
        final john = const IriTerm('http://example.com/john');
        final jane = const IriTerm('http://example.com/jane');
        final name = const IriTerm('http://xmlns.com/foaf/0.1/name');
        final knows = const IriTerm('http://xmlns.com/foaf/0.1/knows');

        final graph = RdfGraph(enableIndexing: true)
            .withTriple(Triple(john, name, LiteralTerm.string('John Smith')))
            .withTriple(Triple(john, knows, jane))
            .withTriple(Triple(jane, name, LiteralTerm.string('Jane Doe')));

        // Force index creation
        graph.findTriples(subject: john);

        // Create subgraph - should reuse index
        final johnGraph = graph.matching(subject: john);

        // Verify the subgraph has the correct triples
        expect(johnGraph.size, equals(2));
        expect(johnGraph.hasTriples(subject: john, predicate: name), isTrue);
        expect(johnGraph.hasTriples(subject: john, predicate: knows), isTrue);

        // Verify subsequent operations on subgraph are efficient
        final johnNameTriples = johnGraph.findTriples(predicate: name);
        expect(johnNameTriples.length, equals(1));
      });

      test('should work with subgraph chaining', () {
        final john = const IriTerm('http://example.com/john');
        final jane = const IriTerm('http://example.com/jane');
        final name = const IriTerm('http://xmlns.com/foaf/0.1/name');
        final knows = const IriTerm('http://xmlns.com/foaf/0.1/knows');

        final graph1 = RdfGraph()
            .withTriple(Triple(john, name, LiteralTerm.string('John Smith')))
            .withTriple(Triple(john, knows, jane));

        final graph2 = RdfGraph()
            .withTriple(Triple(jane, name, LiteralTerm.string('Jane Doe')));

        // Chain operations: get John's info, merge with graph2, then filter by predicate
        final result = graph1
            .matching(subject: john)
            .merge(graph2)
            .matching(predicate: name);

        expect(result.size, equals(2));
        expect(result.hasTriples(subject: john, predicate: name), isTrue);
        expect(result.hasTriples(subject: jane, predicate: name), isTrue);
        expect(result.hasTriples(predicate: knows), isFalse);
      });

      test('should work with indexing disabled for subgraph', () {
        final john = const IriTerm('http://example.com/john');
        final name = const IriTerm('http://xmlns.com/foaf/0.1/name');
        final knows = const IriTerm('http://xmlns.com/foaf/0.1/knows');
        final jane = const IriTerm('http://example.com/jane');

        final indexedGraph = RdfGraph(enableIndexing: true)
            .withTriple(Triple(john, name, LiteralTerm.string('John Smith')))
            .withTriple(Triple(john, knows, jane));

        final unindexedGraph = indexedGraph.withOptions(enableIndexing: false);

        // Results should be the same regardless of indexing
        final indexedSubgraph = indexedGraph.matching(subject: john);
        final unindexedSubgraph = unindexedGraph.matching(subject: john);

        expect(indexedSubgraph.size, equals(unindexedSubgraph.size));
        expect(indexedSubgraph.triples.toSet(),
            equals(unindexedSubgraph.triples.toSet()));
      });
    });

    // Legacy tests for compatibility verification
    group('Legacy Compatibility', () {
      test('should handle a complete profile', () {
        final profileTriple = Triple(
          const IriTerm('https://example.com/profile#me'),
          const IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#type'),
          const IriTerm('http://www.w3.org/ns/solid/terms#Profile'),
        );
        final storageTriple1 = Triple(
          const IriTerm('https://example.com/profile#me'),
          const IriTerm('http://www.w3.org/ns/solid/terms#storage'),
          const IriTerm('https://example.com/storage/'),
        );
        final storageTriple2 = Triple(
          const IriTerm('https://example.com/profile#me'),
          const IriTerm('http://www.w3.org/ns/pim/space#storage'),
          const IriTerm('https://example.com/storage/'),
        );

        final graph = RdfGraph()
            .withTriple(profileTriple)
            .withTriple(storageTriple1)
            .withTriple(storageTriple2);

        // Find all storage URLs
        final storageTriples = graph
            .findTriples(
                subject: const IriTerm('https://example.com/profile#me'))
            .where(
              (triple) =>
                  triple.predicate ==
                      const IriTerm(
                          'http://www.w3.org/ns/solid/terms#storage') ||
                  triple.predicate ==
                      const IriTerm('http://www.w3.org/ns/pim/space#storage'),
            );

        expect(storageTriples.length, equals(2));
        expect(
          storageTriples.map((t) => t.object),
          everyElement(equals(const IriTerm('https://example.com/storage/'))),
        );
      });
    });
  });
}
