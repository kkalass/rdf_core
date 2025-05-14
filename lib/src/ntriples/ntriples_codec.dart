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
  static const String _primaryMimeType = 'application/n-triples';

  /// The additional MIME types that should be recognized as N-Triples
  static const List<String> alternativeMimeTypes = [];

  /// The file extensions associated with N-Triples files
  static const List<String> fileExtensions = ['.nt'];

  final NTriplesEncoderOptions _encoderOptions;
  final NTriplesDecoderOptions _decoderOptions;

  /// Creates a new N-Triples format definition
  const NTriplesCodec({
    NTriplesEncoderOptions encoderOptions = const NTriplesEncoderOptions(),
    NTriplesDecoderOptions decoderOptions = const NTriplesDecoderOptions(),
  }) : _encoderOptions = encoderOptions,
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

  @override
  String get primaryMimeType => _primaryMimeType;

  @override
  Set<String> get supportedMimeTypes => {
    ...alternativeMimeTypes,
    _primaryMimeType,
  };

  @override
  RdfGraphDecoder get decoder => NTriplesDecoder(options: _decoderOptions);

  @override
  RdfGraphEncoder get encoder => NTriplesEncoder(options: _encoderOptions);

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
