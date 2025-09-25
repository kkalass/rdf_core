import 'package:rdf_core/rdf_core.dart';
import 'package:test/test.dart';

void main() {
  final registry = RdfCodecRegistry();

  setUp(() {
    // Clear the registry before each test
    registry.clear();
  });

  group('RdfCodecRegistry', () {
    test('registerCodec adds codec to registry', () {
      final mockCodec = _MockCodec();
      registry.registerGraphCodec(mockCodec);

      final retrievedCodec = registry.getGraphCodec('application/test');
      expect(retrievedCodec, equals(mockCodec));
    });

    test('getCodec returns null for unregistered MIME type', () {
      expect(
        () => registry.getGraphCodec('application/not-registered'),
        throwsA(isA<CodecNotSupportedException>()),
      );
    });

    test('getCodec handles case insensitivity', () {
      final mockCodec = _MockCodec();
      registry.registerGraphCodec(mockCodec);

      final retrievedCodec = registry.getGraphCodec('APPLICATION/TEST');
      expect(retrievedCodec, equals(mockCodec));
    });

    test('getAllCodecs returns all registered codecs', () {
      final mockCodec1 = _MockCodec();
      final mockCodec2 = _MockCodec2();

      registry.registerGraphCodec(mockCodec1);
      registry.registerGraphCodec(mockCodec2);

      final codecs = registry.getAllGraphCodecs();
      expect(codecs.length, equals(2));
      expect(codecs, contains(mockCodec1));
      expect(codecs, contains(mockCodec2));
    });

    test('detectCodec calls canParse on each codec', () {
      final alwaysFalseCodec = _MockCodec();
      final alwaysTrueCodec = _MockCodec2();

      registry.registerGraphCodec(alwaysFalseCodec);
      registry.registerGraphCodec(alwaysTrueCodec);

      final detectedCodec = registry.detectGraphCodec('dummy content');
      expect(detectedCodec, equals(alwaysTrueCodec));
    });

    test('detectCodec returns null when no codec matches', () {
      final alwaysFalseCodec = _MockCodec();
      registry.registerGraphCodec(alwaysFalseCodec);

      final detectedCodec = registry.detectGraphCodec('dummy content');
      expect(detectedCodec, isNull);
    });

    test('getDecoder returns detecting decoder when codec not found', () {
      // Don't register any codecs
      expect(
        () => registry.getGraphCodec('application/not-registered'),
        throwsA(isA<CodecNotSupportedException>()),
      );
    });

    test('getEncoder throws when codec not found', () {
      // Don't register any codecs

      expect(
        () => registry.getGraphCodec('application/not-registered').encoder,
        throwsA(isA<CodecNotSupportedException>()),
      );
    });

    test('getEncoder throws when no codecs registered and none specified', () {
      // Don't register any codecs

      expect(
        () => registry.getGraphCodec(null).decoder,
        throwsA(isA<CodecNotSupportedException>()),
      );
    });
  });
}

// Mock implementations for testing

class _MockDecoder extends RdfGraphDecoder {
  @override
  RdfGraphDecoder withOptions(RdfGraphDecoderOptions options) => this;
  @override
  RdfGraph convert(String input, {String? documentUrl}) =>
      // Just return an empty graph
      RdfGraph();
}

class _MockCodec extends RdfGraphCodec {
  @override
  bool canParse(String content) => false;

  @override
  RdfGraphDecoder get decoder => _MockDecoder();

  @override
  RdfGraphEncoder get encoder => _MockEncoder();

  @override
  String get primaryMimeType => 'application/test';

  @override
  Set<String> get supportedMimeTypes => {'application/test'};

  @override
  RdfGraphCodec withOptions({
    RdfGraphEncoderOptions? encoder,
    RdfGraphDecoderOptions? decoder,
  }) =>
      this;
}

class _MockCodec2 extends RdfGraphCodec {
  @override
  bool canParse(String content) => true;

  @override
  RdfGraphDecoder get decoder => _MockDecoder();

  @override
  RdfGraphEncoder get encoder => _MockEncoder();

  @override
  String get primaryMimeType => 'application/test2';

  @override
  Set<String> get supportedMimeTypes => {'application/test2'};

  @override
  RdfGraphCodec withOptions({
    RdfGraphEncoderOptions? encoder,
    RdfGraphDecoderOptions? decoder,
  }) =>
      this;
}

class _MockEncoder extends RdfGraphEncoder {
  @override
  RdfGraphEncoder withOptions(RdfGraphEncoderOptions options) => this;

  @override
  String convert(
    RdfGraph graph, {
    String? baseUri,
    Map<String, String> customPrefixes = const {},
  }) =>
      'mock serialized content';
}
