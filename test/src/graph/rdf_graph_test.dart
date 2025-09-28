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

      test('should extract true subgraphs with reachability', () {
        // Create a graph with interconnected resources
        final alice = const IriTerm('http://example.com/alice');
        final bob = const IriTerm('http://example.com/bob');
        final address1 = const IriTerm('http://example.com/address1');
        final address2 = const IriTerm('http://example.com/address2');

        final name = const IriTerm('http://xmlns.com/foaf/0.1/name');
        final knows = const IriTerm('http://xmlns.com/foaf/0.1/knows');
        final hasAddress = const IriTerm('http://example.com/hasAddress');
        final street = const IriTerm('http://example.com/street');
        final city = const IriTerm('http://example.com/city');

        final graph = RdfGraph(triples: [
          // Alice info
          Triple(alice, name, LiteralTerm.string('Alice')),
          Triple(alice, knows, bob),
          Triple(alice, hasAddress, address1),

          // Bob info (reachable from Alice)
          Triple(bob, name, LiteralTerm.string('Bob')),
          Triple(bob, hasAddress, address2),

          // Address1 info (reachable from Alice)
          Triple(address1, street, LiteralTerm.string('123 Main St')),
          Triple(address1, city, LiteralTerm.string('Springfield')),

          // Address2 info (reachable from Alice via Bob)
          Triple(address2, street, LiteralTerm.string('456 Oak Ave')),
          Triple(address2, city, LiteralTerm.string('Shelbyville')),

          // Disconnected info (not reachable from Alice)
          Triple(const IriTerm('http://example.com/charlie'), name,
              LiteralTerm.string('Charlie')),
        ]);

        // Extract subgraph starting from Alice
        final aliceSubgraph = graph.subgraph(alice);

        // Should include all reachable triples (9 total)
        expect(aliceSubgraph.size, equals(9));

        // Should include Alice's direct triples
        expect(
            aliceSubgraph.hasTriples(subject: alice, predicate: name), isTrue);
        expect(
            aliceSubgraph.hasTriples(subject: alice, predicate: knows), isTrue);
        expect(aliceSubgraph.hasTriples(subject: alice, predicate: hasAddress),
            isTrue);

        // Should include Bob's triples (reachable from Alice)
        expect(aliceSubgraph.hasTriples(subject: bob, predicate: name), isTrue);
        expect(aliceSubgraph.hasTriples(subject: bob, predicate: hasAddress),
            isTrue);

        // Should include both addresses' triples (reachable)
        expect(aliceSubgraph.hasTriples(subject: address1, predicate: street),
            isTrue);
        expect(aliceSubgraph.hasTriples(subject: address1, predicate: city),
            isTrue);
        expect(aliceSubgraph.hasTriples(subject: address2, predicate: street),
            isTrue);
        expect(aliceSubgraph.hasTriples(subject: address2, predicate: city),
            isTrue);

        // Should NOT include Charlie (not reachable from Alice)
        expect(
            aliceSubgraph.hasTriples(
                subject: const IriTerm('http://example.com/charlie')),
            isFalse);
      });

      test('should support traversal control with filter callback', () {
        final alice = const IriTerm('http://example.com/alice');
        final bob = const IriTerm('http://example.com/bob');
        final address = const IriTerm('http://example.com/address');

        final name = const IriTerm('http://xmlns.com/foaf/0.1/name');
        final email = const IriTerm('http://xmlns.com/foaf/0.1/email');
        final knows = const IriTerm('http://xmlns.com/foaf/0.1/knows');
        final hasAddress = const IriTerm('http://example.com/hasAddress');
        final street = const IriTerm('http://example.com/street');

        final graph = RdfGraph(triples: [
          Triple(alice, name, LiteralTerm.string('Alice')),
          Triple(alice, email, LiteralTerm.string('alice@example.com')),
          Triple(alice, knows, bob),
          Triple(alice, hasAddress, address),
          Triple(bob, name, LiteralTerm.string('Bob')),
          Triple(bob, email, LiteralTerm.string('bob@example.com')),
          Triple(address, street, LiteralTerm.string('123 Main St')),
        ]);

        // Test TraversalDecision.skip - exclude email triples completely
        final noEmailSubgraph = graph.subgraph(alice, filter: (triple, depth) {
          if (triple.predicate == email) {
            return TraversalDecision.skip;
          }
          return TraversalDecision.include;
        });

        expect(noEmailSubgraph.hasTriples(subject: alice, predicate: name),
            isTrue);
        expect(noEmailSubgraph.hasTriples(subject: alice, predicate: knows),
            isTrue);
        expect(
            noEmailSubgraph.hasTriples(subject: alice, predicate: hasAddress),
            isTrue);
        expect(noEmailSubgraph.hasTriples(subject: alice, predicate: email),
            isFalse);
        expect(
            noEmailSubgraph.hasTriples(subject: bob, predicate: name), isTrue);
        expect(noEmailSubgraph.hasTriples(subject: bob, predicate: email),
            isFalse); // Bob's email also skipped
        expect(noEmailSubgraph.hasTriples(subject: address, predicate: street),
            isTrue);

        // Test TraversalDecision.includeButDontDescend - include address but don't traverse it
        final shallowSubgraph = graph.subgraph(alice, filter: (triple, depth) {
          if (triple.predicate == hasAddress) {
            return TraversalDecision.includeButDontDescend;
          }
          return TraversalDecision.include;
        });

        expect(
            shallowSubgraph.hasTriples(subject: alice, predicate: hasAddress),
            isTrue);
        expect(shallowSubgraph.hasTriples(subject: address, predicate: street),
            isFalse); // Not traversed
        expect(shallowSubgraph.hasTriples(subject: bob, predicate: name),
            isTrue); // Still traversed via knows

        // Test depth limiting - only include direct triples from Alice (depth 0)
        final depthLimitedSubgraph =
            graph.subgraph(alice, filter: (triple, depth) {
          if (depth >= 1) {
            return TraversalDecision.skip;
          }
          return TraversalDecision.include;
        });

        expect(depthLimitedSubgraph.hasTriples(subject: alice, predicate: name),
            isTrue); // depth 0
        expect(depthLimitedSubgraph.hasTriples(subject: bob, predicate: name),
            isFalse); // depth 1 - skipped
        expect(
            depthLimitedSubgraph.hasTriples(
                subject: address, predicate: street),
            isFalse); // depth >= 1 skipped completely
      });

      test('should handle cycles in subgraph traversal', () {
        final alice = const IriTerm('http://example.com/alice');
        final bob = const IriTerm('http://example.com/bob');
        final charlie = const IriTerm('http://example.com/charlie');

        final knows = const IriTerm('http://xmlns.com/foaf/0.1/knows');
        final name = const IriTerm('http://xmlns.com/foaf/0.1/name');

        // Create a cycle: Alice -> Bob -> Charlie -> Alice
        final graph = RdfGraph(triples: [
          Triple(alice, name, LiteralTerm.string('Alice')),
          Triple(alice, knows, bob),

          Triple(bob, name, LiteralTerm.string('Bob')),
          Triple(bob, knows, charlie),

          Triple(charlie, name, LiteralTerm.string('Charlie')),
          Triple(charlie, knows, alice), // Creates cycle back to Alice
        ]);

        final subgraph = graph.subgraph(alice);

        // Should include all triples despite the cycle
        expect(subgraph.size, equals(6));
        expect(subgraph.hasTriples(subject: alice, predicate: name), isTrue);
        expect(subgraph.hasTriples(subject: alice, predicate: knows), isTrue);
        expect(subgraph.hasTriples(subject: bob, predicate: name), isTrue);
        expect(subgraph.hasTriples(subject: bob, predicate: knows), isTrue);
        expect(subgraph.hasTriples(subject: charlie, predicate: name), isTrue);
        expect(subgraph.hasTriples(subject: charlie, predicate: knows), isTrue);
      });

      test('should work with empty root and non-existent subjects', () {
        final alice = const IriTerm('http://example.com/alice');
        final nonExistent = const IriTerm('http://example.com/nonexistent');
        final name = const IriTerm('http://xmlns.com/foaf/0.1/name');

        final graph = RdfGraph(triples: [
          Triple(alice, name, LiteralTerm.string('Alice')),
        ]);

        // Non-existent subject should return empty subgraph
        final emptySubgraph = graph.subgraph(nonExistent);
        expect(emptySubgraph.isEmpty, isTrue);

        // Should work with filter on non-existent subject
        final filteredEmpty =
            graph.subgraph(nonExistent, filter: (triple, depth) {
          return TraversalDecision.include;
        });
        expect(filteredEmpty.isEmpty, isTrue);
      });

      // Comprehensive tests for edge cases and complex scenarios
      group('Subgraph Edge Cases', () {
        test('should handle blank nodes in subgraph traversal', () {
          final alice = const IriTerm('http://example.com/alice');
          final bnode1 = BlankNodeTerm();
          final bnode2 = BlankNodeTerm();
          final name = const IriTerm('http://xmlns.com/foaf/0.1/name');
          final hasAddress = const IriTerm('http://example.com/hasAddress');
          final street = const IriTerm('http://example.com/street');

          final graph = RdfGraph(triples: [
            Triple(alice, name, LiteralTerm.string('Alice')),
            Triple(alice, hasAddress, bnode1),
            Triple(bnode1, street, LiteralTerm.string('123 Main St')),
            Triple(bnode1, name, bnode2),
            Triple(bnode2, name, LiteralTerm.string('Address Name')),
          ]);

          final subgraph = graph.subgraph(alice);

          expect(subgraph.size, equals(5));
          expect(subgraph.hasTriples(subject: alice, predicate: name), isTrue);
          expect(subgraph.hasTriples(subject: alice, predicate: hasAddress),
              isTrue);
          expect(
              subgraph.hasTriples(subject: bnode1, predicate: street), isTrue);
          expect(subgraph.hasTriples(subject: bnode1, predicate: name), isTrue);
          expect(subgraph.hasTriples(subject: bnode2, predicate: name), isTrue);
        });

        test('should handle literal objects (no further traversal)', () {
          final alice = const IriTerm('http://example.com/alice');
          final name = const IriTerm('http://xmlns.com/foaf/0.1/name');
          final age = const IriTerm('http://xmlns.com/foaf/0.1/age');

          final graph = RdfGraph(triples: [
            Triple(alice, name, LiteralTerm.string('Alice')),
            Triple(alice, age, LiteralTerm.integer(30)),
          ]);

          final subgraph = graph.subgraph(alice);

          expect(subgraph.size, equals(2));
          expect(subgraph.hasTriples(subject: alice, predicate: name), isTrue);
          expect(subgraph.hasTriples(subject: alice, predicate: age), isTrue);
        });

        test('should handle multiple cycles and complex interconnections', () {
          final a = const IriTerm('http://example.com/a');
          final b = const IriTerm('http://example.com/b');
          final c = const IriTerm('http://example.com/c');
          final d = const IriTerm('http://example.com/d');
          final relates = const IriTerm('http://example.com/relates');

          // Complex graph with multiple cycles: A->B->C->A and B->D->B
          final graph = RdfGraph(triples: [
            Triple(a, relates, b),
            Triple(b, relates, c),
            Triple(c, relates, a), // Cycle 1: A->B->C->A
            Triple(b, relates, d),
            Triple(d, relates, b), // Cycle 2: B->D->B
            Triple(d, relates, c), // Additional connection
          ]);

          final subgraph = graph.subgraph(a);

          expect(subgraph.size, equals(6)); // All triples should be included
          expect(subgraph.hasTriples(subject: a, predicate: relates), isTrue);
          expect(subgraph.hasTriples(subject: b, predicate: relates), isTrue);
          expect(subgraph.hasTriples(subject: c, predicate: relates), isTrue);
          expect(subgraph.hasTriples(subject: d, predicate: relates), isTrue);
        });

        test('should handle self-referencing triples', () {
          final alice = const IriTerm('http://example.com/alice');
          final knows = const IriTerm('http://xmlns.com/foaf/0.1/knows');
          final name = const IriTerm('http://xmlns.com/foaf/0.1/name');

          final graph = RdfGraph(triples: [
            Triple(alice, name, LiteralTerm.string('Alice')),
            Triple(alice, knows, alice), // Self-reference
          ]);

          final subgraph = graph.subgraph(alice);

          expect(subgraph.size, equals(2));
          expect(subgraph.hasTriples(subject: alice, predicate: name), isTrue);
          expect(subgraph.hasTriples(subject: alice, predicate: knows), isTrue);
        });

        test('should preserve indexing configuration in subgraph', () {
          final alice = const IriTerm('http://example.com/alice');
          final name = const IriTerm('http://xmlns.com/foaf/0.1/name');

          final indexedGraph = RdfGraph(
            triples: [Triple(alice, name, LiteralTerm.string('Alice'))],
            enableIndexing: true,
          );
          final nonIndexedGraph = RdfGraph(
            triples: [Triple(alice, name, LiteralTerm.string('Alice'))],
            enableIndexing: false,
          );

          final indexedSubgraph = indexedGraph.subgraph(alice);
          final nonIndexedSubgraph = nonIndexedGraph.subgraph(alice);

          expect(indexedSubgraph.indexingEnabled, isTrue);
          expect(nonIndexedSubgraph.indexingEnabled, isFalse);
        });
      });

      group('Traversal Decision Combinations', () {
        test('should handle mixed traversal decisions in complex scenarios',
            () {
          final root = const IriTerm('http://example.com/root');
          final child1 = const IriTerm('http://example.com/child1');
          final child2 = const IriTerm('http://example.com/child2');
          final grandchild1 = const IriTerm('http://example.com/grandchild1');
          final grandchild2 = const IriTerm('http://example.com/grandchild2');

          final hasChild = const IriTerm('http://example.com/hasChild');
          final name = const IriTerm('http://xmlns.com/foaf/0.1/name');
          final restricted = const IriTerm('http://example.com/restricted');

          final graph = RdfGraph(triples: [
            // Root level
            Triple(root, name, LiteralTerm.string('Root')),
            Triple(root, hasChild, child1),
            Triple(root, hasChild, child2),

            // Child 1 - will be included but not descended
            Triple(child1, name, LiteralTerm.string('Child1')),
            Triple(child1, hasChild, grandchild1),
            Triple(child1, restricted, LiteralTerm.string('secret')),

            // Child 2 - will be fully traversed
            Triple(child2, name, LiteralTerm.string('Child2')),
            Triple(child2, hasChild, grandchild2),

            // Grandchildren
            Triple(grandchild1, name, LiteralTerm.string('Grandchild1')),
            Triple(grandchild2, name, LiteralTerm.string('Grandchild2')),
          ]);

          final filteredSubgraph =
              graph.subgraph(root, filter: (triple, depth) {
            // Skip all restricted properties
            if (triple.predicate == restricted) {
              return TraversalDecision.skip;
            }
            // Include child1 but don't descend (stops at child1 level)
            if (triple.object == child1) {
              return TraversalDecision.includeButDontDescend;
            }
            // Everything else is fully included
            return TraversalDecision.include;
          });

          // Should include: root name, root->child1, root->child2, child2 name, child2->grandchild2, grandchild2 name
          expect(filteredSubgraph.size, equals(6));

          // Root level
          expect(filteredSubgraph.hasTriples(subject: root, predicate: name),
              isTrue);
          expect(
              filteredSubgraph.hasTriples(
                  subject: root, predicate: hasChild, object: child1),
              isTrue);
          expect(
              filteredSubgraph.hasTriples(
                  subject: root, predicate: hasChild, object: child2),
              isTrue);

          // Child2 branch (fully traversed)
          expect(filteredSubgraph.hasTriples(subject: child2, predicate: name),
              isTrue);
          expect(
              filteredSubgraph.hasTriples(subject: child2, predicate: hasChild),
              isTrue);
          expect(
              filteredSubgraph.hasTriples(
                  subject: grandchild2, predicate: name),
              isTrue);

          // Child1 branch (not descended into)
          expect(filteredSubgraph.hasTriples(subject: child1, predicate: name),
              isFalse);
          expect(
              filteredSubgraph.hasTriples(subject: child1, predicate: hasChild),
              isFalse);
          expect(
              filteredSubgraph.hasTriples(
                  subject: child1, predicate: restricted),
              isFalse);
          expect(filteredSubgraph.hasTriples(subject: grandchild1), isFalse);
        });

        test('should handle conditional traversal based on depth and content',
            () {
          final root = const IriTerm('http://example.com/root');
          final level1a = const IriTerm('http://example.com/level1a');
          final level1b = const IriTerm('http://example.com/level1b');
          final level2a = const IriTerm('http://example.com/level2a');
          final level2b = const IriTerm('http://example.com/level2b');
          final level3 = const IriTerm('http://example.com/level3');

          final connects = const IriTerm('http://example.com/connects');
          final type =
              const IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#type');
          final important = const IriTerm('http://example.com/Important');
          final regular = const IriTerm('http://example.com/Regular');

          final graph = RdfGraph(triples: [
            Triple(root, connects, level1a),
            Triple(root, connects, level1b),
            Triple(level1a, type, important),
            Triple(level1a, connects, level2a),
            Triple(level1b, type, regular),
            Triple(level1b, connects, level2b),
            Triple(level2a, connects, level3),
            Triple(level2b, connects, level3),
            Triple(level3, type, regular),
          ]);

          final conditionalSubgraph =
              graph.subgraph(root, filter: (triple, depth) {
            // At depth 0, when connecting to level1 resources, check their type
            if (depth == 0 && triple.predicate == connects) {
              final objectAsSubject = triple.object;
              if (objectAsSubject is RdfSubject) {
                final hasImportantType = graph.hasTriples(
                    subject: objectAsSubject,
                    predicate: type,
                    object: important);
                if (!hasImportantType) {
                  return TraversalDecision.includeButDontDescend;
                }
              }
            }
            return TraversalDecision.include;
          });

          // Should traverse through level1a (important) but stop at level1b (regular)
          expect(
              conditionalSubgraph.hasTriples(
                  subject: root, predicate: connects),
              isTrue);
          expect(
              conditionalSubgraph.hasTriples(subject: level1a, predicate: type),
              isTrue);
          expect(
              conditionalSubgraph.hasTriples(subject: level1b, predicate: type),
              isFalse); // Not traversed into level1b
          expect(
              conditionalSubgraph.hasTriples(
                  subject: level2a, predicate: connects),
              isTrue);
          expect(
              conditionalSubgraph.hasTriples(
                  subject: level2b, predicate: connects),
              isFalse); // Not traversed
          expect(
              conditionalSubgraph.hasTriples(subject: level3, predicate: type),
              isTrue); // Reached via important path
        });

        test('should handle all TraversalDecision options systematically', () {
          final root = const IriTerm('http://example.com/root');
          final includeNode = const IriTerm('http://example.com/include');
          final skipNode = const IriTerm('http://example.com/skip');
          final dontDescendNode =
              const IriTerm('http://example.com/dontDescend');
          final skipButDescendNode =
              const IriTerm('http://example.com/skipButDescend');
          final childOfInclude =
              const IriTerm('http://example.com/childOfInclude');
          final childOfSkip = const IriTerm('http://example.com/childOfSkip');
          final childOfDontDescend =
              const IriTerm('http://example.com/childOfDontDescend');
          final childOfSkipButDescend =
              const IriTerm('http://example.com/childOfSkipButDescend');

          final connects = const IriTerm('http://example.com/connects');
          final name = const IriTerm('http://xmlns.com/foaf/0.1/name');

          final graph = RdfGraph(triples: [
            Triple(root, connects, includeNode),
            Triple(root, connects, skipNode),
            Triple(root, connects, dontDescendNode),
            Triple(root, connects, skipButDescendNode),
            Triple(includeNode, name, LiteralTerm.string('Include')),
            Triple(includeNode, connects, childOfInclude),
            Triple(skipNode, name, LiteralTerm.string('Skip')),
            Triple(skipNode, connects, childOfSkip),
            Triple(dontDescendNode, name, LiteralTerm.string('DontDescend')),
            Triple(dontDescendNode, connects, childOfDontDescend),
            Triple(
                skipButDescendNode, name, LiteralTerm.string('SkipButDescend')),
            Triple(skipButDescendNode, connects, childOfSkipButDescend),
            Triple(childOfInclude, name, LiteralTerm.string('ChildOfInclude')),
            Triple(childOfSkip, name, LiteralTerm.string('ChildOfSkip')),
            Triple(childOfDontDescend, name,
                LiteralTerm.string('ChildOfDontDescend')),
            Triple(childOfSkipButDescend, name,
                LiteralTerm.string('ChildOfSkipButDescend')),
          ]);

          final systematicSubgraph =
              graph.subgraph(root, filter: (triple, depth) {
            if (triple.object == includeNode) {
              return TraversalDecision.include; // Include and descend
            } else if (triple.object == skipNode) {
              return TraversalDecision.skip; // Skip completely
            } else if (triple.object == dontDescendNode) {
              return TraversalDecision
                  .includeButDontDescend; // Include but don't descend
            } else if (triple.object == skipButDescendNode) {
              return TraversalDecision
                  .skipButDescend; // Skip triple but descend into object
            }
            return TraversalDecision.include; // Default behavior
          });

          // Root connections
          expect(
              systematicSubgraph.hasTriples(
                  subject: root, predicate: connects, object: includeNode),
              isTrue);
          expect(
              systematicSubgraph.hasTriples(
                  subject: root, predicate: connects, object: skipNode),
              isFalse); // Skipped
          expect(
              systematicSubgraph.hasTriples(
                  subject: root, predicate: connects, object: dontDescendNode),
              isTrue);
          expect(
              systematicSubgraph.hasTriples(
                  subject: root,
                  predicate: connects,
                  object: skipButDescendNode),
              isFalse); // Skipped triple

          // Include node - should be fully traversed
          expect(
              systematicSubgraph.hasTriples(
                  subject: includeNode, predicate: name),
              isTrue);
          expect(
              systematicSubgraph.hasTriples(
                  subject: includeNode, predicate: connects),
              isTrue);
          expect(
              systematicSubgraph.hasTriples(
                  subject: childOfInclude, predicate: name),
              isTrue);

          // Skip node - should not appear at all
          expect(systematicSubgraph.hasTriples(subject: skipNode), isFalse);
          expect(systematicSubgraph.hasTriples(subject: childOfSkip), isFalse);

          // DontDescend node - should appear but children should not
          expect(
              systematicSubgraph.hasTriples(
                  subject: dontDescendNode, predicate: name),
              isFalse); // Not descended into
          expect(
              systematicSubgraph.hasTriples(
                  subject: dontDescendNode, predicate: connects),
              isFalse); // Not descended into
          expect(systematicSubgraph.hasTriples(subject: childOfDontDescend),
              isFalse); // Not reached

          // SkipButDescend node - triple is skipped but we still descend to children
          expect(
              systematicSubgraph.hasTriples(
                  subject: skipButDescendNode, predicate: name),
              isTrue); // Descended into
          expect(
              systematicSubgraph.hasTriples(
                  subject: skipButDescendNode, predicate: connects),
              isTrue); // Descended into
          expect(
              systematicSubgraph.hasTriples(
                  subject: childOfSkipButDescend, predicate: name),
              isTrue); // Child reached
        });
      });

      group('skipButDescend Functionality', () {
        test('should demonstrate list filtering using skipButDescend', () {
          // RDF List structure: root -> _:list1 -> _:list2 -> _:list3 -> rdf:nil
          // Each list node has rdf:first (value) and rdf:rest (next) properties
          final root = const IriTerm('http://example.com/root');
          final list1 = BlankNodeTerm();
          final list2 = BlankNodeTerm();
          final list3 = BlankNodeTerm();

          final hasItems = const IriTerm('http://example.com/hasItems');
          final first =
              const IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#first');
          final rest =
              const IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#rest');
          final rdfNil =
              const IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#nil');

          final graph = RdfGraph(triples: [
            // Root connects to the list
            Triple(root, hasItems, list1),

            // List structure with values "apple", "banana", "cherry"
            Triple(list1, first, LiteralTerm.string('apple')),
            Triple(list1, rest, list2),

            Triple(list2, first, LiteralTerm.string('banana')),
            Triple(list2, rest, list3),

            Triple(list3, first, LiteralTerm.string('cherry')),
            Triple(list3, rest, rdfNil),
          ]);

          // Filter to get only list values (rdf:first), skip list structure (rdf:rest)
          final filteredSubgraph =
              graph.subgraph(root, filter: (triple, depth) {
            if (triple.predicate == rest) {
              // Skip the rdf:rest triple but descend to continue following the list
              return TraversalDecision.skipButDescend;
            }
            if (triple.predicate == hasItems) {
              // Skip the initial connection but descend to the list
              return TraversalDecision.skipButDescend;
            }
            // Include all other triples (like rdf:first values)
            return TraversalDecision.include;
          });

          // Should include only the rdf:first triples (the actual values)
          expect(filteredSubgraph.size, equals(3));
          expect(filteredSubgraph.hasTriples(predicate: first), isTrue);
          expect(filteredSubgraph.hasTriples(predicate: rest),
              isFalse); // rdf:rest triples skipped
          expect(filteredSubgraph.hasTriples(predicate: hasItems),
              isFalse); // hasItems triple skipped

          // Check we have all the list values
          expect(
              filteredSubgraph.hasTriples(
                  predicate: first, object: LiteralTerm.string('apple')),
              isTrue);
          expect(
              filteredSubgraph.hasTriples(
                  predicate: first, object: LiteralTerm.string('banana')),
              isTrue);
          expect(
              filteredSubgraph.hasTriples(
                  predicate: first, object: LiteralTerm.string('cherry')),
              isTrue);
        });

        test('should handle skipButDescend with multiple branching paths', () {
          final root = const IriTerm('http://example.com/root');
          final branch1 = const IriTerm('http://example.com/branch1');
          final branch2 = const IriTerm('http://example.com/branch2');
          final leaf1a = const IriTerm('http://example.com/leaf1a');
          final leaf1b = const IriTerm('http://example.com/leaf1b');
          final leaf2a = const IriTerm('http://example.com/leaf2a');

          final hasBranch = const IriTerm('http://example.com/hasBranch');
          final hasLeaf = const IriTerm('http://example.com/hasLeaf');
          final value = const IriTerm('http://example.com/value');

          final graph = RdfGraph(triples: [
            // Root structure
            Triple(root, hasBranch, branch1),
            Triple(root, hasBranch, branch2),

            // Branch 1
            Triple(branch1, hasLeaf, leaf1a),
            Triple(branch1, hasLeaf, leaf1b),
            Triple(branch1, value, LiteralTerm.string('Branch 1 Value')),

            // Branch 2
            Triple(branch2, hasLeaf, leaf2a),
            Triple(branch2, value, LiteralTerm.string('Branch 2 Value')),

            // Leaf values
            Triple(leaf1a, value, LiteralTerm.string('Leaf 1A Value')),
            Triple(leaf1b, value, LiteralTerm.string('Leaf 1B Value')),
            Triple(leaf2a, value, LiteralTerm.string('Leaf 2A Value')),
          ]);

          // Skip branch connections but descend to get values
          final valueOnlySubgraph =
              graph.subgraph(root, filter: (triple, depth) {
            if (triple.predicate == hasBranch || triple.predicate == hasLeaf) {
              return TraversalDecision.skipButDescend;
            }
            return TraversalDecision.include;
          });

          // Should only include value triples, not structural connections
          expect(valueOnlySubgraph.size, equals(5)); // 5 value triples
          expect(valueOnlySubgraph.hasTriples(predicate: hasBranch), isFalse);
          expect(valueOnlySubgraph.hasTriples(predicate: hasLeaf), isFalse);
          expect(valueOnlySubgraph.hasTriples(predicate: value), isTrue);

          // Check all values are present
          expect(
              valueOnlySubgraph.hasTriples(
                  object: LiteralTerm.string('Branch 1 Value')),
              isTrue);
          expect(
              valueOnlySubgraph.hasTriples(
                  object: LiteralTerm.string('Branch 2 Value')),
              isTrue);
          expect(
              valueOnlySubgraph.hasTriples(
                  object: LiteralTerm.string('Leaf 1A Value')),
              isTrue);
          expect(
              valueOnlySubgraph.hasTriples(
                  object: LiteralTerm.string('Leaf 1B Value')),
              isTrue);
          expect(
              valueOnlySubgraph.hasTriples(
                  object: LiteralTerm.string('Leaf 2A Value')),
              isTrue);
        });

        test('should handle skipButDescend with depth-based filtering', () {
          // Create a nested structure where we want to skip intermediate levels
          final root = const IriTerm('http://example.com/root');
          final level1 = const IriTerm('http://example.com/level1');
          final level2 = const IriTerm('http://example.com/level2');
          final level3 = const IriTerm('http://example.com/level3');
          final level4 = const IriTerm('http://example.com/level4');

          final connects = const IriTerm('http://example.com/connects');
          final data = const IriTerm('http://example.com/data');

          final graph = RdfGraph(triples: [
            // Connection chain
            Triple(root, connects, level1),
            Triple(level1, connects, level2),
            Triple(level2, connects, level3),
            Triple(level3, connects, level4),

            // Data at each level
            Triple(root, data, LiteralTerm.string('Root Data')),
            Triple(level1, data, LiteralTerm.string('Level 1 Data')),
            Triple(level2, data, LiteralTerm.string('Level 2 Data')),
            Triple(level3, data, LiteralTerm.string('Level 3 Data')),
            Triple(level4, data, LiteralTerm.string('Level 4 Data')),
          ]);

          // Skip connections at depth 1 and 2, but descend to get deeper data
          final depthFilteredSubgraph =
              graph.subgraph(root, filter: (triple, depth) {
            if (triple.predicate == connects && (depth == 1 || depth == 2)) {
              return TraversalDecision.skipButDescend;
            }
            return TraversalDecision.include;
          });

          // Should include: root->level1, root data, level1 data, level2 data, level3->level4, level3 data, level4 data
          expect(depthFilteredSubgraph.size, equals(7));
          expect(
              depthFilteredSubgraph.hasTriples(subject: root, predicate: data),
              isTrue);
          expect(
              depthFilteredSubgraph.hasTriples(
                  subject: root, predicate: connects),
              isTrue); // Included at depth 0
          expect(
              depthFilteredSubgraph.hasTriples(
                  subject: level1, predicate: connects),
              isFalse); // Skipped at depth 1
          expect(
              depthFilteredSubgraph.hasTriples(
                  subject: level1, predicate: data),
              isTrue); // Included at depth 1
          expect(
              depthFilteredSubgraph.hasTriples(
                  subject: level2, predicate: connects),
              isFalse); // Skipped at depth 2
          expect(
              depthFilteredSubgraph.hasTriples(
                  subject: level2, predicate: data),
              isTrue); // Included at depth 2
          expect(
              depthFilteredSubgraph.hasTriples(
                  subject: level3, predicate: connects),
              isTrue); // Included at depth 3
          expect(
              depthFilteredSubgraph.hasTriples(
                  subject: level3, predicate: data),
              isTrue);
          expect(
              depthFilteredSubgraph.hasTriples(
                  subject: level4, predicate: data),
              isTrue);
        });

        test('should handle skipButDescend in combination with other decisions',
            () {
          final root = const IriTerm('http://example.com/root');
          final skipNode = const IriTerm('http://example.com/skip');
          final skipButDescendNode =
              const IriTerm('http://example.com/skipButDescend');
          final includeNode = const IriTerm('http://example.com/include');
          final childOfSkip = const IriTerm('http://example.com/childOfSkip');
          final childOfSkipButDescend =
              const IriTerm('http://example.com/childOfSkipButDescend');
          final childOfInclude =
              const IriTerm('http://example.com/childOfInclude');

          final connects = const IriTerm('http://example.com/connects');
          final name = const IriTerm('http://xmlns.com/foaf/0.1/name');

          final graph = RdfGraph(triples: [
            Triple(root, connects, skipNode),
            Triple(root, connects, skipButDescendNode),
            Triple(root, connects, includeNode),
            Triple(skipNode, name, LiteralTerm.string('Skip Node')),
            Triple(skipNode, connects, childOfSkip),
            Triple(skipButDescendNode, name,
                LiteralTerm.string('Skip But Descend Node')),
            Triple(skipButDescendNode, connects, childOfSkipButDescend),
            Triple(includeNode, name, LiteralTerm.string('Include Node')),
            Triple(includeNode, connects, childOfInclude),
            Triple(childOfSkip, name, LiteralTerm.string('Child of Skip')),
            Triple(childOfSkipButDescend, name,
                LiteralTerm.string('Child of Skip But Descend')),
            Triple(
                childOfInclude, name, LiteralTerm.string('Child of Include')),
          ]);

          final combinedFilterSubgraph =
              graph.subgraph(root, filter: (triple, depth) {
            if (triple.object == skipNode) {
              return TraversalDecision.skip;
            } else if (triple.object == skipButDescendNode) {
              return TraversalDecision.skipButDescend;
            } else if (triple.object == includeNode) {
              return TraversalDecision.include;
            }
            return TraversalDecision.include;
          });

          // Root -> skip: nothing from this path
          expect(
              combinedFilterSubgraph.hasTriples(
                  subject: root, object: skipNode),
              isFalse);
          expect(combinedFilterSubgraph.hasTriples(subject: skipNode), isFalse);
          expect(
              combinedFilterSubgraph.hasTriples(subject: childOfSkip), isFalse);

          // Root -> skipButDescend: connection skipped but children included
          expect(
              combinedFilterSubgraph.hasTriples(
                  subject: root, object: skipButDescendNode),
              isFalse);
          expect(
              combinedFilterSubgraph.hasTriples(
                  subject: skipButDescendNode, predicate: name),
              isTrue);
          expect(
              combinedFilterSubgraph.hasTriples(
                  subject: skipButDescendNode, predicate: connects),
              isTrue);
          expect(
              combinedFilterSubgraph.hasTriples(
                  subject: childOfSkipButDescend, predicate: name),
              isTrue);

          // Root -> include: everything included
          expect(
              combinedFilterSubgraph.hasTriples(
                  subject: root, object: includeNode),
              isTrue);
          expect(
              combinedFilterSubgraph.hasTriples(
                  subject: includeNode, predicate: name),
              isTrue);
          expect(
              combinedFilterSubgraph.hasTriples(
                  subject: includeNode, predicate: connects),
              isTrue);
          expect(
              combinedFilterSubgraph.hasTriples(
                  subject: childOfInclude, predicate: name),
              isTrue);

          expect(combinedFilterSubgraph.size, equals(7));
        });

        test(
            'should handle skipButDescend with cycles and prevent infinite loops',
            () {
          final nodeA = const IriTerm('http://example.com/nodeA');
          final nodeB = const IriTerm('http://example.com/nodeB');
          final nodeC = const IriTerm('http://example.com/nodeC');

          final structural = const IriTerm('http://example.com/structural');
          final data = const IriTerm('http://example.com/data');

          // Create a cycle with structural and data relationships
          final graph = RdfGraph(triples: [
            // Structural cycle: A -> B -> C -> A
            Triple(nodeA, structural, nodeB),
            Triple(nodeB, structural, nodeC),
            Triple(nodeC, structural, nodeA),

            // Data at each node
            Triple(nodeA, data, LiteralTerm.string('Data A')),
            Triple(nodeB, data, LiteralTerm.string('Data B')),
            Triple(nodeC, data, LiteralTerm.string('Data C')),
          ]);

          final cyclicSubgraph = graph.subgraph(nodeA, filter: (triple, depth) {
            if (triple.predicate == structural) {
              return TraversalDecision.skipButDescend;
            }
            return TraversalDecision.include;
          });

          // Should include all data triples but skip structural ones
          expect(cyclicSubgraph.size, equals(3));
          expect(cyclicSubgraph.hasTriples(predicate: structural), isFalse);
          expect(cyclicSubgraph.hasTriples(predicate: data), isTrue);
          expect(
              cyclicSubgraph.hasTriples(object: LiteralTerm.string('Data A')),
              isTrue);
          expect(
              cyclicSubgraph.hasTriples(object: LiteralTerm.string('Data B')),
              isTrue);
          expect(
              cyclicSubgraph.hasTriples(object: LiteralTerm.string('Data C')),
              isTrue);
        });
      });

      group('Performance and Stress Tests', () {
        test('should handle large linear chains efficiently', () {
          final nodes =
              List.generate(100, (i) => IriTerm('http://example.com/node$i'));
          final next = const IriTerm('http://example.com/next');

          final triples = <Triple>[];
          for (int i = 0; i < nodes.length - 1; i++) {
            triples.add(Triple(nodes[i], next, nodes[i + 1]));
          }

          final graph = RdfGraph(triples: triples);
          final startTime = DateTime.now();

          final subgraph = graph.subgraph(nodes.first);

          final endTime = DateTime.now();
          final duration = endTime.difference(startTime);

          expect(subgraph.size, equals(99)); // 100 nodes, 99 connections
          expect(duration.inMilliseconds, lessThan(100)); // Should be fast
        });

        test('should handle wide trees efficiently', () {
          final root = const IriTerm('http://example.com/root');
          final hasChild = const IriTerm('http://example.com/hasChild');

          final triples = <Triple>[];
          // Create a tree with 1 root and 100 direct children
          for (int i = 0; i < 100; i++) {
            final child = IriTerm('http://example.com/child$i');
            triples.add(Triple(root, hasChild, child));

            // Each child has 10 grandchildren
            for (int j = 0; j < 10; j++) {
              final grandchild =
                  IriTerm('http://example.com/child${i}_grandchild$j');
              triples.add(Triple(child, hasChild, grandchild));
            }
          }

          final graph = RdfGraph(triples: triples);
          final startTime = DateTime.now();

          final subgraph = graph.subgraph(root);

          final endTime = DateTime.now();
          final duration = endTime.difference(startTime);

          expect(subgraph.size, equals(1100)); // 100 + 1000 connections
          expect(duration.inMilliseconds,
              lessThan(200)); // Should handle wide trees efficiently
        });

        test('should handle deep recursion with cycle detection', () {
          // Create a complex graph with multiple cycles and deep paths
          final triples = <Triple>[];
          final connects = const IriTerm('http://example.com/connects');

          // Create a grid-like structure with cycles
          for (int i = 0; i < 20; i++) {
            for (int j = 0; j < 20; j++) {
              final current = IriTerm('http://example.com/node_${i}_$j');

              // Connect to right neighbor
              if (j < 19) {
                final right = IriTerm('http://example.com/node_${i}_${j + 1}');
                triples.add(Triple(current, connects, right));
              }

              // Connect to bottom neighbor
              if (i < 19) {
                final bottom = IriTerm('http://example.com/node_${i + 1}_$j');
                triples.add(Triple(current, connects, bottom));
              }

              // Add some back-references to create cycles
              if (i > 0 && j > 0) {
                final backRef =
                    IriTerm('http://example.com/node_${i - 1}_${j - 1}');
                triples.add(Triple(current, connects, backRef));
              }
            }
          }

          final graph = RdfGraph(triples: triples);
          final startTime = DateTime.now();

          final root = const IriTerm('http://example.com/node_0_0');
          final subgraph = graph.subgraph(root);

          final endTime = DateTime.now();
          final duration = endTime.difference(startTime);

          // Should include all nodes due to cycles and connections
          expect(subgraph.size,
              greaterThan(700)); // Most triples should be reachable
          expect(duration.inMilliseconds,
              lessThan(500)); // Should handle cycles efficiently
        });
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
