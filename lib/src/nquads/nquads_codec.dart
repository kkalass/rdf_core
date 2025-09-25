/// N-Quads format - Definition of the N-Quads RDF serialization format
///
/// This file defines the format properties for N-Quads, a line-based, plain text
/// format for serializing RDF graphs.
library nquads_format;

import 'package:rdf_core/src/graph/rdf_term.dart';
import 'package:rdf_core/src/nquads/nquads_decoder.dart';
import 'package:rdf_core/src/nquads/nquads_encoder.dart';
import 'package:rdf_core/src/plugin/rdf_dataset_codec.dart';
import 'package:rdf_core/src/rdf_dataset_decoder.dart';
import 'package:rdf_core/src/rdf_dataset_encoder.dart';
import 'package:rdf_core/src/rdf_decoder.dart';
import 'package:rdf_core/src/rdf_encoder.dart';

export 'nquads_decoder.dart' show NQuadsDecoderOptions, NQuadsDecoder;
export 'nquads_encoder.dart' show NQuadsEncoderOptions, NQuadsEncoder;

/// Format definition for the N-Quads RDF serialization format.
///
/// N-Quads is a line-based, plain text RDF serialization format defined by the W3C.
/// It is a simplified subset of Turtle, where each line represents exactly one triple
/// statement. N-Quads is designed to be simple to parse and generate.
///
/// The format is specified in the [RDF 1.1 N-Quads](https://www.w3.org/TR/n-quads/)
/// W3C Recommendation.
///
/// N-Quads characteristics:
/// - Each line contains exactly one triple statement
/// - No abbreviations or prefixes are supported
/// - Everything is written out explicitly, making it verbose but simple
/// - All IRIs are enclosed in angle brackets
/// - The format is line-based, making it easy to process with standard text tools
///
/// Example N-Quads document:
/// ```
/// <http://example.org/subject> <http://example.org/predicate> <http://example.org/object> .
/// <http://example.org/subject> <http://example.org/predicate> "Literal value" .
/// <http://example.org/subject> <http://example.org/predicate> "Value"@en .
/// ```
final class NQuadsCodec extends RdfDatasetCodec {
  /// The primary MIME type for N-Quads: application/n-quads
  ///
  /// This MIME type is used for content negotiation and format identification
  /// according to the W3C standards.
  static const String _primaryMimeType = 'application/n-quads';

  /// The additional MIME types that should be recognized as N-Quads
  ///
  /// Currently, there are no alternative MIME types standardized for N-Quads.
  /// This list is provided for future extensibility if needed.
  static const List<String> alternativeMimeTypes = [];

  /// The file extensions associated with N-Quads files
  ///
  /// The standard file extension for N-Quads documents is '.nt'.
  static const List<String> fileExtensions = ['.nq'];

  /// The encoder options used to configure the serialization behavior
  final NQuadsEncoderOptions _encoderOptions;

  /// The decoder options used to configure the parsing behavior
  final NQuadsDecoderOptions _decoderOptions;

  final IriTermFactory _iriTermFactory;

  /// Creates a new N-Quads format definition
  const NQuadsCodec({
    NQuadsEncoderOptions encoderOptions = const NQuadsEncoderOptions(),
    NQuadsDecoderOptions decoderOptions = const NQuadsDecoderOptions(),
    IriTermFactory iriTermFactory = IriTerm.validated,
  })  : _encoderOptions = encoderOptions,
        _decoderOptions = decoderOptions,
        _iriTermFactory = iriTermFactory;

  @override
  NQuadsCodec withOptions({
    RdfGraphEncoderOptions? encoder,
    RdfGraphDecoderOptions? decoder,
    IriTermFactory? iriTermFactory,
  }) {
    return NQuadsCodec(
        encoderOptions: NQuadsEncoderOptions.from(encoder ?? _encoderOptions),
        decoderOptions: NQuadsDecoderOptions.from(decoder ?? _decoderOptions),
        iriTermFactory: iriTermFactory ?? _iriTermFactory);
  }

  /// Returns the primary MIME type for N-Quads: 'application/n-quads'
  ///
  /// This is the standard MIME type used for content negotiation when
  /// requesting or sending N-Quads data over HTTP.
  @override
  String get primaryMimeType => _primaryMimeType;

  /// Returns the set of all supported MIME types for N-Quads
  ///
  /// Currently this includes only the primary MIME type 'application/n-quads',
  /// as there are no standardized alternative MIME types for this format.
  @override
  Set<String> get supportedMimeTypes => {
        ...alternativeMimeTypes,
        _primaryMimeType,
      };

  /// Returns a decoder configured with the current decoder options
  ///
  /// The decoder is used to parse N-Quads format into an RDF graph.
  @override
  RdfDatasetDecoder get decoder =>
      NQuadsDecoder(options: _decoderOptions, iriTermFactory: _iriTermFactory);

  /// Returns an encoder configured with the current encoder options
  ///
  /// The encoder is used to serialize an RDF graph into N-Quads format.
  @override
  RdfDatasetEncoder get encoder => NQuadsEncoder(options: _encoderOptions);

  /// Determines if the given content is likely in N-Quads format.
  ///
  /// This method implements a heuristic approach to detect N-Quads content
  /// by analyzing its structure. It uses the following criteria:
  ///
  /// 1. The content must not be empty
  /// 2. Each non-empty line that is not a comment (doesn't start with #) should:
  ///    - Start with either '<' (for IRI subjects) or '_:' (for blank nodes)
  ///    - End with a period '.'
  ///    - Contain at least 3 non-empty segments (representing subject, predicate, object)
  ///
  /// If more than 80% of non-empty lines match these criteria, the content is
  /// considered to be in N-Quads format.
  ///
  /// This approach balances accuracy with performance, making it suitable for
  /// auto-detection scenarios where complete parsing would be too expensive.
  ///
  /// The [content] parameter contains the string content to check.
  /// Returns true if the content is likely N-Quads, false otherwise.
  @override
  bool canParse(String content) {
    // A heuristic to detect if content is likely N-Quads
    // N-Quads is line-based with each line being a triple
    if (content.trim().isEmpty) return false;

    // Count lines that match N-Quads pattern
    final lines = content.split('\n');
    int validLines = 0;
    int totalNonEmptyLines = 0;

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;

      totalNonEmptyLines++;

      // Check if line has the basic structure of N-Quads:
      // - Starts with < (IRI) or _: (blank node)
      // - Ends with a period
      // - Contains at least 2 spaces (separating subject, predicate, object)
      if ((trimmed.startsWith('<') || trimmed.startsWith('_:')) &&
          trimmed.endsWith('.') &&
          trimmed.split(' ').where((s) => s.isNotEmpty).length >= 3) {
        validLines++;
      }
    }

    // If more than 80% of non-empty lines match the pattern, it's likely N-Quads
    return totalNonEmptyLines > 0 && validLines / totalNonEmptyLines > 0.8;
  }

  /// Returns a string representation of this codec
  ///
  /// This is primarily used for debugging and logging purposes.
  @override
  String toString() => 'NQuadsFormat()';
}

/// Global convenience variable for working with N-Quads format
///
/// This variable provides direct access to N-Quads codec for easy
/// encoding and decoding of N-Quads data.
///
/// Example:
/// ```dart
/// final graph = nquads.decode(nquadsString);
/// final serialized = nquads.encode(graph);
/// ```
final nquads = NQuadsCodec();
