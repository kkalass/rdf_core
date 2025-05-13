import 'package:rdf_core/rdf_core.dart';
import 'package:test/test.dart';

// Tests for the AutoDetectingGraphCodec and AutoDetectingGraphDecoder classes
void main() {
  group('AutoDetectingGraphCodec Tests', () {
    late RdfCodecRegistry registry;
    late RdfGraphCodec defaultCodec;
    late AutoDetectingGraphCodec codec;

    setUp(() {
      registry = RdfCodecRegistry();
      defaultCodec = const TurtleCodec();
      registry.registerGraphCodec(defaultCodec);
      codec = AutoDetectingGraphCodec(
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

    test('decoder returns an AutoDetectingGraphDecoder', () {
      // Act & Assert
      expect(codec.decoder, isA<AutoDetectingGraphDecoder>());
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
      registry.registerGraphCodec(mockCodec);

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

      registry.registerGraphCodec(const TurtleCodec());
      registry.registerGraphCodec(const JsonLdGraphCodec());

      // Act & Assert - Turtle content should be parsed by the Turtle codec
      final graphFromTurtle = codec.decode(turtleContent);
      expect(graphFromTurtle.size, equals(1));
      expect(
        graphFromTurtle.triples.first.subject,
        equals(IriTerm('http://example.org/subject')),
      );

      // Act & Assert - JSON-LD content should be parsed by the JSON-LD codec
      final graphFromJsonLd = codec.decode(jsonLdContent);
      expect(graphFromJsonLd.size, equals(1));
      expect(
        graphFromJsonLd.triples.first.subject,
        equals(IriTerm('http://example.org/subject')),
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
          IriTerm('http://example.org/subject'),
          IriTerm('http://example.org/predicate'),
          LiteralTerm.string('object'),
        ),
      );

      // Act
      final encoded = codec.encode(
        graph,
        customPrefixes: {'ex': 'http://example.org/'},
      );

      // Assert - should match what the default codec (Turtle) would produce
      expect(encoded, contains('@prefix ex: <http://example.org/>'));
      expect(encoded, contains('ex:subject ex:predicate "object"'));
    });
  });

  group('AutoDetectingGraphDecoder Tests', () {
    late RdfCodecRegistry registry;
    late AutoDetectingGraphDecoder decoder;

    setUp(() {
      registry = RdfCodecRegistry();
      decoder = AutoDetectingGraphDecoder(registry);
    });

    tearDown(() {
      registry.clear();
    });

    test(
      'convert throws CodecNotSupportedException when no codecs can decode the content',
      () {
        // Act & Assert
        expect(
          () => decoder.convert('test content'),
          throwsA(isA<CodecNotSupportedException>()),
        );
      },
    );

    test('convert uses the first codec that can parse the content', () {
      // Arrange - Register Turtle and JSON-LD codecs
      registry.registerGraphCodec(const TurtleCodec());
      registry.registerGraphCodec(const JsonLdGraphCodec());

      final turtleContent =
          '@prefix ex: <http://example.org/> .\nex:subject ex:predicate "object" .';

      // Act
      final result = decoder.convert(turtleContent);

      // Assert
      expect(result, isA<RdfGraph>());
      expect(result.size, equals(1));
      expect(
        result.triples.first.subject,
        equals(IriTerm('http://example.org/subject')),
      );
    });

    test('convert propagates exceptions from the codec', () {
      // Arrange - Register a codec that will always throw an exception
      registry.registerGraphCodec(
        _MockCodec(
          canParse: true,
          willThrow: true,
          errorMessage: 'Mock parsing error',
        ),
      );

      // Act & Assert
      expect(
        () => decoder.convert('test content'),
        throwsA(
          anyOf(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains('Mock parsing error'),
            ),
            isA<CodecNotSupportedException>().having(
              (e) => e.message,
              'message',
              contains('Mock parsing error'),
            ),
          ),
        ),
      );
    });

    test('convert respects documentUrl parameter', () {
      // Arrange
      registry.registerGraphCodec(const TurtleCodec());
      final turtleWithRelativeUri =
          '<resource> <http://example.org/predicate> "object" .';

      // Act
      final result = decoder.convert(
        turtleWithRelativeUri,
        documentUrl: 'http://example.com/',
      );

      // Assert - the relative URI should be resolved against the document URL
      expect(
        result.triples.first.subject,
        equals(IriTerm('http://example.com/resource')),
      );
    });

    test('convert tries codecs in order until one succeeds', () {
      // Arrange - First codec throws, second one succeeds
      registry.registerGraphCodec(
        _MockCodec(
          canParse: true,
          willThrow: true,
          errorMessage: 'First error',
        ),
      );
      registry.registerGraphCodec(const TurtleCodec());

      final turtleContent =
          '@prefix ex: <http://example.org/> .\nex:subject ex:predicate "object" .';

      // Act
      final result = decoder.convert(turtleContent);

      // Assert - should successfully parse with the second codec
      expect(result, isA<RdfGraph>());
      expect(result.size, equals(1));
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
  }) : _canParse = canParse,
       _willThrow = willThrow,
       _errorMessage = errorMessage;

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
  String convert(
    RdfGraph graph, {
    String? baseUri,
    Map<String, String> customPrefixes = const {},
  }) {
    return 'Mock encoded content';
  }
}
