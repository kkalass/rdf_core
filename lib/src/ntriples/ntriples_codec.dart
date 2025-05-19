/// N-Triples format - Definition of the N-Triples RDF serialization format
///
/// This file defines the format properties for N-Triples, a line-based, plain text
/// format for serializing RDF graphs.
library ntriples_format;

import 'package:rdf_core/src/ntriples/ntriples_decoder.dart';
import 'package:rdf_core/src/ntriples/ntriples_encoder.dart';
import 'package:rdf_core/src/plugin/rdf_codec.dart';
import 'package:rdf_core/src/rdf_decoder.dart';
import 'package:rdf_core/src/rdf_encoder.dart';

export 'ntriples_decoder.dart' show NTriplesDecoderOptions, NTriplesDecoder;
export 'ntriples_encoder.dart' show NTriplesEncoderOptions, NTriplesEncoder;

/// Format definition for the N-Triples RDF serialization format.
///
/// N-Triples is a line-based, plain text RDF serialization format defined by the W3C.
/// It is a simplified subset of Turtle, where each line represents exactly one triple
/// statement. N-Triples is designed to be simple to parse and generate.
///
/// The format is specified in the [RDF 1.1 N-Triples](https://www.w3.org/TR/n-triples/)
/// W3C Recommendation.
///
/// N-Triples characteristics:
/// - Each line contains exactly one triple statement
/// - No abbreviations or prefixes are supported
/// - Everything is written out explicitly, making it verbose but simple
/// - All IRIs are enclosed in angle brackets
/// - The format is line-based, making it easy to process with standard text tools
///
/// Example N-Triples document:
/// ```
/// <http://example.org/subject> <http://example.org/predicate> <http://example.org/object> .
/// <http://example.org/subject> <http://example.org/predicate> "Literal value" .
/// <http://example.org/subject> <http://example.org/predicate> "Value"@en .
/// ```
final class NTriplesCodec extends RdfGraphCodec {
  /// The primary MIME type for N-Triples: application/n-triples
  ///
  /// This MIME type is used for content negotiation and format identification
  /// according to the W3C standards.
  static const String _primaryMimeType = 'application/n-triples';

  /// The additional MIME types that should be recognized as N-Triples
  ///
  /// Currently, there are no alternative MIME types standardized for N-Triples.
  /// This list is provided for future extensibility if needed.
  static const List<String> alternativeMimeTypes = [];

  /// The file extensions associated with N-Triples files
  ///
  /// The standard file extension for N-Triples documents is '.nt'.
  static const List<String> fileExtensions = ['.nt'];

  /// The encoder options used to configure the serialization behavior
  final NTriplesEncoderOptions _encoderOptions;

  /// The decoder options used to configure the parsing behavior
  final NTriplesDecoderOptions _decoderOptions;

  /// Creates a new N-Triples format definition
  const NTriplesCodec({
    NTriplesEncoderOptions encoderOptions = const NTriplesEncoderOptions(),
    NTriplesDecoderOptions decoderOptions = const NTriplesDecoderOptions(),
  })  : _encoderOptions = encoderOptions,
        _decoderOptions = decoderOptions;

  @override
  NTriplesCodec withOptions({
    RdfGraphEncoderOptions? encoder,
    RdfGraphDecoderOptions? decoder,
  }) {
    return NTriplesCodec(
      encoderOptions: NTriplesEncoderOptions.from(encoder ?? _encoderOptions),
      decoderOptions: NTriplesDecoderOptions.from(decoder ?? _decoderOptions),
    );
  }

  /// Returns the primary MIME type for N-Triples: 'application/n-triples'
  ///
  /// This is the standard MIME type used for content negotiation when
  /// requesting or sending N-Triples data over HTTP.
  @override
  String get primaryMimeType => _primaryMimeType;

  /// Returns the set of all supported MIME types for N-Triples
  ///
  /// Currently this includes only the primary MIME type 'application/n-triples',
  /// as there are no standardized alternative MIME types for this format.
  @override
  Set<String> get supportedMimeTypes => {
        ...alternativeMimeTypes,
        _primaryMimeType,
      };

  /// Returns a decoder configured with the current decoder options
  ///
  /// The decoder is used to parse N-Triples format into an RDF graph.
  @override
  RdfGraphDecoder get decoder => NTriplesDecoder(options: _decoderOptions);

  /// Returns an encoder configured with the current encoder options
  ///
  /// The encoder is used to serialize an RDF graph into N-Triples format.
  @override
  RdfGraphEncoder get encoder => NTriplesEncoder(options: _encoderOptions);

  /// Determines if the given content is likely in N-Triples format.
  ///
  /// This method implements a heuristic approach to detect N-Triples content
  /// by analyzing its structure. It uses the following criteria:
  ///
  /// 1. The content must not be empty
  /// 2. Each non-empty line that is not a comment (doesn't start with #) should:
  ///    - Start with either '<' (for IRI subjects) or '_:' (for blank nodes)
  ///    - End with a period '.'
  ///    - Contain at least 3 non-empty segments (representing subject, predicate, object)
  ///
  /// If more than 80% of non-empty lines match these criteria, the content is
  /// considered to be in N-Triples format.
  ///
  /// This approach balances accuracy with performance, making it suitable for
  /// auto-detection scenarios where complete parsing would be too expensive.
  ///
  /// The [content] parameter contains the string content to check.
  /// Returns true if the content is likely N-Triples, false otherwise.
  @override
  bool canParse(String content) {
    // A heuristic to detect if content is likely N-Triples
    // N-Triples is line-based with each line being a triple
    if (content.trim().isEmpty) return false;

    // Count lines that match N-Triples pattern
    final lines = content.split('\n');
    int validLines = 0;
    int totalNonEmptyLines = 0;

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;

      totalNonEmptyLines++;

      // Check if line has the basic structure of N-Triples:
      // - Starts with < (IRI) or _: (blank node)
      // - Ends with a period
      // - Contains at least 2 spaces (separating subject, predicate, object)
      if ((trimmed.startsWith('<') || trimmed.startsWith('_:')) &&
          trimmed.endsWith('.') &&
          trimmed.split(' ').where((s) => s.isNotEmpty).length >= 3) {
        validLines++;
      }
    }

    // If more than 80% of non-empty lines match the pattern, it's likely N-Triples
    return totalNonEmptyLines > 0 && validLines / totalNonEmptyLines > 0.8;
  }

  /// Returns a string representation of this codec
  ///
  /// This is primarily used for debugging and logging purposes.
  @override
  String toString() => 'NTriplesFormat()';
}

/// Global convenience variable for working with N-Triples format
///
/// This variable provides direct access to N-Triples codec for easy
/// encoding and decoding of N-Triples data.
///
/// Example:
/// ```dart
/// final graph = ntriples.decode(ntriplesString);
/// final serialized = ntriples.encode(graph);
/// ```
final ntriples = NTriplesCodec();
