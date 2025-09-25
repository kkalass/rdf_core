import 'package:rdf_core/rdf_core.dart';
import 'package:test/test.dart';

void main() {
  group('NQuadsCodec', () {
    late NQuadsCodec codec;

    setUp(() {
      codec = const NQuadsCodec();
    });

    test('primaryMimeType returns application/n-quads', () {
      expect(codec.primaryMimeType, equals('application/n-quads'));
    });

    test('supportedMimeTypes contains expected types', () {
      expect(codec.supportedMimeTypes, contains('application/n-quads'));
    });

    test('decoder returns an NQuadsDecoder', () {
      final decoder = codec.decoder;
      expect(decoder, isA<NQuadsDecoder>());
    });

    test('encoder returns an NQuadsEncoder', () {
      final encoder = codec.encoder;
      expect(encoder, isA<NQuadsEncoder>());
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
      expect(newCodec, isA<NQuadsCodec>());
      expect(identical(newCodec, codec), isFalse); // Should be a new instance

      // Test that core properties are maintained
      expect(newCodec.primaryMimeType, equals(codec.primaryMimeType));
      expect(newCodec.supportedMimeTypes, equals(codec.supportedMimeTypes));
    });

    group('canParse', () {
      test('returns true for valid N-Quads content with default graph only', () {
        final content = '''
          <http://example.org/subject> <http://example.org/predicate> "object" .
          <http://example.org/s2> <http://example.org/p2> <http://example.org/o2> .
        ''';
        expect(codec.canParse(content), isTrue);
      });

      test('returns true for N-Quads with named graphs', () {
        final content = '''
          <http://example.org/subject> <http://example.org/predicate> "object" <http://example.org/graph1> .
          <http://example.org/s2> <http://example.org/p2> <http://example.org/o2> .
          <http://example.org/s3> <http://example.org/p3> <http://example.org/o3> <http://example.org/graph2> .
        ''';
        expect(codec.canParse(content), isTrue);
      });

      test('returns true for N-Quads with blank nodes', () {
        final content = '''
          _:b1 <http://example.org/predicate> "object" .
          <http://example.org/subject> <http://example.org/predicate> _:b2 <http://example.org/graph1> .
        ''';
        expect(codec.canParse(content), isTrue);
      });

      test('returns true for content with comments', () {
        final content = '''
          # This is a comment
          <http://example.org/subject> <http://example.org/predicate> "object" .
          # Another comment
          <http://example.org/s2> <http://example.org/p2> <http://example.org/o2> <http://example.org/graph1> .
        ''';
        expect(codec.canParse(content), isTrue);
      });

      test('returns false for empty content', () {
        expect(codec.canParse(''), isFalse);
        expect(codec.canParse('   \n  \t  '), isFalse);
      });

      test('returns false for Turtle content', () {
        final content = '''
          @prefix ex: <http://example.org/> .
          ex:subject ex:predicate "object" .
        ''';
        expect(codec.canParse(content), isFalse);
      });

      test('returns false for JSON-LD content', () {
        final content = '''
          {
            "@id": "http://example.org/subject",
            "http://example.org/predicate": "object"
          }
        ''';
        expect(codec.canParse(content), isFalse);
      });

      test('returns false when less than 80% of lines are valid N-Quads', () {
        final content = '''
          <http://example.org/subject> <http://example.org/predicate> "object" .
          This is not a valid N-Quads line
          Neither is this
          Or this
        ''';
        expect(codec.canParse(content), isFalse);
      });
    });

    test('toString returns expected value', () {
      expect(codec.toString(), equals('NQuadsFormat()'));
    });
  });
}