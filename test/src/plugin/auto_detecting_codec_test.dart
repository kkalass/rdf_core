import 'package:rdf_core/rdf_core.dart';
import 'package:rdf_core/src/plugin/rdf_codec_registry.dart';
import 'package:test/test.dart';

// Tests for the AutoDetectingRdfCodec and AutoDetectingRdfDecoder classes
void main() {
  group('AutoDetectingRdfCodec Tests', () {
    late BaseRdfCodecRegistry registry;
    late RdfGraphCodec defaultCodec;
    late AutoDetectingRdfCodec codec;

    setUp(() {
      registry = BaseRdfCodecRegistry<RdfGraph>();
      defaultCodec = const TurtleCodec();
      registry.registerCodec(defaultCodec);
      codec = AutoDetectingRdfCodec(
        registry: registry,
        defaultCodec: defaultCodec,
      );
    });

    tearDown(() {
      registry.clear();
    });

    test('primaryMimeType returns the default codec\'s primary MIME type', () {
      // Act & Assert
      expect(codec.primaryMimeType, equals(defaultCodec.primaryMimeType));
    });

    test(
      'supportedMimeTypes returns the default codec\'s supported MIME types',
      () {
        // Act & Assert
        expect(
          codec.supportedMimeTypes,
          equals(defaultCodec.supportedMimeTypes),
        );
      },
    );

    test('decoder returns an AutoDetectingRdfDecoder', () {
      // Act & Assert
      expect(codec.decoder, isA<AutoDetectingRdfDecoder>());
    });

    test('encoder returns the default codec\'s encoder', () {
      // Act & Assert
      expect(
        codec.encoder.runtimeType,
        equals(defaultCodec.encoder.runtimeType),
      );
    });

    test('canParse delegates to registry.detectGraphCodec', () {
      // Arrange - add a codec that can parse the content
      final mockCodec = _MockCodec(canParse: true);
      registry.registerCodec(mockCodec);

      // Act & Assert - should return true when a codec can parse
      expect(codec.canParse('test content'), isTrue);

      // Now clear the registry and try again
      registry.clear();
      expect(codec.canParse('test content'), isFalse);
    });

    test('decode uses the first codec that can parse the content', () {
      // Arrange
      final turtleContent =
          '@prefix ex: <http://example.org/> .\nex:subject ex:predicate "object" .';
      final jsonLdContent =
          '{"@id": "http://example.org/subject", "http://example.org/predicate": "object"}';

      registry.registerCodec(const TurtleCodec());
      registry.registerCodec(const JsonLdGraphCodec());

      // Act & Assert - Turtle content should be parsed by the Turtle codec
      final graphFromTurtle = codec.decode(turtleContent);
      expect(graphFromTurtle.size, equals(1));
      expect(
        graphFromTurtle.triples.first.subject,
        equals(const IriTerm('http://example.org/subject')),
      );

      // Act & Assert - JSON-LD content should be parsed by the JSON-LD codec
      final graphFromJsonLd = codec.decode(jsonLdContent);
      expect(graphFromJsonLd.size, equals(1));
      expect(
        graphFromJsonLd.triples.first.subject,
        equals(const IriTerm('http://example.org/subject')),
      );
    });

    test(
      'decode throws CodecNotSupportedException when no codec can parse the content',
      () {
        // Act & Assert
        expect(
          () => codec.decode('not RDF content'),
          throwsA(isA<CodecNotSupportedException>()),
        );
      },
    );

    test('encode delegates to default codec\'s encoder', () {
      // Arrange
      final graph = RdfGraph().withTriple(
        Triple(
          const IriTerm('http://example.org/subject'),
          const IriTerm('http://example.org/predicate'),
          LiteralTerm.string('object'),
        ),
      );

      // Act
      final encoded = codec.encode(
        graph,
        options: RdfGraphEncoderOptions(
          customPrefixes: {'ex': 'http://example.org/'},
        ),
      );

      // Assert - should match what the default codec (Turtle) would produce
      expect(encoded, contains('@prefix ex: <http://example.org/>'));
      expect(encoded, contains('ex:subject ex:predicate "object"'));
    });

    test('withOptions creates a new codec with the provided options', () {
      // Arrange
      final encoderOptions = RdfGraphEncoderOptions(
        customPrefixes: {'ex': 'http://example.org/'},
      );
      final decoderOptions = RdfGraphDecoderOptions();

      // Act
      final newCodec = codec.withOptions(
        encoder: encoderOptions,
        decoder: decoderOptions,
      );

      // Assert
      expect(newCodec, isA<AutoDetectingRdfCodec>());
      expect(identical(newCodec, codec), isFalse); // Should be a new instance

      // Test that the options are properly applied
      final autoDetectingDecoder = newCodec.decoder as AutoDetectingRdfDecoder;
      expect(autoDetectingDecoder, isA<AutoDetectingRdfDecoder>());
    });

    test('encoder respects encoder options when provided', () {
      // Arrange
      final encoderOptions = RdfGraphEncoderOptions(
        customPrefixes: {'ex': 'http://example.org/'},
      );

      // Act
      final newCodec = codec.withOptions(encoder: encoderOptions);
      final encoder = newCodec.encoder;

      // Assert
      expect(encoder, isNotNull);
      // While we can't directly access the internal options, we can verify
      // that a new encoder instance was created
      expect(identical(encoder, codec.encoder), isFalse);
    });
  });

  group('AutoDetectingRdfDecoder Tests', () {
    late BaseRdfCodecRegistry registry;
    late AutoDetectingRdfDecoder decoder;

    setUp(() {
      registry = BaseRdfCodecRegistry<RdfGraph>();
      registry.registerCodec(const TurtleCodec());
      registry.registerCodec(const NTriplesCodec());
      decoder = AutoDetectingRdfDecoder(registry);
    });

    tearDown(() {
      registry.clear();
    });

    test('withOptions creates a new decoder with provided options', () {
      // Arrange
      final options = RdfGraphDecoderOptions();

      // Act
      final newDecoder = decoder.withOptions(options);

      // Assert
      expect(newDecoder, isA<AutoDetectingRdfDecoder>());
      expect(
        identical(newDecoder, decoder),
        isFalse,
      ); // Should be a new instance
    });

    test('convert method delegates to detected codec decoder', () {
      // Arrange
      final turtleContent =
          '@prefix ex: <http://example.org/> .\nex:subject ex:predicate "object" .';

      // Act
      final result = decoder.convert(turtleContent);

      // Assert
      expect(result, isA<RdfGraph>());
      expect(result.size, equals(1));
    });

    test('convert method tries all codecs when detection fails', () {
      // Arrange - create content without clear format markers but valid as Turtle
      final ambiguousContent =
          '<http://example.org/subject> <http://example.org/predicate> "object" .';

      // Act
      final result = decoder.convert(ambiguousContent);

      // Assert
      expect(result, isA<RdfGraph>());
      expect(result.size, equals(1));
    });

    test('convert method throws when all codecs fail', () {
      // Arrange
      final invalidContent = 'This is not a valid RDF format in any codec';

      // Act & Assert
      expect(
        () => decoder.convert(invalidContent),
        throwsA(isA<CodecNotSupportedException>()),
      );
    });
  });
}

/// Mock implementation of RdfGraphCodec for testing
class _MockCodec extends RdfGraphCodec {
  final bool _canParse;
  final bool _willThrow;
  final String _errorMessage;

  _MockCodec({
    bool canParse = false,
    bool willThrow = false,
    String errorMessage = 'Mock error',
  })  : _canParse = canParse,
        _willThrow = willThrow,
        _errorMessage = errorMessage;

  @override
  RdfGraphCodec withOptions({
    RdfGraphEncoderOptions? encoder,
    RdfGraphDecoderOptions? decoder,
  }) =>
      this;

  @override
  bool canParse(String content) => _canParse;

  @override
  RdfGraphDecoder get decoder => _MockDecoder(_willThrow, _errorMessage);

  @override
  RdfGraphEncoder get encoder => _MockEncoder();

  @override
  String get primaryMimeType => 'application/x-mock';

  @override
  Set<String> get supportedMimeTypes => {'application/x-mock'};
}

/// Mock implementation of RdfGraphDecoder for testing
class _MockDecoder extends RdfGraphDecoder {
  final bool _willThrow;
  final String _errorMessage;

  _MockDecoder(this._willThrow, this._errorMessage);

  @override
  RdfGraphDecoder withOptions(RdfGraphDecoderOptions options) => this;

  @override
  RdfGraph convert(String input, {String? documentUrl}) {
    if (_willThrow) {
      throw FormatException(_errorMessage);
    }

    // Default implementation - return an empty graph
    return RdfGraph();
  }
}

/// Mock implementation of RdfGraphEncoder for testing
class _MockEncoder extends RdfGraphEncoder {
  @override
  RdfGraphEncoder withOptions(RdfGraphEncoderOptions options) => this;

  @override
  String convert(
    RdfGraph graph, {
    String? baseUri,
    Map<String, String> customPrefixes = const {},
  }) {
    return 'Mock encoded content';
  }
}
