/// RDF (Resource Description Framework) Library for Dart
///
/// This library provides a comprehensive implementation of the W3C RDF data model,
/// allowing applications to parse, manipulate, and serialize RDF data in various
/// ways.
///
/// It implements the RDF 1.1 Concepts and Abstract Syntax specification and supports
/// multiple serialization formats.
///
/// ## Core Concepts
///
/// ### RDF Data Model
///
/// RDF (Resource Description Framework) represents information as a graph of statements
/// called "triples". Each triple consists of three parts:
///
/// - **Subject**: The resource being described (an IRI or blank node)
/// - **Predicate**: The property or relationship type (always an IRI)
/// - **Object**: The property value or related resource (an IRI, blank node, or literal)
///
/// ### Key Components
///
/// - **IRIs**: Internationalized Resource Identifiers that uniquely identify resources
/// - **Blank Nodes**: Anonymous resources without global identifiers
/// - **Literals**: Values like strings, numbers, or dates (optionally with language tags or datatypes)
/// - **Triples**: Individual statements in the form subject-predicate-object
/// - **Graphs**: Collections of triples representing related statements
///
/// ### Serialization Codecs
///
/// This library supports these RDF serialization codecs:
///
/// - **Turtle**: A compact, human-friendly text format (MIME type: text/turtle)
/// - **JSON-LD**: JSON-based serialization of Linked Data (MIME type: application/ld+json)
/// - **N-Triples**: A line-based, plain text format for encoding RDF graphs (MIME type: application/n-triples)
///
/// The library uses a plugin system to allow registration of additional codecs.
///
/// ## Usage Examples
///
/// ### Basic Decoding and Encoding
///
/// ```dart
/// // Create an RDF library instance with standard formats
/// final rdf = RdfCore.withStandardCodecs();
///
/// // Decode Turtle data
/// final turtleData = '''
/// @prefix foaf: <http://xmlns.com/foaf/0.1/> .
///
/// <http://example.org/john> foaf:name "John Smith" ;
///                            foaf:knows <http://example.org/jane> .
/// ''';
///
/// final graph = rdf.decode(turtleData, contentType: 'text/turtle');
///
/// // Encode to JSON-LD
/// final jsonLd = rdf.encode(graph, contentType: 'application/ld+json');
/// print(jsonLd);
/// ```
///
/// ### Creating and Manipulating Graphs
///
/// ```dart
/// // Create an empty graph
/// final graph = RdfGraph();
///
/// // Create terms
/// final subject = IriTerm('http://example.org/john');
/// final predicate = IriTerm('http://xmlns.com/foaf/0.1/name');
/// final object = LiteralTerm.string('John Smith');
///
/// // Add a triple
/// final newGraph = graph.withTriple(Triple(subject, predicate, object));
///
/// // Query the graph
/// final nameTriples = graph.getObjects(
///   subject,
///   predicate
/// );
///
/// // Print all objects for the given subject and predicate
/// for (final triple in nameTriples) {
///   print('Name: ${triple.object}');
/// }
/// ```
///
/// ### Auto-detection of codecs
///
/// ```dart
/// // The library can automatically detect the codec from content
/// final unknownContent = getContentFromSomewhere();
/// final graph = rdf.decode(unknownContent); // Format auto-detected
/// ```
///
/// ### Using Custom Prefixes in Serialization
/// Note that this is rarely needed, as the library knows some well-known
/// prefixes and will automatically generate missing prefixes for you.
/// However, this gives you more control over the output.
///
/// ```dart
/// final customPrefixes = {
///   'example': 'http://example.org/',
///   'foaf': 'http://xmlns.com/foaf/0.1/'
/// };
///
/// final turtle = rdf.encode(
///   graph,
///   contentType: 'text/turtle',
///   options: TurtleEncoderOptions(
///     customPrefixes: customPrefixes
///   )
/// );
/// ```
///
/// ## Architecture
///
/// The library follows a modular design with these key components:
///
/// - **Terms**: Classes for representing RDF terms (IRIs, blank nodes, literals)
/// - **Triples**: The atomic data unit in RDF, combining subject, predicate, and object
/// - **Graphs**: Collections of triples with query capabilities
/// - **Decoders**: Convert serialized RDF text into graph structures
/// - **Encoders**: Convert graph structures into serialized text
/// - **Codec Registry**: Plugin system for registering new codecs
///
/// The design follows IoC principles with dependency injection, making the
/// library highly testable and extensible.
library rdf;

import 'package:rdf_core/src/rdf_decoder.dart';
import 'package:rdf_core/src/rdf_encoder.dart';
import 'package:rdf_core/src/vocab/namespaces.dart';

import 'src/graph/rdf_graph.dart';
import 'src/jsonld/jsonld_codec.dart';
import 'src/ntriples/ntriples_codec.dart';
import 'src/plugin/rdf_codec.dart';
import 'src/turtle/turtle_codec.dart';

export 'src/exceptions/exceptions.dart';
// Re-export core components for easy access
export 'src/graph/rdf_graph.dart';
export 'src/graph/rdf_term.dart';
export 'src/graph/triple.dart';
export 'src/jsonld/jsonld_codec.dart';
export 'src/ntriples/ntriples_codec.dart';
export 'src/plugin/rdf_codec.dart';
export 'src/rdf_decoder.dart';
export 'src/rdf_encoder.dart';
export 'src/turtle/turtle_codec.dart';
export 'src/turtle/turtle_tokenizer.dart' show TurtleParsingFlag;
export 'src/vocab/namespaces.dart';

/// RDF Core Library
///
/// Entry point for core RDF data model types and utilities.
///
/// Example usage:
/// ```dart
/// import 'package:rdf_core/rdf_core.dart';
/// final triple = Triple(subject, predicate, object);
/// ```
///
/// See: [RDF 1.1 Concepts and Abstract Syntax](https://www.w3.org/TR/rdf11-concepts/)
/// Central facade for the RDF library, providing access to parsing and serialization.
///
/// This class serves as the primary entry point for the RDF library, offering a simplified
/// interface for common RDF operations. It encapsulates the complexity of codec management,
/// format registries, and plugin management behind a clean, user-friendly API.
///
/// The class follows IoC principles by accepting dependencies in its constructor,
/// making it suitable for dependency injection and improving testability.
/// For most use cases, the [RdfCore.withStandardCodecs] factory constructor
/// provides a pre-configured instance with standard codecs registered.
final class RdfCore {
  final RdfCodecRegistry _registry;

  /// Creates a new RDF library instance with the given components
  ///
  /// This constructor enables full dependency injection, allowing for:
  /// - Custom codec registries
  /// - Mock implementations for testing
  ///
  /// For standard usage, see [RdfCore.withStandardCodecs].
  ///
  /// Parameters:
  /// - [registry]: The codec registry that manages available RDF codecs
  RdfCore({required RdfCodecRegistry registry}) : _registry = registry;

  /// Creates a new RDF library instance with standard codecs registered
  ///
  /// This convenience constructor sets up an RDF library with Turtle, JSON-LD and
  /// N-Triples codecs ready to use. It's the recommended way to create an instance
  /// for most applications.
  ///
  /// Parameters:
  /// - [namespaceMappings]: Optional custom namespace mappings for all codecs
  /// - [additionalCodecs]: Optional list of additional codecs to register beyond
  ///   the standard ones
  ///
  /// Example:
  /// ```dart
  /// final rdf = RdfCore.withStandardCodecs();
  /// final graph = rdf.decode(turtleData, contentType: 'text/turtle');
  /// ```
  factory RdfCore.withStandardCodecs({
    RdfNamespaceMappings? namespaceMappings,
    List<RdfGraphCodec> additionalCodecs = const [],
  }) {
    final registry = RdfCodecRegistry();
    final _namespaceMappings =
        namespaceMappings ?? const RdfNamespaceMappings();

    // Register standard formats
    registry.registerGraphCodec(
      TurtleCodec(namespaceMappings: _namespaceMappings),
    );
    registry.registerGraphCodec(
      JsonLdGraphCodec(namespaceMappings: _namespaceMappings),
    );
    registry.registerGraphCodec(const NTriplesCodec());

    // Register additional codecs
    for (final codec in additionalCodecs) {
      registry.registerGraphCodec(codec);
    }

    return RdfCore(registry: registry);
  }

  /// Creates a new RDF library instance with only the provided codecs registered
  ///
  /// This convenience constructor sets up an RDF library with the specified codecs
  /// registered. It allows for easy customization of the library's capabilities.
  /// For example, if you need to support Turtle with certain parsing flags because
  /// your turtle documents are not fully compliant with the standard.
  ///
  ///
  /// Example:
  /// ```dart
  /// final namespaceMappings = RdfNamespaceMappings();
  /// final turtle = TurtleCodec(
  ///   namespaceMappings: namespaceMappings,
  ///   parsingFlags: {TurtleParsingFlag.allowMissingFinalDot});
  /// final rdf = RdfCore.withCodecs(codecs: [turtle]);
  /// final graph = rdf.decode(turtleData, contentType: 'text/turtle');
  /// ```
  factory RdfCore.withCodecs({List<RdfGraphCodec> codecs = const []}) {
    final registry = RdfCodecRegistry();
    for (final codec in codecs) {
      registry.registerGraphCodec(codec);
    }

    return RdfCore(registry: registry);
  }

  /// Decode RDF content to create a graph
  ///
  /// Converts a string containing serialized RDF data into an in-memory RDF graph.
  /// The format can be explicitly specified using the contentType parameter,
  /// or automatically detected from the content if not specified.
  ///
  /// Parameters:
  /// - [content]: The RDF content to parse as a string
  /// - [contentType]: Optional MIME type to specify the format (e.g., "text/turtle")
  /// - [documentUrl]: Optional base URI for resolving relative references in the document
  /// - [options]: Optional format-specific decoder options (e.g., TurtleDecoderOptions)
  ///
  /// Returns:
  /// - An [RdfGraph] containing the parsed triples
  ///
  /// Throws:
  /// - Codec-specific exceptions for parsing errors
  /// - [CodecNotSupportedException] if the codec is not supported and cannot be detected
  RdfGraph decode(
    String content, {
    String? contentType,
    String? documentUrl,
    RdfGraphDecoderOptions? options,
  }) => codec(
    contentType: contentType,
    decoderOptions: options,
  ).decode(content, documentUrl: documentUrl);

  /// Encode an RDF graph to a string representation
  ///
  /// Converts an in-memory RDF graph into a serialized string representation
  /// in the specified format. If no format is specified, the default codec
  /// (typically Turtle) is used.
  ///
  /// Parameters:
  /// - [graph]: The RDF graph to encode
  /// - [contentType]: Optional MIME type to specify the output format
  /// - [baseUri]: Optional base URI for the serialized output, which may enable
  ///   more compact representations with relative URIs
  /// - [options]: Optional format-specific encoder options (e.g., TurtleEncoderOptions)
  ///
  /// Returns:
  /// - A string containing the serialized RDF data
  ///
  /// Throws:
  /// - [CodecNotSupportedException] if the requested codec is not supported
  /// - Codec-specific exceptions for serialization errors
  String encode(
    RdfGraph graph, {
    String? contentType,
    String? baseUri,
    RdfGraphEncoderOptions? options,
  }) => codec(
    contentType: contentType,
    encoderOptions: options,
  ).encode(graph, baseUri: baseUri);

  /// Get a codec for a specific content type
  ///
  /// Returns a codec that can handle the specified content type.
  /// If no content type is specified, returns the default codec
  /// (typically for Turtle).
  ///
  /// Parameters:
  /// - [contentType]: Optional MIME type to specify the format. If not specified,
  /// then the encoding will be with the default codec (the first codec registered,
  /// typically turtle) and the decoding codec will be automatically detected.
  ///
  /// Returns:
  /// - An [RdfGraphCodec] that can handle the specified content type
  ///
  /// Throws:
  /// - [CodecNotSupportedException] if the requested format is not supported
  RdfGraphCodec codec({
    String? contentType,
    RdfGraphEncoderOptions? encoderOptions,
    RdfGraphDecoderOptions? decoderOptions,
  }) {
    final codec = _registry.getGraphCodec(contentType);
    if (encoderOptions != null || decoderOptions != null) {
      return codec.withOptions(
        encoder: encoderOptions,
        decoder: decoderOptions,
      );
    }
    return codec;
  }
}

/// Global convenience variable for accessing RDF functionality
/// with standard codecs pre-registered
///
/// This variable provides a pre-configured RDF library instance with
/// Turtle, JSON-LD, and N-Triples codecs registered.
///
/// Example:
/// ```dart
/// final graph = rdf.decode(turtleData, contentType: 'text/turtle');
/// final serialized = rdf.encode(graph, contentType: 'application/ld+json');
/// ```
final rdf = RdfCore.withStandardCodecs();
