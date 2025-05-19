/// JSON-LD Parser Implementation
///
/// This library provides the implementation for parsing JSON-LD (JavaScript Object Notation
/// for Linked Data) into RDF graphs. It includes a complete JSON-LD parser that handles
/// the core features of the JSON-LD 1.1 specification.
///
/// The implementation provides:
/// - Parsing of JSON-LD documents into RDF triples
/// - Support for JSON-LD context resolution and compact IRIs
/// - Handling of nested objects and arrays
/// - Blank node normalization and consistent identity
/// - Processing of typed literals and language-tagged strings
/// - Support for @graph structures (without preserving graph names)
///
/// This library is part of the RDF Core package and uses the common RDF data model
/// defined in the graph module.
///
/// See:
/// - [JSON-LD 1.1 Specification](https://www.w3.org/TR/json-ld11/)
/// - [JSON-LD 1.1 Processing Algorithms and API](https://www.w3.org/TR/json-ld11-api/)
library jsonld_parser;

import 'dart:convert';

import 'package:logging/logging.dart';
import 'package:rdf_core/rdf_core.dart';

final _log = Logger("rdf.jsonld");
const _format = "JSON-LD";

/// Configuration options for JSON-LD decoding
///
/// This class provides configuration options for customizing the behavior of the
/// JSON-LD decoder. While the current implementation doesn't define specific options,
/// this class serves as an extension point for future enhancements to the JSON-LD parser.
///
/// Potential future options might include:
/// - Controlling how JSON-LD @graph structures are processed
/// - Customizing blank node generation behavior
/// - Specifying custom datatype handling
///
/// This class follows the pattern used throughout the RDF Core library
/// where decoders accept options objects to configure their behavior.
class JsonLdDecoderOptions extends RdfGraphDecoderOptions {
  /// Creates a new JSON-LD decoder options object with default settings
  const JsonLdDecoderOptions();

  /// Creates a JSON-LD decoder options object from generic RDF decoder options
  ///
  /// This factory method ensures that when generic [RdfGraphDecoderOptions] are provided
  /// to a method expecting JSON-LD-specific options, they are properly converted.
  ///
  /// If the provided options are already a [JsonLdDecoderOptions] instance, they are
  /// returned as-is. Otherwise, a new instance with default settings is created.
  static JsonLdDecoderOptions from(RdfGraphDecoderOptions options) =>
      switch (options) {
        JsonLdDecoderOptions _ => options,
        _ => JsonLdDecoderOptions(),
      };
}

/// Decoder for JSON-LD format
///
/// Adapter that bridges the RdfDecoder base class to the
/// implementation-specific JsonLdParser. This class is responsible for:
///
/// 1. Adapting the RDF Core decoder interface to the JSON-LD parser
/// 2. Converting parsed triples into an RdfGraph
/// 3. Managing configuration options for the parsing process
///
/// The decoder creates a flat RDF Graph from the JSON-LD input. When the
/// input contains a top-level `@graph` property (representing a named graph
/// in JSON-LD), all triples from the graph are extracted into the same RDF Graph,
/// losing the graph name information but preserving the triple data.
///
/// Example usage:
/// ```dart
/// final decoder = JsonLdDecoder();
/// final graph = decoder.convert(jsonLdString);
/// ```
class JsonLdDecoder extends RdfGraphDecoder {
  // Decoders are always expected to have options, even if they are not used at
  // the moment. But maybe the JsonLdDecoder will have options in the future.
  //
  // ignore: unused_field
  final JsonLdDecoderOptions _options;

  const JsonLdDecoder({
    JsonLdDecoderOptions options = const JsonLdDecoderOptions(),
  }) : _options = options;

  @override
  RdfGraphDecoder withOptions(RdfGraphDecoderOptions options) {
    return JsonLdDecoder(options: JsonLdDecoderOptions.from(options));
  }

  @override
  RdfGraph convert(String input, {String? documentUrl}) {
    final parser = JsonLdParser(input, baseUri: documentUrl);
    return RdfGraph.fromTriples(parser.parse());
  }
}

/// A parser for JSON-LD (JSON for Linked Data) format.
///
/// JSON-LD is a lightweight Linked Data format based on JSON. It provides a way
/// to help JSON data interoperate at Web-scale by adding semantic context to JSON data.
/// This parser supports:
///
/// - Basic JSON-LD document parsing
/// - Subject-predicate-object triple extraction
/// - Context resolution for compact IRIs
/// - Graph structure parsing (@graph)
/// - Type coercion
/// - Blank node handling
///
/// ## Named Graph Handling
///
/// When a JSON-LD document contains a top-level `@graph` property, this parser will
/// extract all triples from the named graph into a flat list of triples. The graph
/// name information itself is not preserved in the current implementation, as the
/// focus is on generating a single RDF Graph from the input.
///
/// ## Example usage:
/// ```dart
/// // Basic JSON-LD document
/// final parser = JsonLdParser('''
///   {
///     "@context": {
///       "name": "http://xmlns.com/foaf/0.1/name"
///     },
///     "@id": "http://example.com/me",
///     "name": "John Doe"
///   }
/// ''', baseUri: 'http://example.com/');
///
/// // JSON-LD document with @graph structure
/// final graphParser = JsonLdParser('''
///   {
///     "@context": {
///       "name": "http://xmlns.com/foaf/0.1/name"
///     },
///     "@graph": [
///       { "@id": "http://example.com/alice", "name": "Alice" },
///       { "@id": "http://example.com/bob", "name": "Bob" }
///     ]
///   }
/// ''', baseUri: 'http://example.com/');
///
/// // All triples from both objects in the @graph will be extracted into a
/// // single flat list and merged into one RDF Graph.
/// ```
///
/// See: [JSON-LD 1.1 Processing Algorithms and API](https://www.w3.org/TR/json-ld11-api/)
class JsonLdParser {
  final String _input;
  final String? _baseUri;

  // Map to store consistent blank node instances across the parsing process
  final Map<String, BlankNodeTerm> _blankNodeCache = {};

  /// Common prefixes used in JSON-LD documents
  static const Map<String, String> _commonPrefixes = {
    'rdf': 'http://www.w3.org/1999/02/22-rdf-syntax-ns#',
    'rdfs': 'http://www.w3.org/2000/01/rdf-schema#',
    'xsd': 'http://www.w3.org/2001/XMLSchema#',
    'owl': 'http://www.w3.org/2002/07/owl#',
    'solid': 'http://www.w3.org/ns/solid/terms#',
    'space': 'http://www.w3.org/ns/pim/space#',
    'ldp': 'http://www.w3.org/ns/ldp#',
    'pim': 'http://www.w3.org/ns/pim/space#',
    'foaf': 'http://xmlns.com/foaf/0.1/',
    'schema': 'http://schema.org/',
    'dc': 'http://purl.org/dc/terms/',
  };

  /// Creates a new JSON-LD parser for the given input string.
  ///
  /// [input] is the JSON-LD document to parse.
  /// [baseUri] is the base URI against which relative IRIs should be resolved.
  /// If not provided, relative IRIs will be kept as-is.
  JsonLdParser(String input, {String? baseUri})
      : _input = input,
        _baseUri = baseUri;

  /// Parses the JSON-LD input and returns a list of triples.
  ///
  /// This method processes the input by:
  /// 1. Parsing the JSON document
  /// 2. Extracting the @context if present
  /// 3. Processing the document structure to generate RDF triples
  ///
  /// The method handles both single JSON objects and arrays of JSON objects.
  /// It also processes the `@graph` property if present, extracting all contained
  /// nodes as separate entities in the resulting RDF graph.
  ///
  /// Throws [RdfSyntaxException] if the input is not valid JSON-LD.
  ///
  /// Returns a flat list of [Triple] objects that can be used to construct an
  /// RDF Graph. Graph names are not preserved in the current implementation.
  List<Triple> parse() {
    try {
      _log.info('Starting JSON-LD parsing');
      final dynamic jsonData;

      try {
        jsonData = json.decode(_input);
      } catch (e) {
        throw RdfSyntaxException(
          'Invalid JSON syntax: ${e.toString()}',
          format: _format,
          cause: e,
        );
      }

      final triples = <Triple>[];

      if (jsonData is List) {
        _log.info('Parsing JSON-LD array');
        // Handle JSON-LD array
        for (final item in jsonData) {
          if (item is Map<String, dynamic>) {
            triples.addAll(_processNode(item));
          } else {
            _log.warning('Skipping non-object item in JSON-LD array');
            throw RdfSyntaxException(
              'Array item must be a JSON object',
              format: _format,
            );
          }
        }
      } else if (jsonData is Map<String, dynamic>) {
        _log.info('Parsing JSON-LD object');
        // Handle JSON-LD object
        triples.addAll(_processNode(jsonData));
      } else {
        _log.severe('JSON-LD must be an object or array at the top level');
        throw RdfSyntaxException(
          'Invalid JSON-LD: must be an object or array at the top level',
          format: _format,
        );
      }

      _log.info('JSON-LD parsing complete. Found ${triples.length} triples');
      return triples;
    } catch (e, stack) {
      if (e is RdfException) {
        // Re-throw RDF exceptions as-is
        rethrow;
      }

      _log.severe('Failed to parse JSON-LD', e, stack);
      throw RdfSyntaxException(
        'JSON-LD parsing error: ${e.toString()}',
        format: _format,
        cause: e,
      );
    }
  }

  /// Process a JSON-LD node and extract triples
  ///
  /// Takes a JSON-LD node (a JSON object with potential "@" keywords) and converts
  /// it to a list of RDF triples. This method:
  ///
  /// 1. Extracts the context definitions
  /// 2. Processes any `@graph` property if present
  /// 3. For each node in the graph (or the node itself), extracts subject, predicates and objects
  ///
  /// Special handling is performed for the `@graph` property, which contains an array
  /// of nodes. Each node in the `@graph` is processed independently, and all resulting
  /// triples are merged into a single flat list. The graph name itself is not preserved
  /// in the current implementation.
  List<Triple> _processNode(Map<String, dynamic> node) {
    final triples = <Triple>[];
    final context = _extractContext(node);

    // Handle @graph property if present
    if (node.containsKey('@graph')) {
      _log.info('Processing @graph structure');
      final graph = node['@graph'];

      if (graph is List) {
        for (final item in graph) {
          if (item is Map<String, dynamic>) {
            // Pass context to each graph item
            triples.addAll(_extractTriples(item, context));
          }
        }
      }
      return triples;
    }

    // Process regular node
    triples.addAll(_extractTriples(node, context));

    return triples;
  }

  /// Extract context from JSON-LD node
  ///
  /// Builds a context mapping from prefixes to namespace IRIs by:
  ///
  /// 1. Starting with common well-known prefixes as defaults
  /// 2. Extracting JSON-LD @context entries if present
  /// 3. Handling both simple string mappings and complex object mappings with @id
  ///
  /// The context is used for expanding compact IRIs and term definitions
  /// in the JSON-LD document. For example, with a context mapping "foaf" to
  /// "http://xmlns.com/foaf/0.1/", a property "foaf:name" would expand to
  /// "http://xmlns.com/foaf/0.1/name".
  ///
  /// Returns a map from prefix to namespace IRI.
  Map<String, String> _extractContext(Map<String, dynamic> node) {
    final context = <String, String>{};

    // Add common prefixes as default context
    context.addAll(_commonPrefixes);

    // Extract @context if present
    if (node.containsKey('@context')) {
      final nodeContext = node['@context'];

      if (nodeContext is Map<String, dynamic>) {
        for (final entry in nodeContext.entries) {
          if (entry.value is String) {
            context[entry.key] = entry.value as String;
            _log.info('Found context mapping: ${entry.key} -> ${entry.value}');
          } else if (entry.value is Map<String, dynamic>) {
            // Handle complex context definitions
            final valueMap = entry.value as Map<String, dynamic>;
            if (valueMap.containsKey('@id')) {
              context[entry.key] = valueMap['@id'] as String;
              _log.info(
                'Found complex context mapping: ${entry.key} -> ${valueMap['@id']}',
              );
            }
          }
        }
      }
    }

    return context;
  }

  /// Extract triples from a JSON-LD node
  ///
  /// This method takes a JSON-LD node and converts it to a collection of RDF triples by:
  ///
  /// 1. Determining the subject (using @id if present, or generating a blank node)
  /// 2. Processing all properties of the node
  /// 3. Handling @type specially, converting it to rdf:type triples
  /// 4. Processing other properties based on their values (literals, IRIs, objects)
  ///
  /// The method uses the provided context to expand compact IRIs and property names.
  /// It handles different value types appropriately:
  /// - String values may be converted to literals or IRIs depending on their format
  /// - Numbers are converted to typed literals with xsd:integer or xsd:decimal
  /// - Booleans are converted to xsd:boolean literals
  /// - Object values are processed recursively, potentially creating blank nodes
  ///
  /// [node] The JSON-LD node to process
  /// [context] The context containing prefix mappings for IRI expansion
  ///
  /// Returns a list of RDF triples extracted from the node
  List<Triple> _extractTriples(
    Map<String, dynamic> node,
    Map<String, String> context,
  ) {
    final triples = <Triple>[];

    // Determine the subject
    final String subjectStr = _getSubjectId(node);
    final subject = _createSubjectTerm(subjectStr);
    _log.info('Processing node with subject: $subject');

    // Process all properties except @context and @id
    for (final entry in node.entries) {
      final key = entry.key;
      final value = entry.value;

      // Skip JSON-LD keywords except @type
      if (key.startsWith('@')) {
        if (key == '@type') {
          // Handle @type specially to generate rdf:type triples
          _processType(subject, value, triples, context);
        }
        continue;
      } // Expand predicate using context
      final predicateStr = _expandPredicate(key, context);
      final predicate = IriTerm(predicateStr);
      _log.info('Processing property: $key -> $predicate');

      if (value is List) {
        // Handle array values
        for (final item in value) {
          _addTripleForValue(subject, predicate, item, triples, context);
        }
      } else {
        // Handle single value
        _addTripleForValue(subject, predicate, value, triples, context);
      }
    }

    return triples;
  }

  /// Create appropriate RDF term for a subject
  RdfSubject _createSubjectTerm(String subject) {
    if (subject.startsWith('_:')) {
      // Use the blank node cache to maintain consistent identity
      return _getOrCreateBlankNode(subject);
    } else {
      return IriTerm(subject);
    }
  }

  /// Gets an existing BlankNodeTerm or creates a new one with consistent identity
  BlankNodeTerm _getOrCreateBlankNode(String label) {
    return _blankNodeCache.putIfAbsent(label, () {
      final blankNode = BlankNodeTerm();
      _log.info('Created blank node for label $label: $blankNode');
      return blankNode;
    });
  }

  /// Get the subject identifier from a node
  String _getSubjectId(Map<String, dynamic> node) {
    if (node.containsKey('@id')) {
      final id = node['@id'];

      if (id is! String) {
        throw RdfSyntaxException('@id value must be a string', format: _format);
      }

      // First expand any prefixes using the context
      final context = _extractContext(node);
      final expandedId = _expandPrefixedIri(id, context);

      // Resolve relative IRIs against the base URI if one is provided
      if (_baseUri != null &&
          !expandedId.contains('://') &&
          !expandedId.startsWith('_:')) {
        return Uri.parse(_baseUri).resolve(expandedId).toString();
      }

      return expandedId;
    }

    // Generate blank node identifier if no @id is present
    return '_:b${node.hashCode.abs()}';
  }

  /// Expand a prefixed IRI using the context
  String _expandPrefixedIri(String iri, Map<String, String> context) {
    // If it's already a full IRI or a blank node, return as is
    if (iri.startsWith('http://') ||
        iri.startsWith('https://') ||
        iri.startsWith('_:')) {
      return iri;
    }

    // Handle prefixed name (e.g., ex:subject)
    if (iri.contains(':')) {
      final parts = iri.split(':');
      if (parts.length == 2 && context.containsKey(parts[0])) {
        return '${context[parts[0]]}${parts[1]}';
      }
    }

    // Direct match in context
    if (context.containsKey(iri)) {
      return context[iri]!;
    }

    // Return the IRI as-is if we can't resolve it
    _log.warning('Could not expand prefixed IRI: $iri');
    return iri;
  }

  /// Process @type value and add appropriate triples
  void _processType(
    RdfSubject subject,
    dynamic typeValue,
    List<Triple> triples,
    Map<String, String> context,
  ) {
    final typePredicate = IriTerm(
      'http://www.w3.org/1999/02/22-rdf-syntax-ns#type',
    );

    if (typeValue is List) {
      for (final type in typeValue) {
        if (type is String) {
          final expandedType = _expandPredicate(type, context);
          triples.add(Triple(subject, typePredicate, IriTerm(expandedType)));
          _log.info(
            'Added type triple: $subject -> $typePredicate -> $expandedType',
          );
        }
      }
    } else if (typeValue is String) {
      final expandedType = _expandPredicate(typeValue, context);
      triples.add(Triple(subject, typePredicate, IriTerm(expandedType)));
      _log.info(
        'Added type triple: $subject -> $typePredicate -> $expandedType',
      );
    } else if (typeValue is Map<String, dynamic>) {
      // Handle case when @type is an object with @id
      if (typeValue.containsKey('@id')) {
        final typeId = typeValue['@id'];
        if (typeId is String) {
          final expandedType = _expandPredicate(typeId, context);
          triples.add(Triple(subject, typePredicate, IriTerm(expandedType)));
          _log.info(
            'Added type triple from object: $subject -> $typePredicate -> $expandedType',
          );
        }
      }
    }
  }

  /// Add a triple for a given value
  ///
  /// This method creates appropriate RDF triples based on the type and structure of the value.
  /// It handles the various ways values can be represented in JSON-LD:
  ///
  /// - **String values**: Interpreted as IRIs if they start with http:// or https://,
  ///   or if they can be expanded using the context. Otherwise treated as string literals.
  ///
  /// - **Numeric values**: Converted to typed literals with appropriate XSD datatype
  ///   (integer or decimal)
  ///
  /// - **Boolean values**: Converted to typed literals with xsd:boolean datatype
  ///
  /// - **Object values**: Processed according to their structure:
  ///   * Objects with @id: Treated as references to other resources
  ///   * Objects with @value: Treated as literal values, possibly with datatype or language
  ///   * Other objects: Treated as blank nodes and processed recursively
  ///
  /// This versatile handling allows for the full range of JSON-LD value representations
  /// to be properly converted to RDF triples.
  ///
  /// The [subject] is the subject of the triple.
  /// The [predicate] is the predicate of the triple.
  /// The [value] is the value to convert to an RDF object term.
  /// The [triples] is the list to add the created triple(s) to.
  /// The [context] is the context for IRI expansion.
  void _addTripleForValue(
    RdfSubject subject,
    RdfPredicate predicate,
    dynamic value,
    List<Triple> triples,
    Map<String, String> context,
  ) {
    if (value is String) {
      // Simple literal or IRI value
      if (value.startsWith('http://') || value.startsWith('https://')) {
        // Treat as IRI
        triples.add(Triple(subject, predicate, IriTerm(value)));
        _log.info('Added IRI triple: $subject -> $predicate -> $value');
      } else if (value.contains(':')) {
        // Check if it's a prefixed IRI like "schema:name"
        final expanded = _expandPrefixedIri(value, context);
        if (expanded != value) {
          // Was expanded, so treat as IRI
          triples.add(Triple(subject, predicate, IriTerm(expanded)));
          _log.info(
            'Added expanded IRI triple: $subject -> $predicate -> $expanded (from $value)',
          );
        } else {
          // Wasn't expanded, treat as literal
          triples.add(Triple(subject, predicate, LiteralTerm.string(value)));
          _log.info('Added literal triple: $subject -> $predicate -> "$value"');
        }
      } else {
        // Treat as literal
        triples.add(Triple(subject, predicate, LiteralTerm.string(value)));
        _log.info('Added literal triple: $subject -> $predicate -> "$value"');
      }
    } else if (value is num) {
      // Numeric literal
      final datatype = value is int ? 'integer' : 'decimal';
      triples.add(
        Triple(
          subject,
          predicate,
          LiteralTerm.typed(value.toString(), datatype),
        ),
      );
      _log.info(
        'Added numeric literal triple: $subject -> $predicate -> $value',
      );
    } else if (value is bool) {
      // Boolean literal
      triples.add(
        Triple(
          subject,
          predicate,
          LiteralTerm.typed(value.toString(), 'boolean'),
        ),
      );
      _log.info(
        'Added boolean literal triple: $subject -> $predicate -> $value',
      );
    } else if (value is Map<String, dynamic>) {
      // Object value (nested node or value with metadata)
      if (value.containsKey('@id')) {
        // Reference to another resource
        final objectId = value['@id'] as String;
        final expandedIri = _expandIri(objectId);
        final RdfObject objectTerm = expandedIri.startsWith('_:')
            ? _getOrCreateBlankNode(expandedIri)
            : IriTerm(expandedIri);

        triples.add(Triple(subject, predicate, objectTerm));
        _log.info(
          'Added object reference triple: $subject -> $predicate -> $expandedIri',
        );

        // If the object has more properties, process it recursively
        if (value.keys.any((k) => !k.startsWith('@'))) {
          triples.addAll(_extractTriples(value, context));
        }
      } else if (value.containsKey('@value')) {
        // Typed or language-tagged literal
        final literalValue = value['@value'].toString();
        LiteralTerm objectTerm;

        if (value.containsKey('@type')) {
          // Typed literal with datatype IRI
          final typeIri = value['@type'] as String;
          objectTerm = LiteralTerm(literalValue, datatype: IriTerm(typeIri));
        } else if (value.containsKey('@language')) {
          // Language-tagged literal
          final language = value['@language'] as String;
          objectTerm = LiteralTerm.withLanguage(literalValue, language);
        } else {
          // Simple literal
          objectTerm = LiteralTerm.string(literalValue);
        }

        triples.add(Triple(subject, predicate, objectTerm));
        _log.info(
          'Added complex literal triple: $subject -> $predicate -> $objectTerm',
        );
      } else {
        // Blank node
        final blankNodeId = '_:b${value.hashCode.abs()}';
        final blankNode = _getOrCreateBlankNode(blankNodeId);

        triples.add(Triple(subject, predicate, blankNode));
        _log.info(
          'Added blank node triple: $subject -> $predicate -> $blankNodeId',
        );

        // Process the blank node recursively
        value['@id'] = blankNodeId;
        triples.addAll(_extractTriples(value, context));
      }
    }
  }

  /// Expand a predicate using the context
  ///
  /// This method expands a predicate term (key in the JSON-LD document) to its full IRI form
  /// using the provided context. It handles several expansion patterns:
  ///
  /// 1. Direct term definitions - where a term like "name" is mapped directly to an IRI
  /// 2. Prefixed IRIs - where a term like "foaf:name" uses a prefix defined in the context
  /// 3. Chained expansions - where an expansion might need to be expanded again
  ///
  /// For example:
  /// - With context {"name": "http://xmlns.com/foaf/0.1/name"}, the key "name" expands to "http://xmlns.com/foaf/0.1/name"
  /// - With context {"foaf": "http://xmlns.com/foaf/0.1/"}, the key "foaf:name" expands to "http://xmlns.com/foaf/0.1/name"
  ///
  /// The [key] parameter is the predicate key to expand.
  /// The [context] parameter contains prefix mappings.
  /// Returns the expanded IRI for the predicate.
  String _expandPredicate(String key, Map<String, String> context) {
    // Check direct match in context first - this is for cases like
    // where "name" is defined to be "schema:name" or a full IRI
    if (context.containsKey(key)) {
      final value = context[key]!;
      // If value is a prefixed IRI, expand it further
      if (value.contains(':') &&
          !value.startsWith('http://') &&
          !value.startsWith('https://')) {
        return _expandPrefixedIri(value, context);
      }
      return value;
    }

    // Otherwise try to expand as a prefixed IRI
    return _expandPrefixedIri(key, context);
  }

  /// Expand an IRI using the base URI if needed
  String _expandIri(String iri) {
    if (iri.startsWith('http://') ||
        iri.startsWith('https://') ||
        iri.startsWith('_:')) {
      return iri;
    }

    // Try to resolve against base URI if available
    if (_baseUri != null) {
      try {
        return Uri.parse(_baseUri).resolve(iri).toString();
      } catch (e) {
        _log.warning('Failed to resolve IRI against base URI: $iri', e);
        throw RdfInvalidIriException(
          'Failed to resolve IRI against base URI',
          iri: iri,
          format: _format,
          cause: e,
        );
      }
    }

    return iri;
  }
}
