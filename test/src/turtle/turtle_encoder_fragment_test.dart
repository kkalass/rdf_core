import 'package:rdf_core/rdf_core.dart';
import 'package:test/test.dart';

void main() {
  group('TurtleEncoder Fragment Rendering', () {
    late TurtleEncoder encoder;

    setUp(() {
      encoder = TurtleEncoder();
    });

    group('with renderFragmentsAsPrefixed: true (default)', () {
      test(
          'should render fragments as prefixed IRIs with empty prefix when using baseUri',
          () {
        // Arrange
        final graph = RdfGraph(
          triples: [
            Triple(
              const IriTerm('http://example.org/document#subject'),
              const IriTerm('http://example.org/document#predicate'),
              const IriTerm('http://example.org/document#object'),
            ),
          ],
        );

        // Act - provide baseUri that matches the fragment namespace
        final result =
            encoder.convert(graph, baseUri: 'http://example.org/document');

        // Assert
        expect(result, contains('@prefix : <#> .'));
        expect(result, contains(':subject :predicate :object .'));
        expect(result, isNot(contains('<#subject>')));
        expect(result, isNot(contains('<#predicate>')));
        expect(result, isNot(contains('<#object>')));
      });
      test(
          'should render fragments as prefixed full IRIs with empty prefix when using baseUri and custom prefix',
          () {
        // Arrange
        final graph = RdfGraph(
          triples: [
            Triple(
              const IriTerm('http://example.org/document#subject'),
              const IriTerm('http://example.org/document#predicate'),
              const IriTerm('http://example.org/document#object'),
            ),
          ],
        );

        // Act - provide baseUri that matches the fragment namespace
        final result = encoder
            .withOptions(encoder.options.copyWith(
              customPrefixes: {'': 'http://example.org/document#'},
            ))
            .convert(graph, baseUri: 'http://example.org/document');

        // Assert
        expect(result, contains('@prefix : <http://example.org/document#> .'));
        expect(result, contains(':subject :predicate :object .'));
        expect(result, isNot(contains('<#subject>')));
        expect(result, isNot(contains('<#predicate>')));
        expect(result, isNot(contains('<#object>')));
      });
      test(
          'should render fragments with normal prefixes when no matching baseUri',
          () {
        // Arrange
        final graph = RdfGraph(
          triples: [
            Triple(
              const IriTerm('http://example.org/document#subject'),
              const IriTerm('http://example.org/document#predicate'),
              const IriTerm('http://example.org/document#object'),
            ),
          ],
        );

        // Act - no baseUri provided
        final result = encoder.convert(graph);

        // Assert
        expect(result,
            contains('@prefix document: <http://example.org/document#> .'));
        expect(result,
            contains('document:subject document:predicate document:object .'));
        expect(result,
            isNot(contains('@prefix : <http://example.org/document#> .')));
      });

      test('should handle mixed fragment and non-fragment IRIs correctly', () {
        // Arrange
        final graph = RdfGraph(
          triples: [
            Triple(
              const IriTerm('http://example.org/document#subject'),
              const IriTerm('http://example.org/document#predicate'),
              const IriTerm('http://example.org/other'),
            ),
          ],
        );

        // Act
        final result =
            encoder.convert(graph, baseUri: 'http://example.org/document');

        // Assert
        expect(result, contains('@prefix : <#> .'));
        expect(result, contains(':subject :predicate <other> .'));
      });
    });

    group('with renderFragmentsAsPrefixed: false', () {
      test('should render fragments as relative IRIs when using baseUri', () {
        // Arrange
        final graph = RdfGraph(
          triples: [
            Triple(
              const IriTerm('http://example.org/document#subject'),
              const IriTerm('http://example.org/document#predicate'),
              const IriTerm('http://example.org/document#object'),
            ),
          ],
        );

        final encoderWithFragmentRelativeMode = encoder.withOptions(
          const TurtleEncoderOptions(renderFragmentsAsPrefixed: false),
        );

        // Act - provide baseUri that matches the fragment namespace
        final result = encoderWithFragmentRelativeMode.convert(graph,
            baseUri: 'http://example.org/document');

        // Assert
        expect(result, contains('<#subject> <#predicate> <#object> .'));
        expect(result,
            isNot(contains('@prefix : <http://example.org/document#> .')));
        expect(result, isNot(contains(':subject')));
        expect(result, isNot(contains(':predicate')));
        expect(result, isNot(contains(':object')));
      });

      test(
          'should render fragments as normal prefixes when no matching baseUri',
          () {
        // Arrange
        final graph = RdfGraph(
          triples: [
            Triple(
              const IriTerm('http://example.org/document#subject'),
              const IriTerm('http://example.org/document#predicate'),
              const IriTerm('http://example.org/document#object'),
            ),
          ],
        );

        final encoderWithFragmentRelativeMode = encoder.withOptions(
          const TurtleEncoderOptions(renderFragmentsAsPrefixed: false),
        );

        // Act - no baseUri provided
        final result = encoderWithFragmentRelativeMode.convert(graph);

        // Assert
        expect(result,
            contains('document:subject document:predicate document:object .'));
        expect(result, isNot(contains('<#subject>')));
      });

      test('should handle mixed fragment and non-fragment IRIs correctly', () {
        // Arrange
        final graph = RdfGraph(
          triples: [
            Triple(
              const IriTerm('http://example.org/document#subject'),
              const IriTerm('http://example.org/document#predicate'),
              const IriTerm('http://example.org/other'),
            ),
          ],
        );

        final encoderWithFragmentRelativeMode = encoder.withOptions(
          const TurtleEncoderOptions(renderFragmentsAsPrefixed: false),
        );

        // Act
        final result = encoderWithFragmentRelativeMode.convert(graph,
            baseUri: 'http://example.org/document');

        // Assert
        expect(result, contains('<#subject> <#predicate> <other> .'));
        expect(result,
            isNot(contains('@prefix : <http://example.org/document#> .')));
      });

      test('should handle non-fragment IRIs normally', () {
        // Arrange
        final graph = RdfGraph(
          triples: [
            Triple(
              const IriTerm('http://example.org/subject'),
              const IriTerm('http://example.org/predicate'),
              const IriTerm('http://example.org/object'),
            ),
          ],
        );

        final encoderWithFragmentRelativeMode = encoder.withOptions(
          const TurtleEncoderOptions(renderFragmentsAsPrefixed: false),
        );

        // Act
        final result = encoderWithFragmentRelativeMode.convert(graph);

        // Assert
        // Should use default compaction rules for non-fragment IRIs
        expect(result, contains('ex:subject ex:predicate ex:object .'));
        expect(result, contains('@prefix ex: <http://example.org/> .'));
        expect(result, isNot(contains('<#')));
      });

      test('should handle empty fragments correctly', () {
        // Arrange
        final graph = RdfGraph(
          triples: [
            Triple(
              const IriTerm('http://example.org/document#'),
              const IriTerm('http://example.org/predicate'),
              const IriTerm('http://example.org/document#object'),
            ),
          ],
        );

        final encoderWithFragmentRelativeMode = encoder.withOptions(
          const TurtleEncoderOptions(renderFragmentsAsPrefixed: false),
        );

        // Act
        final result = encoderWithFragmentRelativeMode.convert(graph,
            baseUri: 'http://example.org/document');

        // Assert
        // Empty fragment should not be treated as fragment IRI for relative rendering
        expect(result, contains('<#> <predicate> <#object> .'));
      });
    });

    group('complex scenarios', () {
      test('should handle same subject with different rendering modes', () {
        // Test the same graph with both modes to ensure they produce different output

        final graph = RdfGraph(
          triples: [
            Triple(
              const IriTerm('http://example.org/document#subject'),
              const IriTerm('http://example.org/document#predicate'),
              const IriTerm('http://example.org/document#object'),
            ),
          ],
        );

        // Test default mode (prefixed) with baseUri
        final prefixedResult =
            encoder.convert(graph, baseUri: 'http://example.org/document');
        expect(prefixedResult,
            isNot(contains('@prefix : <http://example.org/document#> .')));
        expect(prefixedResult, contains('@prefix : <#> .'));
        expect(prefixedResult, contains(':subject :predicate :object .'));

        // Test relative mode with baseUri
        final relativeEncoder = encoder.withOptions(
          TurtleEncoderOptions.from(encoder.options)
              .copyWith(renderFragmentsAsPrefixed: false),
        );
        final relativeResult = relativeEncoder.convert(graph,
            baseUri: 'http://example.org/document');
        expect(relativeResult, contains('<#subject> <#predicate> <#object> .'));
        expect(relativeResult,
            isNot(contains('@prefix : <http://example.org/document#> .')));
        expect(relativeResult, isNot(contains('@prefix : <#> .')));

        // Ensure outputs are different
        expect(prefixedResult, isNot(equals(relativeResult)));
      });
    });
  });
}
