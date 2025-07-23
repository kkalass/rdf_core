import 'package:rdf_core/rdf_core.dart';
import 'package:test/test.dart';

// Tests for the RdfCore class
void main() {
  group('RdfCore Class Tests', () {
    late RdfCodecRegistry registry;

    setUp(() {
      registry = RdfCodecRegistry();
    });

    tearDown(() {
      registry.clear();
    });

    test('constructor creates instance with provided registry', () {
      // Act
      final rdfCore = RdfCore(registry: registry);

      // Assert
      expect(rdfCore, isA<RdfCore>());
    });

    group('Factory Methods', () {
      test('withStandardCodecs registers standard codecs', () {
        // Act
        final rdfCore = RdfCore.withStandardCodecs();

        // Assert - we should find Turtle, JSON-LD, and N-Triples codecs
        expect(
          () => rdfCore.codec(contentType: 'text/turtle'),
          returnsNormally,
        );
        expect(
          () => rdfCore.codec(contentType: 'application/ld+json'),
          returnsNormally,
        );
        expect(
          () => rdfCore.codec(contentType: 'application/n-triples'),
          returnsNormally,
        );
      });

      test(
        'withStandardCodecs with additionalCodecs registers those codecs',
        () {
          // Arrange
          final customCodec = _CustomRdfGraphCodec();

          // Act
          final rdfCore = RdfCore.withStandardCodecs(
            additionalCodecs: [customCodec],
          );

          // Assert - we should find the standard codecs plus our custom one
          expect(
            () => rdfCore.codec(contentType: 'text/turtle'),
            returnsNormally,
          );
          expect(
            () => rdfCore.codec(contentType: 'application/ld+json'),
            returnsNormally,
          );
          expect(
            () => rdfCore.codec(contentType: 'application/n-triples'),
            returnsNormally,
          );
          expect(
            () => rdfCore.codec(contentType: 'application/x-custom-rdf'),
            returnsNormally,
          );
        },
      );

      test('withCodecs registers only the provided codecs', () {
        // Arrange
        final customCodec = _CustomRdfGraphCodec();

        // Act
        final rdfCore = RdfCore.withCodecs(codecs: [customCodec]);

        // Assert - we should find only our custom codec
        expect(
          () => rdfCore.codec(contentType: 'application/x-custom-rdf'),
          returnsNormally,
        );
        expect(
          () => rdfCore.codec(contentType: 'text/turtle'),
          throwsA(isA<CodecNotSupportedException>()),
        );
      });
    });

    group('Codec Methods', () {
      late RdfCore rdfCore;

      setUp(() {
        rdfCore = RdfCore.withStandardCodecs();
      });

      test('codec returns the correct codec for a content type', () {
        // Act & Assert
        expect(rdfCore.codec(contentType: 'text/turtle'), isA<TurtleCodec>());
        expect(
          rdfCore.codec(contentType: 'application/ld+json'),
          isA<JsonLdGraphCodec>(),
        );
        expect(
          rdfCore.codec(contentType: 'application/n-triples'),
          isA<NTriplesCodec>(),
        );
      });

      test('codec handles case-insensitive content types', () {
        // Act & Assert
        expect(rdfCore.codec(contentType: 'TEXT/TURTLE'), isA<TurtleCodec>());
        expect(
          rdfCore.codec(contentType: 'Application/LD+JSON'),
          isA<JsonLdGraphCodec>(),
        );
      });

      test('codec throws for unsupported content type', () {
        // Act & Assert
        expect(
          () => rdfCore.codec(contentType: 'application/unsupported'),
          throwsA(isA<CodecNotSupportedException>()),
        );
      });
    });

    group('Encode/Decode Methods', () {
      late RdfCore rdfCore;

      setUp(() {
        rdfCore = RdfCore.withStandardCodecs();
      });

      test('decode method properly decodes RDF content with content type', () {
        // Arrange
        final turtleContent =
            '@prefix ex: <http://example.org/> .\nex:subject ex:predicate "object" .';

        // Act
        final graph = rdfCore.decode(turtleContent, contentType: 'text/turtle');

        // Assert
        expect(graph, isA<RdfGraph>());
        expect(graph.size, equals(1));
        expect(
          graph.triples.first.subject,
          equals(IriTerm('http://example.org/subject')),
        );
        expect(
          graph.triples.first.predicate,
          equals(IriTerm('http://example.org/predicate')),
        );
        expect(
          graph.triples.first.object,
          equals(LiteralTerm.string('object')),
        );
      });

      test(
        'decode method auto-detects format when contentType is not provided',
        () {
          // Arrange
          final turtleContent =
              '@prefix ex: <http://example.org/> .\nex:subject ex:predicate "object" .';

          // Act
          final graph = rdfCore.decode(turtleContent);

          // Assert
          expect(graph, isA<RdfGraph>());
          expect(graph.size, equals(1));
        },
      );

      test('decode method passes documentUrl to the codec', () {
        // Arrange
        final contentWithRelativeUri =
            '<resource> <http://example.org/predicate> "object" .';
        final baseUrl = 'http://example.com/';

        // Act
        final graph = rdfCore.decode(
          contentWithRelativeUri,
          contentType: 'text/turtle',
          documentUrl: baseUrl,
        );

        // Assert - the relative URI should be resolved against the document URL
        expect(
          graph.triples.first.subject,
          equals(IriTerm('http://example.com/resource')),
        );
      });

      test('encode method properly encodes RDF graph with content type', () {
        // Arrange
        final graph = RdfGraph();
        final subject = IriTerm('http://example.org/subject');
        final predicate = IriTerm('http://example.org/predicate');
        final object = LiteralTerm.string('object');
        final triple = Triple(subject, predicate, object);
        final graphWithTriple = graph.withTriple(triple);

        // Act
        final encoded = rdfCore.encode(
          graphWithTriple,
          contentType: 'text/turtle',
          options: RdfGraphEncoderOptions(
            customPrefixes: {'ex': 'http://example.org/'},
          ),
        );

        // Assert
        expect(encoded, contains('@prefix ex: <http://example.org/>'));
        expect(encoded, contains('ex:subject ex:predicate "object"'));
      });

      test('encode method uses baseUri when provided', () {
        // Arrange
        final graph = RdfGraph();
        final subject = IriTerm('http://example.com/resource');
        final predicate = IriTerm('http://example.org/predicate');
        final object = LiteralTerm.string('object');
        final triple = Triple(subject, predicate, object);
        final graphWithTriple = graph.withTriple(triple);

        // Act
        final encoded = rdfCore.encode(
          graphWithTriple,
          contentType: 'text/turtle',
          baseUri: 'http://example.com/',
          options: TurtleEncoderOptions(
            customPrefixes: {'ex': 'http://example.org/'},
          ),
        );

        // Assert - should use the base URI to produce more compact output
        expect(encoded, contains('@base <http://example.com/>'));
        expect(encoded, contains('<resource> ex:predicate "object"'));
      });

      test(
        'encode method defaults to Turtle when no contentType is provided',
        () {
          // Arrange
          final graph = RdfGraph().withTriple(
            Triple(
              IriTerm('http://example.org/subject'),
              IriTerm('http://example.org/predicate'),
              LiteralTerm.string('object'),
            ),
          );

          // Act
          final encoded = rdfCore.encode(graph);

          // Assert - should be Turtle syntax
          expect(encoded, contains('ex:subject ex:predicate "object"'));
        },
      );
    });
  });
}

/// Custom implementation of RdfGraphCodec for testing purposes
class _CustomRdfGraphCodec extends RdfGraphCodec {
  @override
  bool canParse(String content) => content.contains('CUSTOM-FORMAT');

  @override
  RdfGraphDecoder get decoder => _CustomRdfGraphDecoder();

  @override
  RdfGraphEncoder get encoder => _CustomRdfGraphEncoder();

  @override
  String get primaryMimeType => 'application/x-custom-rdf';

  @override
  Set<String> get supportedMimeTypes => {'application/x-custom-rdf'};

  @override
  RdfGraphCodec withOptions({
    RdfGraphEncoderOptions? encoder,
    RdfGraphDecoderOptions? decoder,
  }) =>
      this;
}

/// Custom implementation of RdfGraphDecoder for testing purposes
class _CustomRdfGraphDecoder extends RdfGraphDecoder {
  @override
  RdfGraph convert(String input, {String? documentUrl}) {
    // For testing, just create a simple graph with one triple
    final graph = RdfGraph();
    final triple = Triple(
      IriTerm('http://example.org/custom-subject'),
      IriTerm('http://example.org/custom-predicate'),
      LiteralTerm.string('custom-object'),
    );
    return graph.withTriple(triple);
  }

  @override
  RdfGraphDecoder withOptions(RdfGraphDecoderOptions options) => this;
}

/// Custom implementation of RdfGraphEncoder for testing purposes
class _CustomRdfGraphEncoder extends RdfGraphEncoder {
  @override
  String convert(
    RdfGraph graph, {
    String? baseUri,
    Map<String, String> customPrefixes = const {},
  }) {
    return 'CUSTOM-FORMAT:${graph.size} triple(s)';
  }

  @override
  RdfGraphEncoder withOptions(RdfGraphEncoderOptions options) => this;
}
