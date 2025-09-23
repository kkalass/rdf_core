import 'package:rdf_core/rdf_core.dart';
import 'package:test/test.dart';

void main() {
  late RdfCodecRegistry registry;
  late RdfCore rdf;

  setUp(() {
    // Create a fresh registry for each test
    registry = RdfCodecRegistry();
    final _namespaceMappings = const RdfNamespaceMappings();

    // Register standard formats
    registry.registerGraphCodec(
      TurtleCodec(namespaceMappings: _namespaceMappings),
    );
    registry.registerGraphCodec(
      JsonLdGraphCodec(namespaceMappings: _namespaceMappings),
    );
    registry.registerGraphCodec(const NTriplesCodec());

    rdf = RdfCore(registry: registry);
  });

  tearDown(() {
    // Clean up after each test
    registry.clear();
  });

  // Test the RdfCore functionality)

  group('RdfCore', () {
    test('withStandardCodecs registers standard codecs', () {
      // The factory constructor should pre-register standard codecs

      // Check that at least the standard codecs are registered (Turtle, JSON-LD)
      final codecs = registry.getAllGraphCodecs();
      expect(codecs.length, greaterThanOrEqualTo(2));

      // Verify we can get a decoder for Turtle
      final turtleDecoder = rdf.codec(contentType: 'text/turtle').decoder;
      expect(turtleDecoder, isNotNull);

      // Verify we can get a decoder for JSON-LD
      final jsonLdEncoder =
          rdf.codec(contentType: 'application/ld+json').encoder;
      expect(jsonLdEncoder, isNotNull);
    });

    test('registerCodec adds custom codec', () {
      final customCodec = _CustomRdfGraphCodec();

      // Register our custom codec
      registry.registerGraphCodec(customCodec);

      // Verify we can get a decoder for our custom codec
      final customDecoder =
          rdf.codec(contentType: 'application/x-custom-rdf').decoder;
      expect(customDecoder, isA<_CustomRdfDecoder>());

      // Verify we can get a encoder for our custom codec
      final customEncoder =
          rdf.codec(contentType: 'application/x-custom-rdf').encoder;
      expect(customEncoder, isA<_CustomRdfGraphEncoder>());
    });

    test('parse and encode with custom codec', () {
      final customCodec = _CustomRdfGraphCodec();
      registry.registerGraphCodec(customCodec);

      // Custom codec parsing should work
      final graph = rdf.decode(
        'custom content',
        contentType: 'application/x-custom-rdf',
      );
      expect(graph.size, equals(1));

      // Custom codec serialization should work
      final encoded = rdf.encode(
        graph,
        contentType: 'application/x-custom-rdf',
      );
      expect(encoded, equals('CUSTOM:1 triple(s)'));
    });

    test('auto-detection works with custom codec', () {
      // Register our custom codec that accepts any input
      registry.registerGraphCodec(_CustomRdfGraphCodec());

      // Custom codec should be detected
      final graph = rdf.decode('custom content');
      expect(graph.size, equals(1));
    });
  });
}

// Example of a custom codec implementation

class _CustomRdfGraphCodec extends RdfGraphCodec {
  @override
  bool canParse(String content) => true; // Accept any content for testing

  @override
  RdfGraphDecoder get decoder => _CustomRdfDecoder();

  @override
  RdfGraphEncoder get encoder => _CustomRdfGraphEncoder();

  @override
  String get primaryMimeType => 'application/x-custom-rdf';

  @override
  Set<String> get supportedMimeTypes => {
        'application/x-custom-rdf',
        'text/x-custom',
      };

  @override
  RdfGraphCodec withOptions({
    RdfGraphEncoderOptions? encoder,
    RdfGraphDecoderOptions? decoder,
  }) =>
      this;
}

class _CustomRdfDecoder extends RdfGraphDecoder {
  @override
  RdfGraph convert(String input, {String? documentUrl}) {
    // For testing, always create a graph with one triple
    final subject = const IriTerm('http://example.org/subject');
    final predicate = const IriTerm('http://example.org/predicate');
    final object = LiteralTerm.string('Custom parsed content');

    return RdfGraph(triples: [Triple(subject, predicate, object)]);
  }

  @override
  RdfGraphDecoder withOptions(RdfGraphDecoderOptions options) => this;
}

class _CustomRdfGraphEncoder extends RdfGraphEncoder {
  @override
  String convert(
    RdfGraph graph, {
    String? baseUri,
    Map<String, String> customPrefixes = const {},
  }) {
    // For testing, just return a simple string with the triple count
    return 'CUSTOM:${graph.size} triple(s)';
  }

  @override
  RdfGraphEncoder withOptions(RdfGraphEncoderOptions options) => this;
}
