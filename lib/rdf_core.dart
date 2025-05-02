/// RDF (Resource Description Framework) Library for Dart
///
/// This library provides a comprehensive implementation of the W3C RDF data model,
/// allowing applications to parse, manipulate, and serialize RDF data in various formats.
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
/// ### Serialization Formats
///
/// This library supports these RDF serialization formats:
///
/// - **Turtle**: A compact, human-friendly text format (MIME type: text/turtle)
/// - **JSON-LD**: JSON-based serialization of Linked Data (MIME type: application/ld+json)
///
/// The library uses a plugin system to allow registration of additional formats.
///
/// ## Usage Examples
///
/// ### Basic Parsing and Serialization
///
/// ```dart
/// // Create an RDF library instance with standard formats
/// final rdf = RdfCore.withStandardFormats();
///
/// // Parse Turtle data
/// final turtleData = '''
/// @prefix foaf: <http://xmlns.com/foaf/0.1/> .
///
/// <http://example.org/john> foaf:name "John Smith" ;
///                            foaf:knows <http://example.org/jane> .
/// ''';
///
/// final graph = rdf.parse(turtleData, contentType: 'text/turtle');
///
/// // Serialize to JSON-LD
/// final jsonLd = rdf.serialize(graph, contentType: 'application/ld+json');
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
/// final nameTriples = graph.findBySubjectAndPredicate(
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
/// ### Auto-detection of formats
///
/// ```dart
/// // The library can automatically detect the format from content
/// final unknownContent = getContentFromSomewhere();
/// final graph = rdf.parse(unknownContent); // Format auto-detected
/// ```
///
/// ### Using Custom Prefixes in Serialization
///
/// ```dart
/// final customPrefixes = {
///   'ex': 'http://example.org/',
///   'foaf': 'http://xmlns.com/foaf/0.1/'
/// };
///
/// final turtle = rdf.serialize(
///   graph,
///   contentType: 'text/turtle',
///   customPrefixes: customPrefixes
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
/// - **Parsers**: Convert serialized RDF text into graph structures
/// - **Serializers**: Convert graph structures into serialized text
/// - **Format Registry**: Plugin system for registering new serialization formats
///
/// The design follows IoC principles with dependency injection, making the
/// library highly testable and extensible.
library rdf;

import 'package:rdf_core/src/vocab/namespaces.dart';

import 'src/graph/rdf_graph.dart';
import 'src/plugin/format_plugin.dart';
import 'src/rdf_parser.dart';
import 'src/rdf_serializer.dart';
import 'src/jsonld/jsonld_format.dart';
import 'src/turtle/turtle_format.dart';

// Re-export core components for easy access
export 'src/graph/rdf_graph.dart';
export 'src/graph/rdf_term.dart';
export 'src/graph/triple.dart';
export 'src/plugin/format_plugin.dart';
export 'src/rdf_parser.dart';
export 'src/rdf_serializer.dart';
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
/// interface for common RDF operations. It encapsulates the complexity of parser and serializer
/// factories, format registries, and plugin management behind a clean, user-friendly API.
///
/// The class follows IoC principles by accepting dependencies in its constructor,
/// making it suitable for dependency injection and improving testability.
/// For most use cases, the [RdfCore.withStandardFormats] factory constructor
/// provides a pre-configured instance with standard formats registered.
final class RdfCore {
  final RdfFormatRegistry _registry;
  final RdfParserFactory _parserFactory;
  final RdfSerializerFactory _serializerFactory;

  /// Creates a new RDF library instance with the given components
  ///
  /// This constructor enables full dependency injection, allowing for:
  /// - Custom format registries
  /// - Modified parser or serializer factories
  /// - Mock implementations for testing
  ///
  /// For standard usage, see [RdfCore.withStandardFormats].
  ///
  /// Parameters:
  /// - [registry]: The format registry that manages available RDF formats
  /// - [parserFactory]: The factory that creates parser instances
  /// - [serializerFactory]: The factory that creates serializer instances
  RdfCore({
    required RdfFormatRegistry registry,
    required RdfParserFactory parserFactory,
    required RdfSerializerFactory serializerFactory,
  }) : _registry = registry,
       _parserFactory = parserFactory,
       _serializerFactory = serializerFactory;

  /// Creates a new RDF library instance with standard formats registered
  ///
  /// This convenience constructor sets up an RDF library with Turtle and JSON-LD
  /// formats ready to use. It's the recommended way to create an instance for
  /// most applications.
  ///
  /// Example:
  /// ```dart
  /// final rdf = RdfCore.withStandardFormats();
  /// final graph = rdf.parse(turtleData, contentType: 'text/turtle');
  /// ```
  factory RdfCore.withStandardFormats({
    RdfNamespaceMappings? namespaceMappings,
  }) {
    final registry = RdfFormatRegistry();
    final _namespaceMappings =
        namespaceMappings ?? const RdfNamespaceMappings();
    // Register standard formats
    registry.registerFormat(
      TurtleFormat(namespaceMappings: _namespaceMappings),
    );
    registry.registerFormat(
      JsonLdFormat(namespaceMappings: _namespaceMappings),
    );

    final parserFactory = RdfParserFactory(registry);
    final serializerFactory = RdfSerializerFactory(registry);

    return RdfCore(
      registry: registry,
      parserFactory: parserFactory,
      serializerFactory: serializerFactory,
    );
  }

  /// Creates a new RDF library instance with only the provided formats registered
  ///
  /// This convenience constructor sets up an RDF library with the specified formats
  /// registered. It allows for easy customization of the library's capabilities.
  /// For example, if you need to support Turtle with certain parsing flags because
  /// your turtle documents are not fully compliant with the standard.
  ///
  ///
  /// Example:
  /// ```dart
  /// final namespaceMappings = RdfNamespaceMappings();
  /// final turtle = TurtleFormat(
  ///   namespaceMappings: namespaceMappings,
  ///   parsingFlags: {TurtleParsingFlag.allowMissingFinalDot});
  /// final rdf = RdfCore.withFormats();
  /// final graph = rdf.parse(turtleData, contentType: 'text/turtle');
  /// ```
  factory RdfCore.withFormats({List<RdfFormat> formats = const []}) {
    final registry = RdfFormatRegistry();
    for (final format in formats) {
      registry.registerFormat(format);
    }

    final parserFactory = RdfParserFactory(registry);
    final serializerFactory = RdfSerializerFactory(registry);

    return RdfCore(
      registry: registry,
      parserFactory: parserFactory,
      serializerFactory: serializerFactory,
    );
  }

  /// Parse RDF content to create a graph
  ///
  /// Converts a string containing serialized RDF data into an in-memory RDF graph.
  /// The format can be explicitly specified using the contentType parameter,
  /// or automatically detected from the content if not specified.
  ///
  /// Parameters:
  /// - [content]: The RDF content to parse as a string
  /// - [contentType]: Optional MIME type to specify the format (e.g., "text/turtle")
  /// - [documentUrl]: Optional base URI for resolving relative references in the document
  ///
  /// Returns:
  /// - An [RdfGraph] containing the parsed triples
  ///
  /// Throws:
  /// - Format-specific exceptions for parsing errors
  /// - [FormatNotSupportedException] if the format is not supported and cannot be detected
  RdfGraph parse(String content, {String? contentType, String? documentUrl}) {
    return _parserFactory.parse(
      content,
      contentType: contentType,
      documentUrl: documentUrl,
    );
  }

  /// Serialize an RDF graph to a string representation
  ///
  /// Converts an in-memory RDF graph into a serialized string representation
  /// in the specified format. If no format is specified, the default format
  /// (typically Turtle) is used.
  ///
  /// Parameters:
  /// - [graph]: The RDF graph to serialize
  /// - [contentType]: Optional MIME type to specify the output format
  /// - [baseUri]: Optional base URI for the serialized output, which may enable
  ///   more compact representations with relative URIs
  /// - [customPrefixes]: Optional custom namespace prefix mappings to use in
  ///   formats that support prefixes (like Turtle)
  ///
  /// Returns:
  /// - A string containing the serialized RDF data
  ///
  /// Throws:
  /// - [FormatNotSupportedException] if the requested format is not supported
  /// - Format-specific exceptions for serialization errors
  String serialize(
    RdfGraph graph, {
    String? contentType,
    String? baseUri,
    Map<String, String> customPrefixes = const {},
  }) {
    return _serializerFactory.write(
      graph,
      contentType: contentType,
      baseUri: baseUri,
      customPrefixes: customPrefixes,
    );
  }

  /// Register a custom format with the RDF library
  ///
  /// This method allows extending the library with support for additional
  /// RDF serialization formats beyond the standard ones.
  ///
  /// Parameters:
  /// - [format]: The format implementation to register
  ///
  /// After registering a format, it can be used for both parsing and serialization
  /// by specifying its MIME type in the [parse] and [serialize] methods.
  ///
  /// Example:
  /// ```dart
  /// final rdf = RdfCore.withStandardFormats();
  /// rdf.registerFormat(MyCustomRdfFormat());
  /// ```
  void registerFormat(RdfFormat format) {
    _registry.registerFormat(format);
  }

  /// Get an instance of a parser for a specific format
  ///
  /// This method provides direct access to format-specific parsers when
  /// more control over the parsing process is needed.
  ///
  /// Parameters:
  /// - [contentType]: MIME type of the format to get a parser for
  ///
  /// Returns:
  /// - An [RdfParser] instance for the specified format
  /// - If no contentType is specified, returns an auto-detecting parser
  RdfParser getParser({String? contentType}) {
    return _parserFactory.createParser(contentType: contentType);
  }

  /// Get an instance of a serializer for a specific format
  ///
  /// This method provides direct access to format-specific serializers when
  /// more control over the serialization process is needed.
  ///
  /// Parameters:
  /// - [contentType]: MIME type of the format to get a serializer for
  ///
  /// Returns:
  /// - An [RdfSerializer] instance for the specified format
  /// - If no contentType is specified, returns a serializer for the default format
  ///
  /// Throws:
  /// - [FormatNotSupportedException] if no serializer is available for the specified format
  RdfSerializer getSerializer({String? contentType}) {
    return _serializerFactory.createSerializer(contentType: contentType);
  }

  /// Access to the underlying format registry
  ///
  /// Provides access to the format registry for advanced operations
  /// like querying available formats or format-specific capabilities.
  ///
  /// Returns:
  /// - The [RdfFormatRegistry] instance used by this library
  RdfFormatRegistry get registry => _registry;
}
