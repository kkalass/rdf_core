import 'package:rdf_core/src/exceptions/rdf_exception.dart';
import 'package:rdf_core/src/exceptions/rdf_decoder_exception.dart';
import 'package:test/test.dart';

void main() {
  group('RdfDecoderException', () {
    test('constructor initializes properties correctly', () {
      const message = 'Parser error';
      const format = 'Turtle';
      final cause = Exception('IO error');
      final source = SourceLocation(line: 5, column: 10, source: 'test.ttl');

      final exception = RdfDecoderException(
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
      const exception = RdfDecoderException('Parser error', format: 'Turtle');

      expect(
        exception.toString(),
        equals('RdfDecoderException(Turtle): Parser error'),
      );
    });

    test('toString includes source when available', () {
      final source = SourceLocation(line: 5, column: 10, source: 'test.ttl');
      final exception = RdfDecoderException(
        'Parser error',
        format: 'Turtle',
        source: source,
      );

      expect(
        exception.toString(),
        equals('RdfDecoderException(Turtle): Parser error at test.ttl:6:11'),
      );
    });

    test('toString includes cause when available', () {
      final cause = Exception('IO error');
      final exception = RdfDecoderException(
        'Parser error',
        format: 'Turtle',
        cause: cause,
      );

      expect(
        exception.toString(),
        equals(
          'RdfDecoderException(Turtle): Parser error\nCaused by: Exception: IO error',
        ),
      );
    });
  });

  group('RdfSyntaxException', () {
    test('constructor initializes properties correctly', () {
      const message = 'Syntax error';
      const format = 'Turtle';
      final cause = Exception('Tokenizer error');
      final source = SourceLocation(line: 5, column: 10, source: 'test.ttl');

      final exception = RdfSyntaxException(
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
      const exception = RdfSyntaxException(
        'Missing closing bracket',
        format: 'Turtle',
      );

      expect(
        exception.toString(),
        equals('RdfSyntaxException(Turtle): Missing closing bracket'),
      );
    });

    test('toString includes source and cause when available', () {
      final cause = Exception('Tokenizer error');
      final source = SourceLocation(line: 5, column: 10, source: 'test.ttl');
      final exception = RdfSyntaxException(
        'Missing closing bracket',
        format: 'Turtle',
        cause: cause,
        source: source,
      );

      expect(
        exception.toString(),
        equals(
          'RdfSyntaxException(Turtle): Missing closing bracket at test.ttl:6:11\nCaused by: Exception: Tokenizer error',
        ),
      );
    });
  });

  group('RdfUnsupportedFeatureException', () {
    test('constructor initializes properties correctly', () {
      const message = 'Feature not implemented';
      const feature = 'Named graphs';
      const format = 'Turtle';
      final source = SourceLocation(line: 5, column: 10, source: 'test.ttl');

      final exception = RdfUnsupportedFeatureException(
        message,
        feature: feature,
        format: format,
        source: source,
      );

      expect(exception.message, equals(message));
      expect(exception.feature, equals(feature));
      expect(exception.format, equals(format));
      expect(exception.source, equals(source));
    });

    test('toString formats message correctly', () {
      const exception = RdfUnsupportedFeatureException(
        'Feature not implemented',
        feature: 'Named graphs',
        format: 'Turtle',
      );

      expect(
        exception.toString(),
        equals(
          'RdfUnsupportedFeatureException(Turtle): Named graphs - Feature not implemented',
        ),
      );
    });

    test('toString includes all components when available', () {
      final cause = Exception('Not implemented');
      final source = SourceLocation(line: 5, column: 10, source: 'test.ttl');
      final exception = RdfUnsupportedFeatureException(
        'Feature not implemented',
        feature: 'Named graphs',
        format: 'Turtle',
        cause: cause,
        source: source,
      );

      expect(
        exception.toString(),
        equals(
          'RdfUnsupportedFeatureException(Turtle): Named graphs - Feature not implemented at test.ttl:6:11\nCaused by: Exception: Not implemented',
        ),
      );
    });
  });

  group('RdfInvalidIriException', () {
    test('constructor initializes properties correctly', () {
      const message = 'Invalid IRI format';
      const iri = 'http://example.org/<invalid>';
      const format = 'Turtle';

      final exception = RdfInvalidIriException(
        message,
        iri: iri,
        format: format,
      );

      expect(exception.message, equals(message));
      expect(exception.iri, equals(iri));
      expect(exception.format, equals(format));
    });

    test('toString formats message correctly', () {
      const exception = RdfInvalidIriException(
        'Invalid IRI format',
        iri: 'http://example.org/<invalid>',
        format: 'Turtle',
      );

      expect(
        exception.toString(),
        equals(
          'RdfInvalidIriException(Turtle): Invalid IRI "http://example.org/<invalid>" - Invalid IRI format',
        ),
      );
    });

    test('toString includes all components when available', () {
      final cause = Exception('Character not allowed in IRI');
      final source = SourceLocation(line: 5, column: 10, source: 'test.ttl');
      final exception = RdfInvalidIriException(
        'Invalid IRI format',
        iri: 'http://example.org/<invalid>',
        format: 'Turtle',
        cause: cause,
        source: source,
      );

      expect(
        exception.toString(),
        equals(
          'RdfInvalidIriException(Turtle): Invalid IRI "http://example.org/<invalid>" - Invalid IRI format at test.ttl:6:11\nCaused by: Exception: Character not allowed in IRI',
        ),
      );
    });
  });
}
