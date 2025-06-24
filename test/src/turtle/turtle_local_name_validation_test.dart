import 'package:test/test.dart';
import 'package:rdf_core/rdf_core.dart';

void main() {
  group('Turtle Local Name Validation', () {
    test('should not generate invalid prefix:localname with dots at end', () {
      // This is the bug case: IRIs ending with dots should not use prefix notation
      final graph = RdfGraph.fromTriples([
        Triple(
          IriTerm('https://example.com/subject'),
          IriTerm('https://example.com/predicate'),
          IriTerm('https://example.com/author.me'),
        ),
      ]);

      final encoder = TurtleEncoder();
      final result = encoder.convert(graph);

      // The IRI with 'author.me' should NOT be serialized as ex:author.me
      // because 'author.me' is not a valid PN_LOCAL (dot at end is invalid)
      expect(
        result,
        contains('<https://example.com/author.me>'),
        reason: 'IRIs ending with dots should be serialized as full IRIs',
      );
      expect(
        result,
        isNot(contains('ex:author.me')),
        reason: 'Should not use prefix notation for invalid local names',
      );
    });

    test('should validate other invalid PN_LOCAL patterns', () {
      final testCases = [
        'https://example.com/test.', // dot at end
        'https://example.com/.start', // dot at start
        'https://example.com/test..double', // double dots
        'https://example.com/test-.invalid', // hyphen followed by dot
        'https://example.com/-start', // hyphen at start
      ];

      for (final iri in testCases) {
        final graph = RdfGraph.fromTriples([
          Triple(
            IriTerm('https://example.com/subject'),
            IriTerm('https://example.com/predicate'),
            IriTerm(iri),
          ),
        ]);

        final encoder = TurtleEncoder();
        final result = encoder.convert(graph);

        // All these should be serialized as full IRIs, not with prefix notation
        expect(
          result,
          contains('<$iri>'),
          reason: 'Invalid local name "$iri" should be serialized as full IRI',
        );
      }
    });

    test('should allow valid PN_LOCAL patterns with dots', () {
      final validCases = [
        'https://example.com/v1.0', // dot followed by digit
        'https://example.com/test.valid', // dot followed by letter
        'https://example.com/name.space', // dot in middle
      ];

      for (final iri in validCases) {
        final graph = RdfGraph.fromTriples([
          Triple(
            IriTerm('https://example.com/subject'),
            IriTerm('https://example.com/predicate'),
            IriTerm(iri),
          ),
        ]);

        final encoder = TurtleEncoder();
        final result = encoder.convert(graph);

        // These should be able to use prefix notation
        expect(
          result,
          contains('ex:'),
          reason: 'Valid local name in "$iri" should allow prefix notation',
        );
      }
    });
  });
}
