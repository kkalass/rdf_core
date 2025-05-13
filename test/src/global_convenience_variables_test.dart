import 'package:rdf_core/rdf_core.dart';
import 'package:test/test.dart';

// Tests for the global convenience variable 'rdf'
void main() {
  group('Global Convenience Variable - rdf', () {
    test('rdf provides an instance of RdfCore with standard codecs', () {
      // Assert
      expect(rdf, isA<RdfCore>());
    });

    test('rdf supports Turtle codec', () {
      // Arrange
      final turtleContent =
          '@prefix ex: <http://example.org/> .\nex:subject ex:predicate "object" .';

      // Act
      final graph = rdf.decode(turtleContent, contentType: 'text/turtle');

      // Assert
      expect(graph, isA<RdfGraph>());
      expect(graph.size, equals(1));
      expect(
        graph.triples.first.subject,
        equals(IriTerm('http://example.org/subject')),
      );
    });

    test('rdf supports JSON-LD codec', () {
      // Arrange
      final jsonLdContent = '''
      {
        "@context": {
          "ex": "http://example.org/"
        },
        "@id": "ex:subject",
        "ex:predicate": "object"
      }''';

      // Act
      final graph = rdf.decode(
        jsonLdContent,
        contentType: 'application/ld+json',
      );

      // Assert
      expect(graph, isA<RdfGraph>());
      expect(graph.size, equals(1));
      expect(
        graph.triples.first.subject,
        equals(IriTerm('http://example.org/subject')),
      );
    });

    test('rdf supports N-Triples codec', () {
      // Arrange
      final ntriplesContent =
          '<http://example.org/subject> <http://example.org/predicate> "object" .';

      // Act
      final graph = rdf.decode(
        ntriplesContent,
        contentType: 'application/n-triples',
      );

      // Assert
      expect(graph, isA<RdfGraph>());
      expect(graph.size, equals(1));
      expect(
        graph.triples.first.subject,
        equals(IriTerm('http://example.org/subject')),
      );
    });

    test('rdf has auto-detection capability', () {
      // Arrange
      final turtleContent =
          '@prefix ex: <http://example.org/> .\nex:subject ex:predicate "object" .';
      final jsonLdContent = '''
      {
        "@context": {
          "ex": "http://example.org/"
        },
        "@id": "ex:subject",
        "ex:predicate": "object"
      }''';
      final ntriplesContent =
          '<http://example.org/subject> <http://example.org/predicate> "object" .';

      // Act & Assert - Turtle auto-detection
      final graphFromTurtle = rdf.decode(turtleContent);
      expect(graphFromTurtle, isA<RdfGraph>());
      expect(graphFromTurtle.size, equals(1));

      // Act & Assert - JSON-LD auto-detection
      final graphFromJsonLd = rdf.decode(jsonLdContent);
      expect(graphFromJsonLd, isA<RdfGraph>());
      expect(graphFromJsonLd.size, equals(1));

      // Act & Assert - N-Triples auto-detection
      final graphFromNTriples = rdf.decode(ntriplesContent);
      expect(graphFromNTriples, isA<RdfGraph>());
      expect(graphFromNTriples.size, equals(1));
    });

    test(
      'Cross-codec compatibility - decode with one codec and encode with another',
      () {
        // Arrange
        final turtleContent =
            '@prefix ex: <http://example.org/> .\nex:subject ex:predicate "object" .';

        // Act - decode with Turtle and encode with N-Triples
        final graph = rdf.decode(turtleContent, contentType: 'text/turtle');
        final ntriplesEncoded = rdf.encode(
          graph,
          contentType: 'application/n-triples',
        );

        // Assert
        expect(
          ntriplesEncoded,
          contains(
            '<http://example.org/subject> <http://example.org/predicate> "object" .',
          ),
        );

        // Act - decode with N-Triples and encode with JSON-LD
        final ntriplesContent =
            '<http://example.org/subject> <http://example.org/predicate> "object" .';
        final graphFromNTriples = rdf.decode(
          ntriplesContent,
          contentType: 'application/n-triples',
        );
        final jsonLdEncoded = rdf.encode(
          graphFromNTriples,
          contentType: 'application/ld+json',
        );

        // Assert
        expect(jsonLdEncoded, contains('"@id": "http://example.org/subject"'));
      },
    );

    test('Round-trip through different codecs preserves content', () {
      // Arrange
      final originalGraph = RdfGraph().withTriple(
        Triple(
          IriTerm('http://example.org/subject'),
          IriTerm('http://example.org/predicate'),
          LiteralTerm.string(
            'object with "quotes" and special chars: éñçödîñg',
          ),
        ),
      );

      // Act - encode with Turtle
      final turtleEncoded = rdf.encode(
        originalGraph,
        contentType: 'text/turtle',
      );

      // Decode Turtle
      final graphFromTurtle = rdf.decode(
        turtleEncoded,
        contentType: 'text/turtle',
      );

      // Encode with JSON-LD
      final jsonLdEncoded = rdf.encode(
        graphFromTurtle,
        contentType: 'application/ld+json',
      );

      // Decode JSON-LD
      final graphFromJsonLd = rdf.decode(
        jsonLdEncoded,
        contentType: 'application/ld+json',
      );

      // Encode with N-Triples
      final ntriplesEncoded = rdf.encode(
        graphFromJsonLd,
        contentType: 'application/n-triples',
      );

      // Decode N-Triples
      final finalGraph = rdf.decode(
        ntriplesEncoded,
        contentType: 'application/n-triples',
      );

      // Assert - the original graph should be preserved through all these conversions
      expect(finalGraph.size, equals(originalGraph.size));
      expect(
        finalGraph.triples.first.subject,
        equals(originalGraph.triples.first.subject),
      );
      expect(
        finalGraph.triples.first.predicate,
        equals(originalGraph.triples.first.predicate),
      );
      expect(
        finalGraph.triples.first.object,
        equals(originalGraph.triples.first.object),
      );
    });
  });
}
