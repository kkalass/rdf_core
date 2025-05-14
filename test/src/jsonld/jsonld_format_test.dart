import 'package:rdf_core/src/jsonld/jsonld_codec.dart';
import 'package:test/test.dart';

void main() {
  group('JsonLdFormat', () {
    late JsonLdGraphCodec codec;

    setUp(() {
      codec = const JsonLdGraphCodec();
    });

    test('primaryMimeType returns application/ld+json', () {
      expect(codec.primaryMimeType, equals('application/ld+json'));
    });

    test('supportedMimeTypes contains expected types', () {
      expect(
        codec.supportedMimeTypes,
        containsAll(['application/ld+json', 'application/json+ld']),
      );
      expect(codec.supportedMimeTypes.length, equals(2));
    });

    test('codec.decoder returns a JsonLdDecoder', () {
      final parser = codec.decoder;
      expect(parser, isNotNull);
      // Can't check exact type since _JsonLdParserAdapter is private
      // but we can verify its behavior
      expect(parser.toString(), contains('JsonLd'));
    });

    test('codec.encoder returns a JsonLdSerializer', () {
      final serializer = codec.encoder;
      expect(serializer, isA<JsonLdEncoder>());
    });

    group('canParse', () {
      test('returns true for valid JSON-LD object with @context', () {
        final content = '''
          {
            "@context": "http://schema.org/",
            "@type": "Person",
            "name": "John Doe"
          }
        ''';
        expect(codec.canParse(content), isTrue);
      });

      test('returns true for valid JSON-LD object with @id', () {
        final content = '''
          {
            "@id": "http://example.org/john",
            "http://xmlns.com/foaf/0.1/name": "John Doe"
          }
        ''';
        expect(codec.canParse(content), isTrue);
      });

      test('returns true for valid JSON-LD object with @type', () {
        final content = '''
          {
            "@type": "http://schema.org/Person",
            "http://xmlns.com/foaf/0.1/name": "John Doe"
          }
        ''';
        expect(codec.canParse(content), isTrue);
      });

      test('returns true for valid JSON-LD object with @graph', () {
        final content = '''
          {
            "@graph": [
              {
                "@id": "http://example.org/john",
                "http://xmlns.com/foaf/0.1/name": "John Doe"
              }
            ]
          }
        ''';
        expect(codec.canParse(content), isTrue);
      });

      test('returns true for valid JSON-LD array', () {
        final content = '''
          [
            {
              "@id": "http://example.org/john",
              "http://xmlns.com/foaf/0.1/name": "John Doe"
            }
          ]
        ''';
        expect(codec.canParse(content), isTrue);
      });

      test('returns false for non-JSON content', () {
        final content = 'This is just plain text';
        expect(codec.canParse(content), isFalse);
      });

      test('returns false for JSON without JSON-LD keywords', () {
        final content = '''
          {
            "name": "John Doe",
            "email": "john@example.org"
          }
        ''';
        expect(codec.canParse(content), isFalse);
      });

      test('handles whitespace in content correctly', () {
        final content = '''
          
          {
            "@context": "http://schema.org/",
            "@type": "Person"
          }
          
        ''';
        expect(codec.canParse(content), isTrue);
      });
    });
  });
}
