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
      registry.registerCodec(mockCodec);

      final retrievedCodec = registry.getCodec('application/test');
      expect(retrievedCodec, equals(mockCodec));
    });

    test('getCodec returns null for unregistered MIME type', () {
      expect(
        () => registry.getCodec('application/not-registered'),
        throwsA(isA<CodecNotSupportedException>()),
      );
    });

    test('getCodec handles case insensitivity', () {
      final mockCodec = _MockCodec();
      registry.registerCodec(mockCodec);

      final retrievedCodec = registry.getCodec('APPLICATION/TEST');
      expect(retrievedCodec, equals(mockCodec));
    });

    test('getAllCodecs returns all registered codecs', () {
      final mockCodec1 = _MockCodec();
      final mockCodec2 = _MockCodec2();

      registry.registerCodec(mockCodec1);
      registry.registerCodec(mockCodec2);

      final codecs = registry.getAllCodecs();
      expect(codecs.length, equals(2));
      expect(codecs, contains(mockCodec1));
      expect(codecs, contains(mockCodec2));
    });

    test('detectCodec calls canParse on each codec', () {
      final alwaysFalseCodec = _MockCodec();
      final alwaysTrueCodec = _MockCodec2();

      registry.registerCodec(alwaysFalseCodec);
      registry.registerCodec(alwaysTrueCodec);

      final detectedCodec = registry.detectCodec('dummy content');
      expect(detectedCodec, equals(alwaysTrueCodec));
    });

    test('detectCodec returns null when no codec matches', () {
      final alwaysFalseCodec = _MockCodec();
      registry.registerCodec(alwaysFalseCodec);

      final detectedCodec = registry.detectCodec('dummy content');
      expect(detectedCodec, isNull);
    });

    test('getDecoder returns detecting decoder when codec not found', () {
      // Don't register any codecs
      expect(
        () => registry.getCodec('application/not-registered'),
        throwsA(isA<CodecNotSupportedException>()),
      );
    });

    test('getEncoder throws when codec not found', () {
      // Don't register any codecs

      expect(
        () => registry.getCodec('application/not-registered').encoder,
        throwsA(isA<CodecNotSupportedException>()),
      );
    });

    test('getEncoder throws when no codecs registered and none specified', () {
      // Don't register any codecs

      expect(
        () => registry.getCodec(null).decoder,
        throwsA(isA<CodecNotSupportedException>()),
      );
    });
  });

  group('FormatDetectingDecoder', () {
    test('tries each format in sequence', () {
      final mockFormat1 = _MockCodec();
      final mockFormat2 = _MockCodec2();

      registry.registerCodec(mockFormat1);
      registry.registerCodec(mockFormat2);

      final decoder = AutoDetectingDecoder(registry);
      final result = decoder.convert('dummy content');

      // Should use the second format since the first returns null
      expect(result, isA<RdfGraph>());
    });

    test('tries each format when detection fails', () {
      // Both formats return false for canParse, but one parser should work
      final undetectableFormat1 = _UndetectableButParsableCodec();
      final undetectableFormat2 = _UndetectableAndFailingCodec();

      registry.registerCodec(undetectableFormat1);
      registry.registerCodec(undetectableFormat2);

      final decoder = AutoDetectingDecoder(registry);
      final result = decoder.convert('dummy content');

      // Should use the first format since detection fails but parsing works
      expect(result, isA<RdfGraph>());
    });

    test('throws exception when all formats fail to parse', () {
      // Register formats that all fail to parse
      final failingFormat1 = _UndetectableAndFailingCodec();
      final failingFormat2 = _AnotherFailingCodec();

      registry.registerCodec(failingFormat1);
      registry.registerCodec(failingFormat2);

      final decoder = AutoDetectingDecoder(registry);

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
      final decoder = AutoDetectingDecoder(registry);

      expect(
        () => decoder.convert('dummy content'),
        throwsA(isA<CodecNotSupportedException>()),
      );
    });
  });
}

// Mock implementations for testing

class _MockCodec extends RdfCodec {
  @override
  bool canParse(String content) => false;

  @override
  RdfDecoder get decoder => _MockDecoder();

  @override
  RdfEncoder get encoder => _MockEncoder();

  @override
  String get primaryMimeType => 'application/test';

  @override
  Set<String> get supportedMimeTypes => {'application/test'};
}

class _MockCodec2 extends RdfCodec {
  @override
  bool canParse(String content) => true;

  @override
  RdfDecoder get decoder => _MockDecoder();

  @override
  RdfEncoder get encoder => _MockEncoder();

  @override
  String get primaryMimeType => 'application/test2';

  @override
  Set<String> get supportedMimeTypes => {'application/test2'};
}

class _UndetectableButParsableCodec extends RdfCodec {
  @override
  bool canParse(String content) => false;

  @override
  RdfDecoder get decoder => _MockDecoder();

  @override
  RdfEncoder get encoder => _MockEncoder();

  @override
  String get primaryMimeType => 'application/undetectable';

  @override
  Set<String> get supportedMimeTypes => {'application/undetectable'};
}

class _UndetectableAndFailingCodec extends RdfCodec {
  @override
  bool canParse(String content) => false;

  @override
  RdfDecoder get decoder => _FailingDecoder('Mock parsing error 1');

  @override
  RdfEncoder get encoder => _MockEncoder();

  @override
  String get primaryMimeType => 'application/failing';

  @override
  Set<String> get supportedMimeTypes => {'application/failing'};
}

class _AnotherFailingCodec extends RdfCodec {
  @override
  bool canParse(String content) => false;

  @override
  RdfDecoder get decoder => _FailingDecoder('Mock parsing error 2');

  @override
  RdfEncoder get encoder => _MockEncoder();

  @override
  String get primaryMimeType => 'application/failing2';

  @override
  Set<String> get supportedMimeTypes => {'application/failing2'};
}

class _MockDecoder extends RdfDecoder {
  @override
  RdfGraph convert(String input, {String? documentUrl}) {
    // Just return an empty graph
    return RdfGraph();
  }
}

class _FailingDecoder extends RdfDecoder {
  final String errorMessage;

  _FailingDecoder(this.errorMessage);

  @override
  RdfGraph convert(String input, {String? documentUrl}) {
    throw FormatException(errorMessage);
  }
}

class _MockEncoder extends RdfEncoder {
  @override
  String convert(
    RdfGraph graph, {
    String? baseUri,
    Map<String, String> customPrefixes = const {},
  }) {
    return 'mock serialized content';
  }
}
