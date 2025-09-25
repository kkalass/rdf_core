/// JSON-LD RDF Format - Linked Data in JSON
///
/// This file defines the implementation of JSON-LD (JavaScript Object Notation for Linked Data)
/// serialization format for RDF data. JSON-LD enables the expression of linked data using
/// standard JSON syntax, making it both web-friendly and developer-friendly.
///
/// The JSON-LD implementation in this library provides:
/// - Serialization of RDF graphs to JSON-LD (encoding)
/// - Parsing of JSON-LD documents into RDF graphs (decoding)
/// - Support for context definitions and compact IRIs
/// - Handling of nested JSON-LD structures
///
/// JSON-LD is particularly useful when:
/// - Integrating RDF data with JavaScript applications
/// - Creating RESTful APIs that serve semantic data
/// - Working with developers who prefer JSON over other RDF formats
/// - Storing RDF data in JSON-based document databases
///
/// For more information on JSON-LD, see:
/// - [JSON-LD 1.1 W3C Recommendation](https://www.w3.org/TR/json-ld11/)
/// - [JSON-LD Website](https://json-ld.org/)
library jsonld_format;

import 'package:rdf_core/src/graph/rdf_term.dart';
import 'package:rdf_core/src/rdf_decoder.dart';
import 'package:rdf_core/src/rdf_encoder.dart';
import 'package:rdf_core/src/vocab/namespaces.dart';

import '../plugin/rdf_graph_codec.dart';
import '../rdf_graph_decoder.dart';
import '../rdf_graph_encoder.dart';
import 'jsonld_decoder.dart';
import 'jsonld_encoder.dart';

export 'jsonld_decoder.dart' show JsonLdDecoderOptions, JsonLdDecoder;
export 'jsonld_encoder.dart' show JsonLdEncoderOptions, JsonLdEncoder;

/// RDF Format implementation for the JSON-LD serialization format.
///
/// JSON-LD (JavaScript Object Notation for Linked Data) is a method of encoding
/// Linked Data using JSON. It was designed to be easy for humans to read and write,
/// while providing a way to represent RDF data in the widely-used JSON format.
///
/// ## JSON-LD Key Concepts
///
/// JSON-LD extends JSON with several special keywords (always prefixed with @):
///
/// - **@context**: Maps terms to IRIs and defines data types for values
///   - Enables shorthand property names in place of full IRIs
///   - Specifies how to interpret values (strings, numbers, dates, etc.)
///
/// - **@id**: Uniquely identifies a node (equivalent to the subject in RDF)
///
/// - **@type**: Indicates the resource's type (equivalent to rdf:type)
///
/// - **@graph**: Contains a set of nodes in a named graph
///
/// ## Example JSON-LD Document
///
/// ```json
/// {
///   "@context": {
///     "name": "http://xmlns.com/foaf/0.1/name",
///     "knows": {
///       "@id": "http://xmlns.com/foaf/0.1/knows",
///       "@type": "@id"
///     },
///     "born": {
///       "@id": "http://example.org/born",
///       "@type": "http://www.w3.org/2001/XMLSchema#date"
///     }
///   },
///   "@id": "http://example.org/john",
///   "name": "John Smith",
///   "born": "1980-03-15",
///   "knows": [
///     {
///       "@id": "http://example.org/jane",
///       "name": "Jane Doe"
///     }
///   ]
/// }
/// ```
///
/// ## Benefits of JSON-LD
///
/// - Uses standard JSON syntax, familiar to web developers
/// - Compatible with existing JSON APIs and tools
/// - Designed to integrate easily with the web (HTTP, REST)
/// - Can express complex RDF data models in a human-readable form
/// - Supports framing, compaction, and expansion operations
///
/// ## File Extension and MIME Types
///
/// JSON-LD files typically use the `.jsonld` file extension.
/// The primary MIME type is `application/ld+json`.
final class JsonLdGraphCodec extends RdfGraphCodec {
  static const _primaryMimeType = 'application/ld+json';

  /// All MIME types that this format implementation can handle
  static const _supportedMimeTypes = {_primaryMimeType, 'application/json+ld'};

  final RdfNamespaceMappings _namespaceMappings;
  final JsonLdEncoderOptions _encoderOptions;
  final JsonLdDecoderOptions _decoderOptions;
  final IriTermFactory _iriTermFactory;

  /// Creates a new JSON-LD codec with optional configuration
  ///
  /// This constructor allows fine-grained control over JSON-LD parsing and
  /// serialization behavior through various options.
  ///
  /// Parameters:
  /// - [namespaceMappings] Custom namespace mappings for compact IRIs during serialization.
  ///   If not provided, default standard namespace mappings will be used.
  /// - [encoderOptions] Options that control JSON-LD serialization behavior.
  ///   Default settings are used if not specified.
  /// - [decoderOptions] Options that control JSON-LD parsing behavior.
  ///   Default settings are used if not specified.
  ///
  /// Example:
  /// ```dart
  /// // Assuming a predefined namespace mapping instance is available
  /// // For example, from your application configuration
  /// final myNamespaces = MyApp.getNamespaceMappings();
  ///
  /// // Create a codec that uses the application-specific namespace mappings
  /// final customCodec = JsonLdGraphCodec(
  ///   namespaceMappings: myNamespaces
  /// );
  /// ```
  const JsonLdGraphCodec({
    RdfNamespaceMappings? namespaceMappings,
    JsonLdEncoderOptions encoderOptions = const JsonLdEncoderOptions(),
    JsonLdDecoderOptions decoderOptions = const JsonLdDecoderOptions(),
    IriTermFactory iriTermFactory = IriTerm.validated,
  })  : _namespaceMappings = namespaceMappings ?? const RdfNamespaceMappings(),
        _decoderOptions = decoderOptions,
        _encoderOptions = encoderOptions,
        _iriTermFactory = iriTermFactory;

  @override
  JsonLdGraphCodec withOptions({
    RdfGraphEncoderOptions? encoder,
    RdfGraphDecoderOptions? decoder,
    IriTermFactory? iriTermFactory,
  }) =>
      JsonLdGraphCodec(
          namespaceMappings: _namespaceMappings,
          encoderOptions: JsonLdEncoderOptions.from(encoder ?? _encoderOptions),
          decoderOptions: JsonLdDecoderOptions.from(decoder ?? _decoderOptions),
          iriTermFactory: iriTermFactory ?? _iriTermFactory);

  @override
  String get primaryMimeType => _primaryMimeType;

  @override
  Set<String> get supportedMimeTypes => _supportedMimeTypes;

  @override
  RdfGraphDecoder get decoder => JsonLdDecoder(
      options: this._decoderOptions, iriTermFactory: _iriTermFactory);

  @override
  RdfGraphEncoder get encoder => JsonLdEncoder(
        namespaceMappings: this._namespaceMappings,
        options: this._encoderOptions,
      );

  @override
  bool canParse(String content) {
    // Simple heuristics for detecting JSON-LD format
    final trimmed = content.trim();

    // Must be valid JSON (starts with { or [)
    if (!(trimmed.startsWith('{') || trimmed.startsWith('['))) {
      return false;
    }

    // Must contain at least one of these JSON-LD keywords
    return trimmed.contains('"@context"') ||
        trimmed.contains('"@id"') ||
        trimmed.contains('"@type"') ||
        trimmed.contains('"@graph"');
  }
}

/// Global convenience variable for working with JSON-LD format
///
/// This variable provides direct access to the JSON-LD codec for easy
/// encoding and decoding of RDF data in JSON-LD format. It uses the default
/// configuration of [JsonLdGraphCodec] with standard namespace mappings and
/// default encoder/decoder options.
///
/// Using this global instance is recommended for most common JSON-LD operations
/// where custom configuration is not needed.
///
/// ## Dataset and Named Graph Handling
///
/// JSON-LD provides native support for RDF datasets through the `@graph` keyword.
/// When converting between JSON-LD and RDF Graphs:
///
/// - **Decoding**: When a JSON-LD document contains a top-level `@graph` property,
///   all triples from the named graphs are imported into a single [RdfGraph],
///   losing the graph names but preserving the triple data.
///
/// - **Encoding**: When an [RdfGraph] contains multiple independent subjects,
///   it is serialized as a JSON-LD document with a top-level `@graph` array,
///   which groups the data for better readability but doesn't create separate
///   named graphs in the RDF sense.
///
/// Note that the full RDF Dataset support (with multiple named graphs) is planned
/// for a future release.
///
/// ## Configuration
///
/// Parameters:
/// - Uses default [RdfNamespaceMappings] for standard namespace prefixes
/// - Uses default [JsonLdEncoderOptions] for serialization
/// - Uses default [JsonLdDecoderOptions] for parsing
///
/// ## Examples
///
/// Basic usage:
/// ```dart
/// // Decode JSON-LD string into an RDF graph
/// final jsonLdString = '''
/// {
///   "@context": {
///     "name": "http://xmlns.com/foaf/0.1/name"
///   },
///   "@id": "http://example.org/person/1",
///   "name": "John Smith"
/// }
/// ''';
/// final graph = jsonldGraph.decode(jsonLdString);
///
/// // Encode an RDF graph to JSON-LD string
/// final serialized = jsonldGraph.encode(graph);
/// ```
///
/// Working with `@graph`:
/// ```dart
/// // JSON-LD with @graph containing multiple subjects
/// final jsonWithGraph = '''
/// {
///   "@context": {
///     "name": "http://xmlns.com/foaf/0.1/name"
///   },
///   "@graph": [
///     {
///       "@id": "http://example.org/person/1",
///       "name": "Alice"
///     },
///     {
///       "@id": "http://example.org/person/2",
///       "name": "Bob"
///     }
///   ]
/// }
/// ''';
///
/// // Decodes into a single RDF graph with multiple subjects
/// final multiSubjectGraph = jsonldGraph.decode(jsonWithGraph);
/// ```
///
/// For custom JSON-LD processing options, create a specific instance of
/// [JsonLdGraphCodec] with the desired configuration.
final jsonldGraph = JsonLdGraphCodec();
