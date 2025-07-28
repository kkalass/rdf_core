import 'package:test/test.dart';
import 'package:rdf_core/src/iri_compaction.dart';
import 'package:rdf_core/src/graph/rdf_graph.dart';
import 'package:rdf_core/src/graph/rdf_term.dart';
import 'package:rdf_core/src/graph/triple.dart';
import 'package:rdf_core/src/vocab/namespaces.dart';

void main() {
  group('IriCompaction', () {
    late IriCompaction compaction;
    late RdfNamespaceMappings namespaceMappings;

    setUp(() {
      namespaceMappings = RdfNamespaceMappings();
      final settings = IriCompactionSettings(
        generateMissingPrefixes: true,
        allowedCompactionTypes: allowedCompactionTypesAll,
        specialPredicates: {},
        specialDatatypes: {},
      );
      compaction = IriCompaction(
        namespaceMappings,
        settings,
        (localPart) => localPart.isNotEmpty && !localPart.contains(' '),
      );
    });

    group('compactIri', () {
      test('should compact IRI with fragment against same IRI base', () {
        // Create a simple graph with our target IRI
        final graph = RdfGraph().withTriple(Triple(
          IriTerm(
              'http://example.org/storage/solidtask/task/task456.ttl#vectorclock-user123'),
          IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#type'),
          IriTerm('http://example.org/VectorClock'),
        ));

        final baseUri = 'http://example.org/storage/solidtask/task/task456.ttl';
        final result = compaction.compactAllIris(graph, {}, baseUri: baseUri);

        final targetIri = IriTerm(
            'http://example.org/storage/solidtask/task/task456.ttl#vectorclock-user123');
        final compactedSubject = result.compactIri(targetIri, IriRole.subject);

        print('Compaction result for subject: $compactedSubject');
        print('Type: ${compactedSubject.runtimeType}');

        // Expected: should return RelativeIri('#vectorclock-user123') since only fragment differs
        expect(compactedSubject, isA<RelativeIri>());
        if (compactedSubject is RelativeIri) {
          expect(compactedSubject.relative, equals('#vectorclock-user123'));
        }
      });

      test('should prefer relative IRI over prefix when shorter', () {
        // Test the specific logic that determines when to use relative vs prefixed
        final graph = RdfGraph().withTriple(Triple(
          IriTerm(
              'http://example.org/storage/solidtask/task/task456.ttl#vectorclock-user123'),
          IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#type'),
          IriTerm('http://example.org/VectorClock'),
        ));

        // Add a custom prefix that could match
        final customPrefixes = {
          'task': 'http://example.org/storage/solidtask/task/',
        };

        final baseUri = 'http://example.org/storage/solidtask/task/task456.ttl';
        final result =
            compaction.compactAllIris(graph, customPrefixes, baseUri: baseUri);

        final targetIri = IriTerm(
            'http://example.org/storage/solidtask/task/task456.ttl#vectorclock-user123');
        final compactedSubject = result.compactIri(targetIri, IriRole.subject);

        print('Compaction result with prefix option: $compactedSubject');
        print('Type: ${compactedSubject.runtimeType}');

        // The relative form '#vectorclock-user123' should be shorter than any prefix form
        expect(compactedSubject, isA<RelativeIri>());
        if (compactedSubject is RelativeIri) {
          expect(compactedSubject.relative, equals('#vectorclock-user123'));
        }
      });

      test('should handle empty relative IRI (same as base)', () {
        final graph = RdfGraph().withTriple(Triple(
          IriTerm('http://example.org/storage/solidtask/task/task456.ttl'),
          IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#type'),
          IriTerm('http://example.org/Document'),
        ));

        final baseUri = 'http://example.org/storage/solidtask/task/task456.ttl';
        final result = compaction.compactAllIris(graph, {}, baseUri: baseUri);

        final targetIri =
            IriTerm('http://example.org/storage/solidtask/task/task456.ttl');
        final compactedSubject = result.compactIri(targetIri, IriRole.subject);

        print('Compaction result for same-as-base: $compactedSubject');
        print('Type: ${compactedSubject.runtimeType}');

        // Should return empty relative IRI
        expect(compactedSubject, isA<RelativeIri>());
        if (compactedSubject is RelativeIri) {
          expect(compactedSubject.relative, equals(''));
        }
      });
    });
  });
}
