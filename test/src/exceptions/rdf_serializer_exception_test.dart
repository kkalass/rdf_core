import 'package:rdf_core/src/exceptions/rdf_exception.dart';
import 'package:rdf_core/src/exceptions/rdf_encoder_exception.dart';
import 'package:test/test.dart';

void main() {
  group('RdfEncoderException', () {
    test('constructor initializes properties correctly', () {
      const message = 'Encoder error';
      const format = 'Turtle';
      final cause = Exception('IO error');
      final source = SourceLocation(line: 5, column: 10, source: 'graph node');

      final exception = RdfEncoderException(
        message,
        format: format,
        cause: cause,
        source: source,
      );

      expect(exception.message, equals(message));
      expect(exception.format, equals(format));
      expect(exception.cause, equals(cause));
      expect(exception.source, equals(source));
    });

    test('toString formats message correctly', () {
      const exception = RdfEncoderException('Encoder error', format: 'Turtle');

      expect(
        exception.toString(),
        equals('RdfEncoderException(Turtle): Encoder error'),
      );
    });

    test('toString includes source when available', () {
      final source = SourceLocation(line: 5, column: 10, source: 'graph node');
      final exception = RdfEncoderException(
        'Encoder error',
        format: 'Turtle',
        source: source,
      );

      expect(
        exception.toString(),
        equals('RdfEncoderException(Turtle): Encoder error at graph node:6:11'),
      );
    });

    test('toString includes cause when available', () {
      final cause = Exception('IO error');
      final exception = RdfEncoderException(
        'Encoder error',
        format: 'Turtle',
        cause: cause,
      );

      expect(
        exception.toString(),
        equals(
          'RdfEncoderException(Turtle): Encoder error\nCaused by: Exception: IO error',
        ),
      );
    });
  });

  group('RdfUnsupportedEncoderFeatureException', () {
    test('constructor initializes properties correctly', () {
      const message = 'Feature cannot be encoded';
      const feature = 'Named graphs';
      const format = 'Turtle';
      final cause = Exception('Not supported');

      final exception = RdfUnsupportedEncoderFeatureException(
        message,
        feature: feature,
        format: format,
        cause: cause,
      );

      expect(exception.message, equals(message));
      expect(exception.feature, equals(feature));
      expect(exception.format, equals(format));
      expect(exception.cause, equals(cause));
    });

    test('toString formats message correctly', () {
      const exception = RdfUnsupportedEncoderFeatureException(
        'Feature cannot be encoded',
        feature: 'Named graphs',
        format: 'Turtle',
      );

      expect(
        exception.toString(),
        equals(
          'RdfUnsupportedEncoderFeatureException(Turtle): Named graphs - Feature cannot be encoded',
        ),
      );
    });

    test('toString includes all components when available', () {
      final cause = Exception('Format limitation');
      final source = SourceLocation(line: 5, column: 10, source: 'graph node');
      final exception = RdfUnsupportedEncoderFeatureException(
        'Feature cannot be encoded',
        feature: 'Named graphs',
        format: 'Turtle',
        cause: cause,
        source: source,
      );

      expect(
        exception.toString(),
        equals(
          'RdfUnsupportedEncoderFeatureException(Turtle): Named graphs - Feature cannot be encoded at graph node:6:11\nCaused by: Exception: Format limitation',
        ),
      );
    });
  });

  group('RdfCyclicGraphException', () {
    test('constructor initializes properties correctly', () {
      const message = 'Cyclic graph detected';
      const format = 'Turtle';
      final source = SourceLocation(
        line: 0,
        column: 0,
        source: 'cyclic relationship',
      );

      final exception = RdfCyclicGraphException(
        message,
        format: format,
        source: source,
      );

      expect(exception.message, equals(message));
      expect(exception.format, equals(format));
      expect(exception.source, equals(source));
    });

    test('toString formats message correctly', () {
      const exception = RdfCyclicGraphException(
        'Cyclic graph detected',
        format: 'Turtle',
      );

      expect(
        exception.toString(),
        equals('RdfCyclicGraphException(Turtle): Cyclic graph detected'),
      );
    });

    test('toString includes all components when available', () {
      final cause = Exception('Turtle does not support cycles in this context');
      final source = SourceLocation(
        line: 0,
        column: 0,
        source: 'cyclic relationship',
      );
      final exception = RdfCyclicGraphException(
        'Cyclic graph detected',
        format: 'Turtle',
        cause: cause,
        source: source,
      );

      expect(
        exception.toString(),
        equals(
          'RdfCyclicGraphException(Turtle): Cyclic graph detected at cyclic relationship:1:1\nCaused by: Exception: Turtle does not support cycles in this context',
        ),
      );
    });
  });
}
