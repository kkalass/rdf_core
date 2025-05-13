import 'package:rdf_core/rdf_core.dart';
import 'package:test/test.dart';

// Tests for edge cases and error handling with the various codecs
void main() {
  group('Codec Edge Cases and Error Handling', () {
    late RdfCore rdfCore;

    setUp(() {
      rdfCore = RdfCore.withStandardCodecs();
    });

    group('RdfCore API Edge Cases', () {
      test(
        'decode throws CodecNotSupportedException for unsupported content type',
        () {
          // Arrange
          const unsupportedType = 'application/unsupported';
          const content = 'some content';

          // Act & Assert
          expect(
            () => rdfCore.decode(content, contentType: unsupportedType),
            throwsA(isA<CodecNotSupportedException>()),
          );
        },
      );

      test(
        'encode throws CodecNotSupportedException for unsupported content type',
        () {
          // Arrange
          const unsupportedType = 'application/unsupported';
          final graph = RdfGraph();

          // Act & Assert
          expect(
            () => rdfCore.encode(graph, contentType: unsupportedType),
            throwsA(isA<CodecNotSupportedException>()),
          );
        },
      );

      test(
        'codec throws CodecNotSupportedException for unsupported content type',
        () {
          // Arrange
          const unsupportedType = 'application/unsupported';

          // Act & Assert
          expect(
            () => rdfCore.codec(unsupportedType),
            throwsA(isA<CodecNotSupportedException>()),
          );
        },
      );

      test('decode throws exception when auto-detection fails', () {
        // Arrange - content that doesn't match any known format
        const undetectableContent =
            'This is not a valid RDF document in any known format.';

        // Act & Assert
        expect(
          () => rdfCore.decode(undetectableContent),
          throwsA(isA<CodecNotSupportedException>()),
        );
      });
    });

    group('Turtle Codec Error Handling', () {
      test('decode throws FormatException for broken Turtle syntax', () {
        // Arrange - broken Turtle syntax (missing dot)
        const brokenTurtle =
            '@prefix ex: <http://example.org/> .\nex:subject ex:predicate "object"';

        // Act & Assert
        expect(
          () => rdfCore.decode(brokenTurtle, contentType: 'text/turtle'),
          throwsA(anyOf(isA<FormatException>(), isA<RdfSyntaxException>())),
        );
      });

      test('decode throws FormatException for invalid IRI in Turtle', () {
        // Arrange - Invalid IRI (missing angle bracket)
        const invalidIriTurtle =
            '<http://example.org/subject> <http://example.org/predicate> http://example.org/object> .';

        // Act & Assert
        expect(
          () => rdfCore.decode(invalidIriTurtle, contentType: 'text/turtle'),
          throwsA(anyOf(isA<FormatException>(), isA<RdfSyntaxException>())),
        );
      });

      test('decode throws FormatException for invalid literal in Turtle', () {
        // Arrange - Invalid literal (unterminated string)
        const invalidLiteralTurtle =
            '<http://example.org/subject> <http://example.org/predicate> "unterminated .';

        // Act & Assert
        expect(
          () =>
              rdfCore.decode(invalidLiteralTurtle, contentType: 'text/turtle'),
          throwsA(anyOf(isA<FormatException>(), isA<RdfSyntaxException>())),
        );
      });

      test(
        'decode throws RdfValidationException for invalid triple structure',
        () {
          // Arrange - Invalid triple structure (missing object)
          const invalidTripleTurtle =
              '<http://example.org/subject> <http://example.org/predicate> .';

          // Act & Assert
          expect(
            () =>
                rdfCore.decode(invalidTripleTurtle, contentType: 'text/turtle'),
            throwsA(anyOf(isA<FormatException>(), isA<RdfSyntaxException>())),
          );
        },
      );
    });

    group('JSON-LD Codec Error Handling', () {
      test('decode throws FormatException for broken JSON-LD syntax', () {
        // Arrange - broken JSON syntax
        const brokenJsonLd = '{ "broken": "json';

        // Act & Assert
        expect(
          () =>
              rdfCore.decode(brokenJsonLd, contentType: 'application/ld+json'),
          throwsA(anyOf(isA<FormatException>(), isA<RdfSyntaxException>())),
        );
      });

      test('decode throws FormatException for non-object/array JSON', () {
        // Arrange - JSON-LD must be an object or array at the root level
        const invalidJsonLd = '"just a string"';

        // Act & Assert
        expect(
          () =>
              rdfCore.decode(invalidJsonLd, contentType: 'application/ld+json'),
          throwsA(anyOf(isA<FormatException>(), isA<RdfSyntaxException>())),
        );
      });

      test('decode throws FormatException for invalid @id value', () {
        // Arrange - @id must be a string
        const invalidIdJsonLd =
            '{ "@id": 123, "http://example.org/predicate": "object" }';

        // Act & Assert
        expect(
          () => rdfCore.decode(
            invalidIdJsonLd,
            contentType: 'application/ld+json',
          ),
          throwsA(anyOf(isA<FormatException>(), isA<RdfSyntaxException>())),
        );
      });
    });

    group('N-Triples Codec Error Handling', () {
      test('decode throws FormatException for broken N-Triples syntax', () {
        // Arrange - broken N-Triples syntax (missing dot)
        const brokenNTriples =
            '<http://example.org/subject> <http://example.org/predicate> "object"';

        // Act & Assert
        expect(
          () => rdfCore.decode(
            brokenNTriples,
            contentType: 'application/n-triples',
          ),
          throwsA(anyOf(isA<FormatException>(), isA<RdfDecoderException>())),
        );
      });

      test('decode throws FormatException for invalid IRI in N-Triples', () {
        // Arrange - Invalid IRI (missing angle bracket)
        const invalidIriNTriples =
            '<http://example.org/subject> http://example.org/predicate> "object" .';

        // Act & Assert
        expect(
          () => rdfCore.decode(
            invalidIriNTriples,
            contentType: 'application/n-triples',
          ),
          throwsA(anyOf(isA<FormatException>(), isA<RdfDecoderException>())),
        );
      });

      test('decode throws FormatException for invalid literal in N-Triples', () {
        // Arrange - Invalid literal (unterminated string)
        const invalidLiteralNTriples =
            '<http://example.org/subject> <http://example.org/predicate> "unterminated .';

        // Act & Assert
        expect(
          () => rdfCore.decode(
            invalidLiteralNTriples,
            contentType: 'application/n-triples',
          ),
          throwsA(anyOf(isA<FormatException>(), isA<RdfDecoderException>())),
        );
      });
    });

    group('Edge Cases Across All Codecs', () {
      test('decode handles empty input correctly', () {
        // Arrange
        const emptyContent = '';

        // Act & Assert - should work for all codecs
        final turtleGraph = rdfCore.decode(
          emptyContent,
          contentType: 'text/turtle',
        );
        expect(turtleGraph.isEmpty, isTrue);

        final jsonLdGraph = rdfCore.decode(
          '{}',
          contentType: 'application/ld+json',
        );
        expect(jsonLdGraph.isEmpty, isTrue);

        final ntriplesGraph = rdfCore.decode(
          emptyContent,
          contentType: 'application/n-triples',
        );
        expect(ntriplesGraph.isEmpty, isTrue);
      });

      test('encode handles empty graph correctly', () {
        // Arrange
        final emptyGraph = RdfGraph();

        // Act & Assert - should work for all codecs
        final turtleEncoded = rdfCore.encode(
          emptyGraph,
          contentType: 'text/turtle',
        );
        expect(turtleEncoded.trim(), isEmpty);

        final jsonLdEncoded = rdfCore.encode(
          emptyGraph,
          contentType: 'application/ld+json',
        );
        expect(jsonLdEncoded, isNotEmpty); // JSON-LD produces an empty object

        final ntriplesEncoded = rdfCore.encode(
          emptyGraph,
          contentType: 'application/n-triples',
        );
        expect(ntriplesEncoded.trim(), isEmpty);
      });

      test('codecs handle Unicode characters correctly', () {
        // Arrange - graph with Unicode characters
        final graph = RdfGraph().withTriple(
          Triple(
            IriTerm('http://example.org/subject'),
            IriTerm('http://example.org/predicate'),
            LiteralTerm.string('Unicode test: 日本語 Русский العربية'),
          ),
        );

        // Act - encode and decode with each codec
        for (final mimeType in [
          'text/turtle',
          'application/ld+json',
          'application/n-triples',
        ]) {
          final encoded = rdfCore.encode(graph, contentType: mimeType);
          final decoded = rdfCore.decode(encoded, contentType: mimeType);

          // Assert
          expect(decoded.size, equals(1));
          expect(
            decoded.triples.first.object,
            equals(LiteralTerm.string('Unicode test: 日本語 Русский العربية')),
          );
        }
      });

      test('codecs handle special characters requiring escaping', () {
        // Arrange - graph with characters that need escaping
        final graph = RdfGraph().withTriple(
          Triple(
            IriTerm('http://example.org/subject'),
            IriTerm('http://example.org/predicate'),
            LiteralTerm.string('Special chars: \r\n\t"\\'),
          ),
        );

        // Act - encode and decode with each codec
        for (final mimeType in [
          'text/turtle',
          'application/ld+json',
          'application/n-triples',
        ]) {
          final encoded = rdfCore.encode(graph, contentType: mimeType);
          final decoded = rdfCore.decode(encoded, contentType: mimeType);

          // Assert
          expect(decoded.size, equals(1));
          expect(
            decoded.triples.first.object,
            equals(LiteralTerm.string('Special chars: \r\n\t"\\')),
          );
        }
      });
    });
  });
}
