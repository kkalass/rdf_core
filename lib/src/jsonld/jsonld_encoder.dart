/// JSON-LD Serializer Implementation
///
/// Implements the [JsonLdEncoder] class to convert RDF graphs to JSON-LD format.
/// JSON-LD (JavaScript Object Notation for Linked Data) allows the representation
/// of RDF data in a human-readable and machine-processable format,
/// based on the widely used JSON standard.
///
/// This implementation supports:
/// - Compact JSON-LD documents with meaningful prefixes
/// - Automatic detection and generation of appropriate `@context` definitions
/// - Grouping of data by subjects for better readability
/// - Special handling of Blank Nodes with consistent identifiers
/// - Generation of `@graph` for graphs with multiple subjects
/// - Conversion of typed literals to appropriate JSON representations
///
/// ## Graph Structure Detection
///
/// The encoder automatically analyzes the structure of the input graph:
/// - For single-subject graphs, it creates a simple JSON-LD object
/// - For multi-subject graphs, it uses a top-level `@graph` array
///
/// The current implementation does not maintain named graph information
/// when serializing RDF graphs. The use of `@graph` in the output is purely
/// for structural organization, not for representing true RDF Dataset named graphs.
///
/// ## Example usage:
/// ```dart
/// import 'package:rdf_core/rdf_core.dart';
///
/// // Using the global encoder
/// final jsonld = jsonldGraph.encode(graph);
///
/// // Or directly with the encoder
/// final encoder = JsonLdEncoder();
/// final jsonld = encoder.convert(graph);
/// ```
///
/// See also:
/// - [JSON-LD 1.1 Specification](https://www.w3.org/TR/json-ld11/)
/// - [JSON-LD Website](https://json-ld.org/)
library jsonld_serializer;

import 'dart:convert';

import 'package:logging/logging.dart';
import 'package:rdf_core/src/graph/rdf_graph.dart';
import 'package:rdf_core/src/graph/rdf_term.dart';
import 'package:rdf_core/src/graph/triple.dart';
import 'package:rdf_core/src/rdf_encoder.dart';
import 'package:rdf_core/src/iri_compaction.dart';
import 'package:rdf_core/src/vocab/namespaces.dart';
import 'package:rdf_core/src/vocab/rdf.dart';
import 'package:rdf_core/src/vocab/xsd.dart';

final _log = Logger("rdf.jsonld");

/// Configuration options for JSON-LD encoding
///
/// This class provides configuration options for customizing the behavior of the
/// JSON-LD encoder. It extends the base RDF encoder options to add JSON-LD specific
/// functionality.
///
/// Currently, the main customization is the ability to provide custom prefixes
/// for the JSON-LD context, allowing for more readable and application-specific
/// compact IRIs in the output.
///
/// Potential future options might include:
/// - Control over formatting (compact vs. expanded form)
/// - Custom handling of complex datatypes
/// - Options for including/excluding @context
/// - Named graph serialization settings
///
/// Example usage:
/// ```dart
/// final options = JsonLdEncoderOptions(
///   customPrefixes: {
///     'ex': 'http://example.org/',
///     'app': 'http://myapp.com/terms#'
///   }
/// );
///
/// final encoder = JsonLdEncoder(options: options);
/// ```
class JsonLdEncoderOptions extends RdfGraphEncoderOptions {
  /// Controls automatic generation of namespace prefixes for IRIs without matching prefixes.
  ///
  /// When set to `true` (default), the encoder will automatically generate namespace
  /// prefixes for IRIs that don't have a matching prefix in either the custom prefixes
  /// or the standard namespace mappings.
  ///
  /// The prefix generation process:
  /// 1. Attempts to extract a meaningful namespace from the IRI (splitting at '/' or '#')
  /// 2. Skips IRIs with only protocol specifiers (e.g., "http://")
  /// 3. Only generates prefixes for namespaces ending with '/' or '#'
  ///    (proper RDF namespace delimiters)
  /// 4. Uses RdfNamespaceMappings.getOrGeneratePrefix to create a compact, unique prefix
  ///
  /// Setting this to `false` will result in all IRIs without matching prefixes being
  /// written as full IRIs in the JSON-LD output.
  ///
  /// This option is particularly useful for:
  /// - Reducing the verbosity of the JSON-LD output
  /// - Making the serialized data more human-readable
  /// - Automatically handling unknown namespaces without manual prefix declaration
  final bool generateMissingPrefixes;

  /// Whether to include base URI declarations in the output
  ///
  /// This option only applies when a baseUri is provided during encoding.
  /// When true and a baseUri is provided, the serializer includes the base URI
  /// declaration in the format-specific way (e.g., @base in Turtle, @base in JSON-LD context).
  /// When false, the baseUri is still used for URI relativization but not declared in the output.
  /// Has no effect if no baseUri is provided during encoding.
  final bool includeBaseDeclaration;

  /// Creates a new JSON-LD encoder options object
  ///
  /// [customPrefixes] A map of prefix to namespace URI pairs that will be used
  /// in the JSON-LD @context. These prefixes take precedence over standard prefixes
  /// if there are conflicts.
  /// [generateMissingPrefixes] When true (default), the encoder will automatically
  /// generate prefix declarations for IRIs that don't have a matching prefix.
  /// [includeBaseDeclaration] Whether to include base URI declarations in the output.
  /// Defaults to true if not provided.
  const JsonLdEncoderOptions({
    Map<String, String> customPrefixes = const {},
    bool generateMissingPrefixes = true,
    bool includeBaseDeclaration = true,
  })  : generateMissingPrefixes = generateMissingPrefixes,
        includeBaseDeclaration = includeBaseDeclaration,
        super(
          customPrefixes: customPrefixes,
        );

  JsonLdEncoderOptions copyWith({
    Map<String, String>? customPrefixes,
    bool? generateMissingPrefixes,
    bool? includeBaseDeclaration,
  }) =>
      JsonLdEncoderOptions(
        customPrefixes: customPrefixes ?? this.customPrefixes,
        generateMissingPrefixes:
            generateMissingPrefixes ?? this.generateMissingPrefixes,
        includeBaseDeclaration:
            includeBaseDeclaration ?? this.includeBaseDeclaration,
      );

  /// Creates a JSON-LD encoder options object from generic RDF encoder options
  ///
  /// This factory method ensures that when generic [RdfGraphEncoderOptions] are provided
  /// to a method expecting JSON-LD-specific options, they are properly converted.
  ///
  /// If the provided options are already a [JsonLdEncoderOptions] instance, they are
  /// returned as-is. Otherwise, a new instance is created with the custom prefixes
  /// and default values for generateMissingPrefixes and includeBaseDeclaration.
  static JsonLdEncoderOptions from(RdfGraphEncoderOptions options) =>
      switch (options) {
        JsonLdEncoderOptions _ => options,
        _ => JsonLdEncoderOptions(
            customPrefixes: options.customPrefixes,
          ),
      };
}

const _stringDatatype = Xsd.string;
const _integerDatatype = Xsd.integer;
const _doubleDatatype = Xsd.double;
const _decimalDatatype = Xsd.decimal;
const _booleanDatatype = Xsd.boolean;

/// Encoder for converting RDF graphs to JSON-LD format.
///
/// JSON-LD is a lightweight Linked Data format that is easy for humans to read
/// and write and easy for machines to parse and generate. This serializer
/// transforms RDF data into compact, structured JSON documents by:
///
/// - Grouping triples by subject
/// - Creating a @context section for namespace prefixes
/// - Nesting objects for more readable representation
/// - Handling different RDF term types appropriately
///
/// ## Graph Structure Handling
///
/// The encoder automatically detects the structure of the input graph:
///
/// - **Single Subject**: When the graph contains triples with only one subject,
///   the output is a single JSON-LD object with properties representing predicates.
///
/// - **Multiple Subjects**: When the graph contains triples with multiple subjects,
///   the encoder generates a JSON-LD document with a top-level `@graph` array
///   containing all subject nodes. This produces more readable output by
///   structuring the data naturally.
///
/// ## @graph and Named Graphs
///
/// Note that the current implementation does not support true RDF Datasets with
/// named graphs. When outputting a graph with multiple subjects as `@graph`,
/// this does not represent different named graphs but rather is a structural
/// device for organizing multiple nodes in the default graph.
///
/// In JSON-LD, a top-level `@graph` array can be used for two different purposes:
/// 1. As a way to organize multiple unrelated nodes (current implementation)
/// 2. As a way to represent named graphs in an RDF dataset (future enhancement)
///
/// ## Datatype Handling
///
/// The encoder handles various RDF literal types and automatically converts them
/// to appropriate JSON representations:
///
/// - String literals are represented as JSON strings
/// - Integer literals are converted to JSON numbers when possible
/// - Boolean literals are converted to JSON booleans when possible
/// - Other datatypes use the `@value` and `@type` syntax
///
/// ## Configuration Options
///
/// The serializer produces compacted JSON-LD by default, using prefixes
/// to make property names more readable. Customizations are possible
/// through namespace mappings and encoder options.
final class JsonLdEncoder extends RdfGraphEncoder {
  /// Well-known common prefixes used for more readable JSON-LD output.
  final RdfNamespaceMappings _namespaceMappings;
  final JsonLdEncoderOptions _options;
  late final IriCompaction _iriCompaction;
  final _useNumericLocalNames = true;

  /// Creates a new JSON-LD serializer.
  JsonLdEncoder({
    RdfNamespaceMappings? namespaceMappings,
    JsonLdEncoderOptions options = const JsonLdEncoderOptions(),
  })  : _options = options,
        _namespaceMappings = namespaceMappings ?? const RdfNamespaceMappings() {
    _iriCompaction = IriCompaction(
        _namespaceMappings,
        IriCompactionSettings(
            generateMissingPrefixes: options.generateMissingPrefixes,
            allowedCompactionTypes: {
              ...allowedCompactionTypesAll,
              IriRole.predicate: {
                IriCompactionType.full,
                // relative IRIs are not allowed for predicates in jsonld
                IriCompactionType.prefixed
              }
            },
            specialPredicates: {
              Rdf.type,
            },
            specialDatatypes: {
              _booleanDatatype,
              _decimalDatatype,
              _doubleDatatype,
              _integerDatatype,
              _stringDatatype,
              Rdf.langString,
            }),
        (String localPart) => RdfNamespaceMappings.isValidLocalPart(localPart,
            allowNumericLocalNames: _useNumericLocalNames));
  }

  @override
  RdfGraphEncoder withOptions(RdfGraphEncoderOptions options) => JsonLdEncoder(
        namespaceMappings: _namespaceMappings,
        options: JsonLdEncoderOptions.from(options),
      );

  /// Converts an RDF graph to a JSON-LD string representation.
  ///
  /// This method analyzes the graph structure and automatically determines
  /// the most appropriate JSON-LD representation:
  ///
  /// - For empty graphs, it returns an empty JSON object `{}`
  /// - For graphs with a single subject, it creates a single JSON-LD object
  ///   with all properties of that subject
  /// - For graphs with multiple subjects, it creates a JSON-LD document with
  ///   a top-level `@graph` array containing all subject nodes
  ///
  /// The method also:
  /// - Generates consistent labels for blank nodes
  /// - Creates a `@context` object with meaningful prefixes based on the graph content
  /// - Groups triples by subject for better structure
  /// - Handles typed literals appropriately
  ///
  /// [graph] The RDF graph to convert to JSON-LD.
  /// [baseUri] Optional base URI for relative IRIs. When provided and
  /// includeBaseDeclaration is true, it will be included in the @context.
  ///
  /// Returns a formatted JSON-LD string with 2-space indentation.
  @override
  String convert(RdfGraph graph, {String? baseUri}) {
    _log.info('Serializing graph to JSON-LD');

    // Return empty JSON object for empty graph
    if (graph.isEmpty) {
      return '{}';
    }

    // Map for tracking BlankNodeTerm to label assignments
    final Map<BlankNodeTerm, String> blankNodeLabels = {};
    _generateBlankNodeLabels(graph, blankNodeLabels);

    // Create context with prefixes and optional base URI
    final (context: context, compactedIris: compactedIris) = _createContext(
      graph,
      _options.customPrefixes,
      baseUri: baseUri,
      includeBaseDeclaration: _options.includeBaseDeclaration,
      generateMissingPrefixes: _options.generateMissingPrefixes,
    );

    // Group triples by subject
    final subjectGroups = _groupTriplesBySubject(graph.triples);

    // Check if we have only one subject group or multiple
    // For a single subject we create a JSON object, for multiple we use a JSON array
    if (subjectGroups.length == 1) {
      final Map<String, dynamic> result = {'@context': context};

      // Add the single subject node
      final entry = subjectGroups.entries.first;
      final subjectNode = _createNodeObject(
          entry.key, entry.value, context, blankNodeLabels,
          compactedIris: compactedIris);
      result.addAll(subjectNode);

      return JsonEncoder.withIndent('  ').convert(result);
    } else {
      // Create a @graph structure for multiple subjects
      final Map<String, dynamic> result = {
        '@context': context,
        '@graph': subjectGroups.entries.map((entry) {
          return _createNodeObject(
              entry.key, entry.value, context, blankNodeLabels,
              compactedIris: compactedIris);
        }).toList(),
      };

      return JsonEncoder.withIndent('  ').convert(result);
    }
  }

  /// Generates unique labels for all blank nodes in the graph.
  ///
  /// This ensures consistent labels throughout a single serialization.
  void _generateBlankNodeLabels(
    RdfGraph graph,
    Map<BlankNodeTerm, String> blankNodeLabels,
  ) {
    var counter = 0;

    // First pass: collect all blank nodes from the graph
    for (final triple in graph.triples) {
      if (triple.subject is BlankNodeTerm) {
        final blankNode = triple.subject as BlankNodeTerm;
        if (!blankNodeLabels.containsKey(blankNode)) {
          blankNodeLabels[blankNode] = 'b${counter++}';
        }
      }

      if (triple.object is BlankNodeTerm) {
        final blankNode = triple.object as BlankNodeTerm;
        if (!blankNodeLabels.containsKey(blankNode)) {
          blankNodeLabels[blankNode] = 'b${counter++}';
        }
      }
    }
  }

  /// Creates the @context object with prefix mappings.
  ///
  /// The context is a key part of JSON-LD that defines how predicates and types
  /// are expanded to full IRIs. This method:
  ///
  /// 1. Starts with any custom prefixes provided by the user
  /// 2. Analyzes the graph to determine which standard prefixes are actually used
  /// 3. Adds only those namespaces that are referenced by IRIs in the graph
  /// 4. Optionally generates new prefixes for unknown namespaces when generateMissingPrefixes is true
  ///
  /// This produces a minimal, relevant context that makes the JSON-LD more compact
  /// and readable while still maintaining the complete semantic information.
  ///
  /// Custom prefixes always take precedence over standard ones if there's a conflict.
  ({Map<String, dynamic> context, IriCompactionResult compactedIris})
      _createContext(
    RdfGraph graph,
    Map<String, String> customPrefixes, {
    String? baseUri,
    bool includeBaseDeclaration = true,
    bool generateMissingPrefixes = true,
  }) {
    final context = <String, dynamic>{};

    // Add base URI if provided and includeBaseDeclaration is true
    if (baseUri != null && includeBaseDeclaration) {
      context['@base'] = baseUri;
    }

    // Add all custom prefixes
    context.addAll(customPrefixes);

    // Add common prefixes that are used in the graph
    final compactedIris = _iriCompaction.compactAllIris(
      graph,
      customPrefixes,
      baseUri: baseUri,
    );

    // Add prefixes that don't conflict with custom ones
    for (final entry in compactedIris.prefixes.entries) {
      if (!customPrefixes.containsKey(entry.key)) {
        context[entry.key] = entry.value;
      }
    }

    return (context: context, compactedIris: compactedIris);
  }

  /// Groups triples by their subject for easier JSON-LD structure creation.
  ///
  /// This method organizes triples into a map where each subject is associated with
  /// all of its triples. This grouping is essential for the JSON-LD structure, which
  /// naturally organizes data by subject rather than as flat triples.
  ///
  /// For example, if we have triples:
  /// - (subject1, predicate1, object1)
  /// - (subject1, predicate2, object2)
  /// - (subject2, predicate1, object3)
  ///
  /// The resulting map would be:
  /// - subject1 → [(subject1, predicate1, object1), (subject1, predicate2, object2)]
  /// - subject2 → [(subject2, predicate1, object3)]
  ///
  /// This structure makes it easy to create JSON-LD objects for each subject with
  /// all its properties, whether converting to a single object or a @graph array
  /// of multiple subject nodes.
  ///
  /// The [triples] parameter is a list of RDF triples to group.
  /// Returns a map from subjects to lists of triples with that subject.
  Map<RdfSubject, List<Triple>> _groupTriplesBySubject(List<Triple> triples) {
    final Map<RdfSubject, List<Triple>> result = {};

    for (final triple in triples) {
      result.putIfAbsent(triple.subject, () => []).add(triple);
    }

    return result;
  }

  /// Creates a JSON object representing an RDF node with all its properties.
  ///
  /// This method transforms an RDF subject and its associated triples into a
  /// structured JSON-LD object by:
  ///
  /// 1. Setting the `@id` property to identify the subject (relative to baseUri if applicable)
  /// 2. Handling `rdf:type` statements specially by converting them to `@type` properties
  /// 3. Grouping remaining triples by predicate to create JSON-LD properties
  /// 4. Rendering single values directly and multiple values as arrays
  /// 5. Properly encoding IRIs, blank nodes, and literals according to JSON-LD rules
  ///
  /// For example, an RDF resource with multiple types and properties will be converted
  /// into a JSON object with the appropriate structure and compaction based on the context.
  ///
  /// [subject] The RDF subject to convert
  /// [triples] The list of triples where this subject is the subject
  /// [context] The JSON-LD context for compaction
  /// [blankNodeLabels] Mapping of blank nodes to consistent labels
  /// [compactedIris] The compacted IRIs for this context
  ///
  /// Returns a JSON-LD object representing the RDF node
  Map<String, dynamic> _createNodeObject(
    RdfSubject subject,
    List<Triple> triples,
    Map<String, dynamic> context,
    Map<BlankNodeTerm, String> blankNodeLabels, {
    required IriCompactionResult compactedIris,
  }) {
    Map<String, dynamic> result = createSubjectObject(
        subject, IriRole.subject, compactedIris, blankNodeLabels);
    // Group triples by predicate
    final predicateGroups = <String, List<RdfObject>>{};
    final typeObjects = <RdfObject>[];

    for (final triple in triples) {
      if (triple.predicate == Rdf.type) {
        // Handle rdf:type specially
        typeObjects.add(triple.object);
      } else {
        final predicateKey = _getPredicateKey(triple.predicate, compactedIris);
        predicateGroups.putIfAbsent(predicateKey, () => []).add(triple.object);
      }
    }

    // Add types to the result
    if (typeObjects.isNotEmpty) {
      if (typeObjects.length == 1) {
        // Single type - for @type, we use the IRI directly, not wrapped in @id
        result['@type'] = _getTypeValue(typeObjects[0],
            compactedIris: compactedIris, blankNodeLabels: blankNodeLabels);
      } else {
        // Multiple types
        result['@type'] = typeObjects
            .map((obj) => _getTypeValue(obj,
                compactedIris: compactedIris, blankNodeLabels: blankNodeLabels))
            .toList();
      }
    }

    // Add other predicates to the result
    for (final entry in predicateGroups.entries) {
      if (entry.value.length == 1) {
        // Single value for predicate
        result[entry.key] = _getObjectValue(entry.value[0], blankNodeLabels,
            compactedIris: compactedIris);
      } else {
        // Multiple values for predicate
        result[entry.key] = entry.value
            .map((obj) => _getObjectValue(obj, blankNodeLabels,
                compactedIris: compactedIris))
            .toList();
      }
    }

    return result;
  }

  Map<String, dynamic> createSubjectObject(
      RdfSubject subject,
      IriRole role,
      IriCompactionResult compactedIris,
      Map<BlankNodeTerm, String> blankNodeLabels) {
    final result = <String, dynamic>{};
    switch (subject) {
      case IriTerm iri:
        result['@id'] = _renderIri(iri, role, compactedIris);
      case BlankNodeTerm blankNode:

        // For blank nodes, we use the generated label
        result['@id'] = _renderBlankNode(blankNode, blankNodeLabels);
    }
    return result;
  }

  String _renderIri(
          IriTerm iri, IriRole role, IriCompactionResult compactedIris) =>
      switch (compactedIris.compactIri(iri, role)) {
        FullIri(iri: var fullIri) => fullIri,
        RelativeIri(relative: var relativeIri) => relativeIri,
        PrefixedIri prefixedIri => prefixedIri.colonSeparated,
        SpecialIri(iri: var specialIri) => () {
            _log.warning(
                'Unexpected special IRI type: ${specialIri.iri} for $role');
            return specialIri.iri;
          }(),
      };

  String _renderBlankNode(
      BlankNodeTerm blankNode, Map<BlankNodeTerm, String> blankNodeLabels) {
    final label = blankNodeLabels[blankNode];
    if (label == null) {
      // This should not happen if labels are generated correctly
      _log.warning(
        'No label generated for blank node subject, using fallback label',
      );
      return '_:b${identityHashCode(blankNode)}';
    }
    return '_:$label';
  }

  /// Returns the appropriate key name for a predicate.
  /// Uses prefixed notation when a matching prefix is available in the context.
  String _getPredicateKey(
          RdfPredicate predicate, IriCompactionResult compactedIris) =>
      switch (predicate) {
        IriTerm iri => _renderIri(iri, IriRole.predicate, compactedIris),
      };

  /// Converts an RDF object to its appropriate JSON-LD representation.
  /// If baseUri is provided, relativizes IRI objects against the base URI.
  dynamic _getObjectValue(
    RdfObject object,
    Map<BlankNodeTerm, String> blankNodeLabels, {
    required IriCompactionResult compactedIris,
  }) =>
      switch (object) {
        IriTerm iri => createSubjectObject(
            iri, IriRole.object, compactedIris, blankNodeLabels),
        BlankNodeTerm blankNode => createSubjectObject(
            blankNode, IriRole.object, compactedIris, blankNodeLabels),
        LiteralTerm literal => _getLiteralValue(literal),
      };

  /// Gets the IRI value for @type properties.
  ///
  /// Unlike _getObjectValue, this method returns the IRI directly as a string
  /// rather than wrapping it in an @id object, which is the correct format
  /// for @type values in JSON-LD.
  String _getTypeValue(RdfObject object,
          {required IriCompactionResult compactedIris,
          required Map<BlankNodeTerm, String> blankNodeLabels}) =>
      switch (object) {
        IriTerm iri => _renderIri(iri, IriRole.type, compactedIris),
        BlankNodeTerm blankNode => _renderBlankNode(blankNode, blankNodeLabels),
        LiteralTerm literal => throw ArgumentError(
            'Literal terms should not be used as @type values: $literal',
          ),
      };

  /// Converts an RDF literal to its appropriate JSON-LD representation.
  ///
  /// This method transforms RDF literals into the correct JSON-LD format based on their
  /// datatype and language tag. It implements JSON-LD's type coercion rules to produce
  /// native JSON values where possible, and uses the expanded @value/@type syntax when necessary.
  ///
  /// The conversion follows these rules:
  ///
  /// 1. **Language-tagged strings**: Represented as `{"@value": "value", "@language": "lang"}`
  ///
  /// 2. **Simple strings** (xsd:string): Represented as plain JSON strings
  ///
  /// 3. **Numbers**:
  ///    - xsd:integer → JSON number if parseable, otherwise expanded form
  ///    - xsd:decimal/xsd:double → JSON number if parseable, otherwise expanded form
  ///
  /// 4. **Booleans**: JSON true/false for "true"/"false" literals, expanded form otherwise
  ///
  /// 5. **Other datatypes**: Always use the expanded form `{"@value": "value", "@type": "datatype"}`
  ///
  /// This handling ensures the JSON-LD output is as natural as possible for JavaScript
  /// processing while preserving the RDF semantics.
  ///
  /// The [literal] parameter is the RDF literal to convert.
  /// Returns a JSON-compatible representation of the literal (string, number, boolean, or object).
  dynamic _getLiteralValue(LiteralTerm literal) {
    final value = literal.value;

    // Handle language-tagged strings
    if (literal.language != null) {
      return {'@value': value, '@language': literal.language};
    }

    // Handle different datatypes
    final datatype = literal.datatype;

    // String literals (default datatype)
    if (datatype == _stringDatatype) {
      return value;
    }

    // Number literals
    if (datatype == _integerDatatype) {
      return int.tryParse(value) ?? {'@value': value, '@type': datatype.iri};
    }

    if (datatype == _doubleDatatype || datatype == _decimalDatatype) {
      return double.tryParse(value) ?? {'@value': value, '@type': datatype.iri};
    }

    // Boolean literals
    if (datatype == _booleanDatatype) {
      if (value == 'true') return true;
      if (value == 'false') return false;
      return {'@value': value, '@type': datatype.iri};
    }

    // Other typed literals
    return {'@value': value, '@type': datatype.iri};
  }
}
