import 'package:rdf_core/rdf_core.dart';
import 'package:rdf_core/src/jsonld/jsonld_parser.dart';
import 'package:rdf_core/src/jsonld/jsonld_serializer.dart';
import 'package:rdf_core/src/vocab/rdf.dart';
import 'package:test/test.dart';

void main() {
  group('JsonLd Serializer-Parser Roundtrip', () {
    test(
      'should preserve triples in roundtrip conversion with simple graph',
      () {
        // Create a simple RDF graph
        var graph = RdfGraph(
          triples: [
            Triple(
              IriTerm('http://example.org/person/alice'),
              RdfPredicates.type,
              IriTerm('http://xmlns.com/foaf/0.1/Person'),
            ),
            Triple(
              IriTerm('http://example.org/person/alice'),
              IriTerm('http://xmlns.com/foaf/0.1/name'),
              LiteralTerm.string('Alice'),
            ),
          ],
        );

        // Perform roundtrip
        final serializer = JsonLdSerializer();
        final jsonLdOutput = serializer.write(graph);

        final parser = JsonLdParser(jsonLdOutput);
        final roundtripTriples = parser.parse();

        // Create a new graph from the parsed triples
        final roundtripGraph = RdfGraph(triples: roundtripTriples);

        // Verify the graphs are equivalent
        expect(roundtripGraph.triples.length, equals(graph.triples.length));

        // Check each triple from original graph exists in roundtrip graph
        for (final triple in graph.triples) {
          final matches = roundtripGraph.findTriples(
            subject: triple.subject,
            predicate: triple.predicate,
            object: triple.object,
          );
          expect(
            matches.isNotEmpty,
            isTrue,
            reason: 'Roundtrip graph is missing triple: $triple',
          );
        }
      },
    );

    test(
      'should preserve triples in roundtrip conversion with complex graph',
      () {
        // Create a more complex RDF graph with various RDF term types
        var graph = RdfGraph(
          triples: [
            // Add person with various property types
            Triple(
              IriTerm('http://example.org/person/john'),
              RdfPredicates.type,
              IriTerm('http://xmlns.com/foaf/0.1/Person'),
            ),
            Triple(
              IriTerm('http://example.org/person/john'),
              IriTerm('http://xmlns.com/foaf/0.1/name'),
              LiteralTerm.string('John Smith'),
            ),
            Triple(
              IriTerm('http://example.org/person/john'),
              IriTerm('http://xmlns.com/foaf/0.1/age'),
              LiteralTerm.typed('42', 'integer'),
            ),
            Triple(
              IriTerm('http://example.org/person/john'),
              IriTerm('http://purl.org/dc/terms/created'),
              LiteralTerm.typed('2025-04-23T12:00:00Z', 'dateTime'),
            ),
            // Add language-tagged literals
            Triple(
              IriTerm('http://example.org/person/john'),
              IriTerm('http://xmlns.com/foaf/0.1/title'),
              LiteralTerm.withLanguage('Dr.', 'en'),
            ),
            Triple(
              IriTerm('http://example.org/person/john'),
              IriTerm('http://xmlns.com/foaf/0.1/title'),
              LiteralTerm.withLanguage('Doktor', 'de'),
            ),
            // Add boolean value
            Triple(
              IriTerm('http://example.org/person/john'),
              IriTerm('http://schema.org/active'),
              LiteralTerm.typed('true', 'boolean'),
            ),
            // Add relationship to another IRI
            Triple(
              IriTerm('http://example.org/person/john'),
              IriTerm('http://xmlns.com/foaf/0.1/knows'),
              IriTerm('http://example.org/person/jane'),
            ),
          ],
        );

        // Add blank node relationship - using a new BlankNodeTerm without label
        final addressNode = BlankNodeTerm();

        graph = graph.withTriples([
          Triple(
            IriTerm('http://example.org/person/john'),
            IriTerm('http://schema.org/address'),
            addressNode,
          ),
          Triple(
            addressNode,
            RdfPredicates.type,
            IriTerm('http://schema.org/PostalAddress'),
          ),
          Triple(
            addressNode,
            IriTerm('http://schema.org/streetAddress'),
            LiteralTerm.string('123 Main St'),
          ),
          Triple(
            addressNode,
            IriTerm('http://schema.org/postalCode'),
            LiteralTerm.string('12345'),
          ),
        ]);

        // Perform roundtrip conversion
        final serializer = JsonLdSerializer();
        final jsonLdOutput = serializer.write(
          graph,
          customPrefixes: {
            'foaf': 'http://xmlns.com/foaf/0.1/',
            'schema': 'http://schema.org/',
            'dcterms': 'http://purl.org/dc/terms/',
          },
        );

        // Print the JSON-LD for debugging if needed
        // print(jsonLdOutput);

        final parser = JsonLdParser(jsonLdOutput);
        final roundtripTriples = parser.parse();

        // Create a new graph from the parsed triples
        final roundtripGraph = RdfGraph(triples: roundtripTriples);

        // Verify the graphs have the same number of triples
        expect(roundtripGraph.triples.length, equals(graph.triples.length));

        // Since blank nodes have identity-based equality, we need to focus on the structure
        // rather than direct triple-by-triple comparison
        _compareGraphStructure(graph, roundtripGraph);
      },
    );
  });
}

/// Compares two graphs structurally, focusing on the properties of resources
/// rather than direct triple comparisons
void _compareGraphStructure(RdfGraph originalGraph, RdfGraph roundtripGraph) {
  // First verify all IRI-based triples match directly
  final directTriples = originalGraph.triples.where(
    (t) => t.subject is IriTerm && !(t.object is BlankNodeTerm),
  );

  for (final triple in directTriples) {
    final matches = roundtripGraph.findTriples(
      subject: triple.subject,
      predicate: triple.predicate,
      object: triple.object,
    );
    expect(
      matches.isNotEmpty,
      isTrue,
      reason: 'Missing direct triple: $triple',
    );
  }

  // Then verify blank node structures are preserved
  final subjectsInOriginal =
      originalGraph.triples
          .map((t) => t.subject)
          .where((s) => s is IriTerm)
          .toSet();

  for (final subject in subjectsInOriginal) {
    // For each subject in the original graph
    final blankNodeObjects =
        originalGraph
            .findTriples(subject: subject)
            .where((t) => t.object is BlankNodeTerm)
            .map((t) => t.object as BlankNodeTerm)
            .toSet();

    for (final blankNode in blankNodeObjects) {
      // Check if there's a corresponding blank node in the roundtrip graph
      final predicateToBlankNode =
          originalGraph
              .findTriples(subject: subject, object: blankNode)
              .first
              .predicate;

      final roundtripBlankNodeTriples = roundtripGraph.findTriples(
        subject: subject,
        predicate: predicateToBlankNode,
      );

      expect(roundtripBlankNodeTriples.isNotEmpty, isTrue);

      final roundtripBlankNode =
          roundtripBlankNodeTriples.first.object as BlankNodeTerm;

      // Now compare the properties of the blank nodes
      final originalProperties = originalGraph.findTriples(subject: blankNode);

      for (final prop in originalProperties) {
        final matchingProps = roundtripGraph.findTriples(
          subject: roundtripBlankNode,
          predicate: prop.predicate,
          object: prop.object is BlankNodeTerm ? null : prop.object,
        );

        expect(
          matchingProps.isNotEmpty,
          isTrue,
          reason: 'Missing property on blank node: ${prop.predicate}',
        );
      }
    }
  }
}
