/// Turtle RDF Format - Human-friendly RDF serialization
///
/// This file defines the implementation of the Turtle (Terse RDF Triple Language)
/// serialization format for RDF data. Turtle provides a compact and human-readable
/// syntax for encoding RDF graphs as text.
library turtle_format;

import 'package:rdf_core/src/turtle/turtle_tokenizer.dart';
import 'package:rdf_core/src/vocab/namespaces.dart';

import '../plugin/rdf_codec.dart';
import '../rdf_decoder.dart';
import '../rdf_encoder.dart';
import 'turtle_decoder.dart';
import 'turtle_encoder.dart';

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
  final Set<TurtleParsingFlag> _parsingFlags;

  /// Creates a new Turtle format handler
  const TurtleCodec({
    RdfNamespaceMappings? namespaceMappings,
    Set<TurtleParsingFlag> parsingFlags = const {},
  }) : _namespaceMappings = namespaceMappings ?? const RdfNamespaceMappings(),
       _parsingFlags = parsingFlags;

  @override
  String get primaryMimeType => _primaryMimeType;

  @override
  Set<String> get supportedMimeTypes => _supportedMimeTypes;

  @override
  RdfGraphDecoder get decoder => TurtleDecoder(
    parsingFlags: _parsingFlags,
    namespaceMappings: _namespaceMappings,
  );

  @override
  RdfGraphEncoder get encoder =>
      TurtleEncoder(namespaceMappings: _namespaceMappings);

  @override
  bool canParse(String content) {
    // Simple heuristics for detecting Turtle format
    final trimmed = content.trim();

    // Check for common Turtle prefixes, predicates or statements
    return trimmed.contains('@prefix') ||
        trimmed.contains('@base') ||
        // Look for triple pattern ending with dot
        RegExp(r'.*\s+.*\s+.*\s*\.$', multiLine: true).hasMatch(trimmed) ||
        // Check for common RDF prefix declarations
        trimmed.contains('prefix rdf:') ||
        trimmed.contains('prefix rdfs:') ||
        trimmed.contains('prefix owl:') ||
        trimmed.contains('prefix xsd:');
  }
}

/// Global convenience variable for working with Turtle format
///
/// This variable provides direct access to Turtle codec for easy
/// encoding and decoding of Turtle data.
///
/// Example:
/// ```dart
/// final graph = turtle.decode(turtleString);
/// final serialized = turtle.encode(graph);
/// ```
final turtle = TurtleCodec();
