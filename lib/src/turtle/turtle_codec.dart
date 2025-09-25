/// Turtle RDF Format - Human-friendly RDF serialization
///
/// This file defines the implementation of the Turtle (Terse RDF Triple Language)
/// serialization format for RDF data. Turtle provides a compact and human-readable
/// syntax for encoding RDF graphs as text.
library turtle_format;

import 'package:rdf_core/src/graph/rdf_term.dart';
import 'package:rdf_core/src/rdf_decoder.dart';
import 'package:rdf_core/src/rdf_encoder.dart';
import 'package:rdf_core/src/vocab/namespaces.dart';

import '../plugin/rdf_graph_codec.dart';
import '../rdf_graph_decoder.dart';
import '../rdf_graph_encoder.dart';
import 'turtle_decoder.dart';
import 'turtle_encoder.dart';

export 'turtle_decoder.dart' show TurtleDecoderOptions, TurtleDecoder;
export 'turtle_encoder.dart' show TurtleEncoderOptions, TurtleEncoder;

/// RDF Codec implementation for the Turtle serialization format.
///
/// Turtle (Terse RDF Triple Language) is a textual syntax for RDF that is
/// both readable by humans and parsable by machines. It is a simplified,
/// compatible subset of the Notation3 (N3) format.
///
/// ## Turtle Syntax Overview
///
/// Turtle has several key features that make it popular for RDF serialization:
///
/// - **Prefixed names**: Allow abbreviation of IRIs using prefixes
///   ```turtle
///   @prefix foaf: <http://xmlns.com/foaf/0.1/> .
///   <http://example.org/john> foaf:name "John Smith" .
///   ```
///
/// - **Lists**: Compact representation of ordered collections
///   ```turtle
///   <http://example.org/list> <http://example.org/property> (1 2 3) .
///   ```
///
/// - **Predicate lists**: Group multiple predicates for the same subject
///   ```turtle
///   <http://example.org/john> foaf:name "John Smith" ;
///                             foaf:age 25 ;
///                             foaf:mbox <mailto:john@example.org> .
///   ```
///
/// - **Object lists**: Group multiple objects for the same subject-predicate pair
///   ```turtle
///   <http://example.org/john> foaf:nick "Johnny", "J", "JJ" .
///   ```
///
/// - **Blank nodes**: Represent anonymous resources
///   ```turtle
///   <http://example.org/john> foaf:knows [ foaf:name "Jane" ] .
///   ```
///
/// ## File Extension and MIME Types
///
/// Turtle files typically use the `.ttl` file extension.
/// The primary MIME type is `text/turtle`.
final class TurtleCodec extends RdfGraphCodec {
  static const _primaryMimeType = 'text/turtle';

  /// All MIME types that this format implementation can handle
  ///
  /// Note: This implementation also supports some N3 MIME types, as Turtle is
  /// a subset of N3. However, full N3 features beyond Turtle are not supported.
  static const _supportedMimeTypes = {
    _primaryMimeType,
    'application/x-turtle',
    'application/turtle',
    'text/n3', // N3 is a superset of Turtle
    'text/rdf+n3', // Alternative MIME for N3
    'application/rdf+n3', // Alternative MIME for N3
  };

  final RdfNamespaceMappings _namespaceMappings;
  final TurtleEncoderOptions _encoderOptions;
  final TurtleDecoderOptions _decoderOptions;
  final IriTermFactory _iriTermFactory;

  /// Creates a new Turtle codec
  ///
  /// Parameters:
  /// - [namespaceMappings] Optional namespace prefixes to use for encoding and decoding.
  ///   If not provided, defaults to standard RDF namespace mappings.
  /// - [encoderOptions] Configuration options for the Turtle encoder.
  ///   Default settings use standard formatting with common prefixes.
  /// - [decoderOptions] Configuration options for the Turtle decoder.
  ///   Default settings handle standard Turtle syntax with no special configurations.
  const TurtleCodec({
    RdfNamespaceMappings? namespaceMappings,
    TurtleEncoderOptions encoderOptions = const TurtleEncoderOptions(),
    TurtleDecoderOptions decoderOptions = const TurtleDecoderOptions(),
    IriTermFactory iriTermFactory = IriTerm.validated,
  })  : _namespaceMappings = namespaceMappings ?? const RdfNamespaceMappings(),
        _encoderOptions = encoderOptions,
        _decoderOptions = decoderOptions,
        _iriTermFactory = iriTermFactory;

  /// Creates a new instance with the specified options
  ///
  /// This method returns a new Turtle codec configured with the provided
  /// encoder and decoder options. The original codec instance remains unchanged.
  ///
  /// Parameters:
  /// - [encoder] Optional encoder options to customize encoding behavior.
  ///   Will be properly cast to TurtleEncoderOptions if possible, else we use
  ///   just the options from the [RdfGraphEncoderOptions] class.
  /// - [decoder] Optional decoder options to customize decoding behavior.
  ///   Will be properly cast to TurtleDecoderOptions if possible, else we use
  ///   just the options from the [RdfGraphDecoderOptions] class.
  ///
  /// Returns:
  /// - A new [TurtleCodec] instance with the specified options applied,
  ///   while preserving the original namespace mappings.
  @override
  TurtleCodec withOptions({
    RdfGraphEncoderOptions? encoder,
    RdfGraphDecoderOptions? decoder,
    IriTermFactory? iriTermFactory,
  }) {
    return TurtleCodec(
        namespaceMappings: _namespaceMappings,
        encoderOptions: TurtleEncoderOptions.from(encoder ?? _encoderOptions),
        decoderOptions: TurtleDecoderOptions.from(decoder ?? _decoderOptions),
        iriTermFactory: iriTermFactory ?? _iriTermFactory);
  }

  /// Returns the primary MIME type for Turtle format
  ///
  /// The canonical MIME type for Turtle is 'text/turtle'.
  @override
  String get primaryMimeType => _primaryMimeType;

  /// Returns all MIME types supported by this Turtle codec
  ///
  /// Includes the primary MIME type 'text/turtle' and other
  /// alternative and compatible MIME types such as those for N3.
  @override
  Set<String> get supportedMimeTypes => _supportedMimeTypes;

  /// Returns a Turtle decoder instance
  ///
  /// Creates a new decoder that can parse Turtle syntax into an RDF graph.
  /// The decoder will be initialized with this codec's namespace mappings
  /// and decoder options.
  ///
  /// Returns:
  /// - A [TurtleDecoder] configured with this codec's settings
  @override
  RdfGraphDecoder get decoder => TurtleDecoder(
      options: _decoderOptions,
      namespaceMappings: _namespaceMappings,
      iriTermFactory: _iriTermFactory);

  /// Returns a Turtle encoder instance
  ///
  /// Creates a new encoder that can serialize an RDF graph to Turtle syntax.
  /// The encoder will be initialized with this codec's namespace mappings
  /// and encoder options.
  ///
  /// Returns:
  /// - A [TurtleEncoder] configured with this codec's settings
  @override
  RdfGraphEncoder get encoder => TurtleEncoder(
        options: _encoderOptions,
        namespaceMappings: _namespaceMappings,
      );

  /// Determines if the content is likely in Turtle format
  ///
  /// This method performs a heuristic analysis of the content to check if it
  /// appears to be in Turtle format. It looks for common Turtle syntax markers
  /// such as prefix declarations, common RDF prefixes, and triple patterns.
  ///
  /// The method uses a lightweight approach that balances accuracy with performance,
  /// avoiding a full parse while still providing reasonable detection capability.
  ///
  /// Parameters:
  /// - [content] The string content to analyze
  ///
  /// Returns:
  /// - true if the content appears to be in Turtle format
  @override
  bool canParse(String content) {
    // Simple heuristics for detecting Turtle format
    final trimmed = content.trim();

    // Early rejection: obvious HTML content
    if (_isObviouslyHtml(trimmed)) {
      return false;
    }

    // Check for explicit Turtle directives
    if (trimmed.contains('@prefix') ||
        trimmed.contains('@base') ||
        trimmed.contains('prefix rdf:') ||
        trimmed.contains('prefix rdfs:') ||
        trimmed.contains('prefix owl:') ||
        trimmed.contains('prefix xsd:')) {
      return true;
    }

    // Look for Turtle-like triple patterns (more specific than before)
    // Must have angle brackets for IRIs or prefixed names
    final hasTriplePattern = RegExp(
      r'(<[^>]+>|\w+:\w+)\s+(<[^>]+>|\w+:\w+|a)\s+(<[^>]+>|\w+:\w+|"[^"]*"|\d+|true|false)\s*\.',
      multiLine: true,
    ).hasMatch(trimmed);

    if (hasTriplePattern) {
      return true;
    }

    // Check for blank node patterns
    final hasBlankNodes = RegExp(r'\[\s*\]|\[.*?\]').hasMatch(trimmed);
    if (hasBlankNodes && trimmed.contains('.')) {
      return true;
    }

    // Check for collection patterns
    final hasCollections = RegExp(r'\(\s*\)|\([^)]+\)').hasMatch(trimmed);
    if (hasCollections && trimmed.contains('.')) {
      return true;
    }

    return false;
  }

  /// Helper method to detect obvious HTML content that should be rejected
  bool _isObviouslyHtml(String content) {
    final lowerContent = content.toLowerCase();

    // Check for HTML doctype
    if (lowerContent.startsWith('<!doctype html')) {
      return true;
    }

    // Check for HTML opening tag
    if (lowerContent.startsWith('<html')) {
      return true;
    }

    // Single HTML tag might be coincidental, but DOCTYPE or <html> is definitive
    return false;
  }
}

/// Global convenience variable for working with Turtle format
///
/// This variable provides direct access to a pre-configured Turtle codec
/// for easy encoding and decoding of Turtle data without needing to create
/// a codec instance manually.
///
/// Example:
/// ```dart
/// final graph = turtle.decode(turtleString);
/// final serialized = turtle.encode(graph);
/// ```
///
/// For custom configuration, you can create a new codec with specific options:
/// ```dart
/// final customTurtle = TurtleCodec(
///   namespaceMappings: myNamespaces,
///   encoderOptions: TurtleEncoderOptions(generateMissingPrefixes: false),
/// );
/// ```
final turtle = TurtleCodec();
