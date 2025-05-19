import 'package:rdf_core/src/graph/rdf_graph.dart';
import 'package:rdf_core/src/plugin/rdf_codec.dart';
import 'package:rdf_core/src/rdf_decoder.dart';
import 'package:rdf_core/src/rdf_encoder.dart';
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
        () => registry.getGraphCodec('application/not-registered'),
        throwsA(isA<CodecNotSupportedException>()),
      );
    });

    test('getEncoder throws when no codecs registered and none specified', () {
      // Don't register any codecs

      expect(
        () => registry.getGraphCodec(null),
        throwsA(isA<CodecNotSupportedException>()),
      );
    });
  });

  group('FormatDetectingDecoder', () {
    test('tries each format in sequence', () {
      final mockFormat1 = _MockCodec();
      final mockFormat2 = _MockCodec2();

      registry.registerGraphCodec(mockFormat1);
      registry.registerGraphCodec(mockFormat2);

      final decoder = AutoDetectingGraphDecoder(registry);
      final result = decoder.convert('dummy content');

      // Should use the second format since the first returns null
      expect(result, isA<RdfGraph>());
    });

    test('tries each format when detection fails', () {
      // Both formats return false for canParse, but one parser should work
      final undetectableFormat1 = _UndetectableButParsableCodec();
      final undetectableFormat2 = _UndetectableAndFailingCodec();

      registry.registerGraphCodec(undetectableFormat1);
      registry.registerGraphCodec(undetectableFormat2);

      final decoder = AutoDetectingGraphDecoder(registry);
      final result = decoder.convert('dummy content');

      // Should use the first format since detection fails but parsing works
      expect(result, isA<RdfGraph>());
    });

    test('throws exception when all formats fail to parse', () {
      // Register formats that all fail to parse
      final failingFormat1 = _UndetectableAndFailingCodec();
      final failingFormat2 = _AnotherFailingCodec();

      registry.registerGraphCodec(failingFormat1);
      registry.registerGraphCodec(failingFormat2);

      final decoder = AutoDetectingGraphDecoder(registry);

      expect(
        () => decoder.convert('dummy content'),
        throwsA(
          isA<CodecNotSupportedException>().having(
            (e) => e.toString(),
            'message contains last error',
            contains('Mock parsing error 2'),
          ),
        ),
      );
    });

    test('throws exception when no formats registered', () {
      // Don't register any formats
      final decoder = AutoDetectingGraphDecoder(registry);

      expect(
        () => decoder.convert('dummy content'),
        throwsA(isA<CodecNotSupportedException>()),
      );
    });
  });
}

// Mock implementations for testing

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

class _UndetectableButParsableCodec extends RdfGraphCodec {
  @override
  bool canParse(String content) => false;

  @override
  RdfGraphDecoder get decoder => _MockDecoder();

  @override
  RdfGraphEncoder get encoder => _MockEncoder();

  @override
  String get primaryMimeType => 'application/undetectable';

  @override
  Set<String> get supportedMimeTypes => {'application/undetectable'};
  @override
  RdfGraphCodec withOptions({
    RdfGraphEncoderOptions? encoder,
    RdfGraphDecoderOptions? decoder,
  }) =>
      this;
}

class _UndetectableAndFailingCodec extends RdfGraphCodec {
  @override
  bool canParse(String content) => false;

  @override
  RdfGraphDecoder get decoder => _FailingDecoder('Mock parsing error 1');

  @override
  RdfGraphEncoder get encoder => _MockEncoder();

  @override
  String get primaryMimeType => 'application/failing';

  @override
  Set<String> get supportedMimeTypes => {'application/failing'};
  @override
  RdfGraphCodec withOptions({
    RdfGraphEncoderOptions? encoder,
    RdfGraphDecoderOptions? decoder,
  }) =>
      this;
}

class _AnotherFailingCodec extends RdfGraphCodec {
  @override
  bool canParse(String content) => false;

  @override
  RdfGraphDecoder get decoder => _FailingDecoder('Mock parsing error 2');

  @override
  RdfGraphEncoder get encoder => _MockEncoder();

  @override
  String get primaryMimeType => 'application/failing2';

  @override
  Set<String> get supportedMimeTypes => {'application/failing2'};
  @override
  RdfGraphCodec withOptions({
    RdfGraphEncoderOptions? encoder,
    RdfGraphDecoderOptions? decoder,
  }) =>
      this;
}

class _MockDecoder extends RdfGraphDecoder {
  @override
  RdfGraphDecoder withOptions(RdfGraphDecoderOptions options) => this;

  @override
  RdfGraph convert(String input, {String? documentUrl}) => RdfGraph();
}

class _FailingDecoder extends RdfGraphDecoder {
  final String errorMessage;

  _FailingDecoder(this.errorMessage);
  @override
  RdfGraphDecoder withOptions(RdfGraphDecoderOptions options) => this;

  @override
  RdfGraph convert(String input, {String? documentUrl}) =>
      throw FormatException(errorMessage);
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
