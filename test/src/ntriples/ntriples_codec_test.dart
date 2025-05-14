import 'package:rdf_core/rdf_core.dart';
import 'package:rdf_core/src/ntriples/ntriples_codec.dart';
import 'package:rdf_core/src/rdf_decoder.dart';
import 'package:rdf_core/src/rdf_encoder.dart';
import 'package:test/test.dart';

void main() {
  group('NTriplesCodec', () {
    late NTriplesCodec codec;

    setUp(() {
      codec = const NTriplesCodec();
    });

    test('primaryMimeType returns application/n-triples', () {
      expect(codec.primaryMimeType, equals('application/n-triples'));
    });

    test('supportedMimeTypes contains expected types', () {
      expect(codec.supportedMimeTypes, contains('application/n-triples'));
    });

    test('decoder returns an NTriplesDecoder', () {
      final decoder = codec.decoder;
      expect(decoder, isA<NTriplesDecoder>());
    });

    test('encoder returns an NTriplesEncoder', () {
      final encoder = codec.encoder;
      expect(encoder, isA<NTriplesEncoder>());
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
      expect(newCodec, isA<NTriplesCodec>());
      expect(identical(newCodec, codec), isFalse); // Should be a new instance

      // Test that core properties are maintained
      expect(newCodec.primaryMimeType, equals(codec.primaryMimeType));
      expect(newCodec.supportedMimeTypes, equals(codec.supportedMimeTypes));
    });

    group('canParse', () {
      test('returns true for valid N-Triples content', () {
        final content = '''
          <http://example.org/subject> <http://example.org/predicate> "object" .
          <http://example.org/s2> <http://example.org/p2> <http://example.org/o2> .
        ''';
        expect(codec.canParse(content), isTrue);
      });

      test('returns true for N-Triples with blank nodes', () {
        final content = '''
          _:b1 <http://example.org/predicate> "object" .
          <http://example.org/subject> <http://example.org/predicate> _:b2 .
        ''';
        expect(codec.canParse(content), isTrue);
      });

      test('returns true for content with comments', () {
        final content = '''
          # This is a comment
          <http://example.org/subject> <http://example.org/predicate> "object" .
          # Another comment
          <http://example.org/s2> <http://example.org/p2> <http://example.org/o2> .
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

      test('returns false when less than 80% of lines are valid N-Triples', () {
        final content = '''
          <http://example.org/subject> <http://example.org/predicate> "object" .
          This is not a valid N-Triples line
          Neither is this
          Or this
        ''';
        expect(codec.canParse(content), isFalse);
      });
    });

    test('toString returns expected value', () {
      expect(codec.toString(), equals('NTriplesFormat()'));
    });
  });
}
