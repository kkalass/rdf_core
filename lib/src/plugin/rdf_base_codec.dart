import 'dart:convert';

import 'package:rdf_core/rdf_core.dart';

abstract class RdfCodec<G> extends Codec<G, String> {
  /// The primary MIME type for this codec
  ///
  /// This is the canonical MIME type used to identify the codec,
  /// typically the one registered with IANA.
  String get primaryMimeType;

  /// All MIME types supported by this codec
  ///
  /// Some codecs may have multiple MIME types associated with them,
  /// including older or deprecated ones. This set should include all
  /// MIME types that the codec implementation can handle.
  Set<String> get supportedMimeTypes;

  /// Creates a decoder instance for this codec
  ///
  /// Returns a new instance of a decoder that can convert text in this codec's format
  /// to an RdfGraph object.
  @override
  RdfDecoder<G> get decoder;

  /// Creates an encoder instance for this codec
  ///
  /// Returns a new instance of an encoder that can convert an RdfGraph
  /// to text in this codec's format.
  @override
  RdfEncoder<G> get encoder;

  const RdfCodec();

  /// Creates a new codec instance with the specified options
  ///
  /// This method returns a new instance of the codec configured with the
  /// provided encoder and decoder options. The original codec instance remains unchanged.
  ///
  /// The [encoder] parameter contains optional encoder options to customize encoding behavior.
  /// The [decoder] parameter contains optional decoder options to customize decoding behavior.
  ///
  /// Returns a new [RdfGraphCodec] instance with the specified options applied.
  ///
  /// This follows the immutable configuration pattern, allowing for clean
  /// method chaining and configuration without side effects.
  RdfCodec<G> withOptions({
    RdfGraphEncoderOptions? encoder,
    RdfGraphDecoderOptions? decoder,
  });

  /// Encodes an RDF graph to a string representation in this codec
  ///
  /// This is a convenience method that delegates to the codec's encoder.
  /// It transforms an in-memory RDF graph into an encoded text representation that can be
  /// stored or transmitted.
  ///
  /// The [input] parameter is the RDF graph to encode.
  /// The [baseUri] parameter is an optional base URI for resolving/shortening IRIs in the output.
  /// When provided, the encoder may use this to produce more compact output.
  /// The [options] parameter contains optional encoder options to use for this encoding operation.
  /// Can include custom namespace prefixes and other encoder-specific settings.
  ///
  /// Returns the serialized representation of the graph as a string.
  ///
  /// Example:
  /// ```dart
  /// final turtle = TurtleCodec();
  /// final options = RdfGraphEncoderOptions(customPrefixes: {'ex': 'http://example.org/'});
  /// final serialized = turtle.encode(graph, options: options);
  /// ```
  String encode(
    G input, {
    String? baseUri,
    RdfGraphEncoderOptions? options,
  }) {
    return (options == null ? encoder : encoder.withOptions(options)).convert(
      input,
      baseUri: baseUri,
    );
  }

  /// Decodes a string containing RDF data into an RDF graph
  ///
  /// This is a convenience method that delegates to the codec's decoder.
  /// It transforms a textual RDF document into a structured RdfGraph object
  /// containing triples parsed from the input.
  ///
  /// The [input] parameter is the RDF content to decode as a string.
  /// The [documentUrl] parameter is an optional base URI for resolving relative references in the document.
  /// If not provided, relative IRIs will be kept as-is or handled according to
  /// codec-specific rules.
  /// The [options] parameter contains optional decoder options for this operation.
  ///
  /// Returns an [RdfGraph] containing the parsed triples.
  ///
  /// Example:
  /// ```dart
  /// final turtle = TurtleCodec();
  /// final graph = turtle.decode(turtleString);
  /// ```
  ///
  /// Throws codec-specific exceptions for syntax errors or other parsing problems.
  G decode(
    String input, {
    String? documentUrl,
    RdfGraphDecoderOptions? options,
  }) {
    return (options == null ? decoder : decoder.withOptions(options)).convert(
      input,
      documentUrl: documentUrl,
    );
  }

  /// Tests if the provided content is likely in this codec's format
  ///
  /// This method is used for codec auto-detection when no explicit MIME type
  /// is available. It should perform quick heuristic checks to determine if
  /// the content appears to be in the format supported by this codec.
  ///
  /// The method should balance accuracy with performance - it should not
  /// perform a full parse, but should do enough checking to make a reasonable
  /// determination.
  ///
  /// The [content] parameter is the string content to check.
  ///
  /// Returns true if the content appears to be in this codec's format.
  bool canParse(String content);
}
