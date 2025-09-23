// filepath: /Users/klaskalass/privat/rdf/rdf_core/test/src/global_convenience_variables_test.dart
import 'package:rdf_core/rdf_core.dart';
import 'package:test/test.dart';

// Tests for the global convenience variables: rdf, turtle, jsonldGraph, ntriples
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
        equals(const IriTerm('http://example.org/subject')),
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
        equals(const IriTerm('http://example.org/subject')),
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
        equals(const IriTerm('http://example.org/subject')),
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
        expect(jsonLdEncoded, contains('"@id": "ex:subject"'));
      },
    );

    test('Round-trip through different codecs preserves content', () {
      // Arrange
      final originalGraph = RdfGraph().withTriple(
        Triple(
          const IriTerm('http://example.org/subject'),
          const IriTerm('http://example.org/predicate'),
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

  group('Global Convenience Variable - turtle', () {
    test('turtle provides instance of TurtleGraphCodec', () {
      // Assert
      expect(turtle, isA<RdfGraphCodec>());
      expect(turtle.primaryMimeType, equals('text/turtle'));
    });

    test(
      'turtle encoder serializes RDF graph to Turtle format without prefix gen.',
      () {
        // Arrange
        final graph = RdfGraph().withTriple(
          Triple(
            const IriTerm('http://example.org/subject'),
            const IriTerm('http://example.org/predicate'),
            LiteralTerm.string('object'),
          ),
        );

        // Act
        final encoded = turtle.encoder
            .withOptions(TurtleEncoderOptions(generateMissingPrefixes: false))
            .convert(graph);

        // Assert
        expect(encoded, contains('<http://example.org/subject>'));
        expect(encoded, contains('<http://example.org/predicate>'));
        expect(encoded, contains('"object"'));
      },
    );

    test('turtle encoder serializes RDF graph to Turtle format', () {
      // Arrange
      final graph = RdfGraph().withTriple(
        Triple(
          const IriTerm('http://example.org/subject'),
          const IriTerm('http://example.org/predicate'),
          LiteralTerm.string('object'),
        ),
      );

      // Act
      final encoded = turtle.encoder.convert(graph);

      // Assert
      expect(encoded, contains('ex:subject'));
      expect(encoded, contains('ex:predicate'));
      expect(encoded, contains('"object"'));
    });

    test('turtle decoder parses Turtle format to RDF graph', () {
      // Arrange
      final turtleContent =
          '@prefix ex: <http://example.org/> .\nex:subject ex:predicate "object" .';

      // Act
      final graph = turtle.decoder.convert(turtleContent);

      // Assert
      expect(graph, isA<RdfGraph>());
      expect(graph.size, equals(1));
      expect(
        graph.triples.first.subject,
        equals(const IriTerm('http://example.org/subject')),
      );
    });

    test(
      'turtle encodes graphs with relative URIs when baseUri is provided',
      () {
        // Arrange
        final graph = RdfGraph().withTriple(
          Triple(
            const IriTerm('http://example.org/base/subject'),
            const IriTerm('http://example.org/predicate'),
            LiteralTerm.string('object'),
          ),
        );

        // Act - encode with baseUri
        final encoded = turtle.encoder.convert(
          graph,
          baseUri: 'http://example.org/base/',
        );

        // Assert - subject should be relative
        expect(encoded, contains('<subject>'));
        expect(encoded, contains('@base <http://example.org/base/>'));
      },
    );
    test(
      'turtle encodes graphs with relative URIs when baseUri is provided and parses back correctly',
      () {
        // Arrange
        final graph = RdfGraph().withTriple(
          Triple(
            const IriTerm('http://example.org/base/subject'),
            const IriTerm('http://example.org/predicate'),
            LiteralTerm.string('object'),
          ),
        );

        // Act - encode with baseUri
        final encoded = turtle.encoder.convert(
          graph,
          baseUri: 'http://example.org/base/',
        );
        final decoded = turtle.decoder.convert(encoded);

        // Assert - subject should be relative
        expect(graph, equals(decoded));
      },
    );
  });

  group('Global Convenience Variable - jsonldGraph', () {
    test('jsonldGraph provides instance of JsonLdGraphCodec', () {
      // Assert
      expect(jsonldGraph, isA<RdfGraphCodec>());
      expect(jsonldGraph.primaryMimeType, equals('application/ld+json'));
    });

    test(
        'jsonldGraph encoder serializes RDF graph to JSON-LD format using automatic prefix generation',
        () {
      // Arrange
      final graph = RdfGraph().withTriple(
        Triple(
          const IriTerm('http://example.org/subject'),
          const IriTerm('http://example.org/predicate'),
          LiteralTerm.string('object'),
        ),
      );

      // Act
      final encoded = jsonldGraph.encoder.convert(graph);

      // Assert
      expect(encoded, contains('"@id": "ex:subject"'));
      expect(encoded, contains('"ex:predicate": "object"'));
      expect(encoded, contains('"ex": "http://example.org/"'));

      final decoded = jsonldGraph.decoder.convert(encoded);
      expect(decoded, equals(graph));
    });

    test('jsonldGraph decoder parses JSON-LD format to RDF graph', () {
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
      final graph = jsonldGraph.decoder.convert(jsonLdContent);

      // Assert
      expect(graph, isA<RdfGraph>());
      expect(graph.size, equals(1));
      expect(
        graph.triples.first.subject,
        equals(const IriTerm('http://example.org/subject')),
      );
    });

    test('jsonldGraph handles compact IRIs', () {
      // Arrange
      final jsonLdContent = '''
      {
        "@context": {
          "schema": "https://schema.org/",
          "name": "schema:name"
        },
        "@id": "http://example.org/person/1",
        "name": "John Doe"
      }''';

      // Act
      final graph = jsonldGraph.decoder.convert(jsonLdContent);

      // Assert
      expect(graph, isA<RdfGraph>());
      expect(graph.size, equals(1));

      expect(graph.triples.first.predicate, isA<IriTerm>());
      expect(
        graph.triples.first.predicate,
        equals(const IriTerm('https://schema.org/name')),
      );
      // The object should be the string value
      expect(
        graph.triples.first.object,
        equals(LiteralTerm.string('John Doe')),
      );
    });
  });

  group('Global Convenience Variable - ntriples', () {
    test('ntriples provides instance of NTriplesCodec', () {
      // Assert
      expect(ntriples, isA<RdfGraphCodec>());
      expect(ntriples.primaryMimeType, equals('application/n-triples'));
    });

    test('ntriples encoder serializes RDF graph to N-Triples format', () {
      // Arrange
      final graph = RdfGraph().withTriple(
        Triple(
          const IriTerm('http://example.org/subject'),
          const IriTerm('http://example.org/predicate'),
          LiteralTerm.string('object'),
        ),
      );

      // Act
      final encoded = ntriples.encoder.convert(graph);

      // Assert
      expect(
        encoded.trim(),
        equals(
          '<http://example.org/subject> <http://example.org/predicate> "object" .',
        ),
      );
    });

    test('ntriples decoder parses N-Triples format to RDF graph', () {
      // Arrange
      final ntriplesContent =
          '<http://example.org/subject> <http://example.org/predicate> "object" .';

      // Act
      final graph = ntriples.decoder.convert(ntriplesContent);

      // Assert
      expect(graph, isA<RdfGraph>());
      expect(graph.size, equals(1));
      expect(
        graph.triples.first.subject,
        equals(const IriTerm('http://example.org/subject')),
      );
    });

    test('ntriples handles special characters correctly', () {
      // Arrange
      final graph = RdfGraph().withTriple(
        Triple(
          const IriTerm('http://example.org/subject'),
          const IriTerm('http://example.org/predicate'),
          LiteralTerm.string('Special chars: \r\n\t"\\'),
        ),
      );

      // Act - Round-trip test
      final encoded = ntriples.encoder.convert(graph);
      final decoded = ntriples.decoder.convert(encoded);

      // Assert
      expect(decoded.size, equals(1));
      expect(
        decoded.triples.first.object,
        equals(LiteralTerm.string('Special chars: \r\n\t"\\')),
      );
    });
  });
}
