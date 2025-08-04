import 'package:logging/logging.dart';
import 'package:rdf_core/src/graph/rdf_graph.dart';
import 'package:rdf_core/src/graph/rdf_term.dart';
import 'package:rdf_core/src/graph/triple.dart';
import 'package:rdf_core/src/rdf_encoder.dart';
import 'package:rdf_core/src/iri_compaction.dart';
import 'package:rdf_core/src/vocab/namespaces.dart';
import 'package:rdf_core/src/vocab/rdf.dart';
import 'package:rdf_core/src/vocab/xsd.dart';

final _log = Logger("rdf.turtle");

/// Configuration options for Turtle serialization.
///
/// This class provides configuration settings that control how RDF graphs
/// are serialized to the Turtle format, including namespace prefix handling
/// and automatic prefix generation.
///
/// Example:
/// ```dart
/// final options = TurtleEncoderOptions(
///   customPrefixes: {'ex': 'http://example.org/'},
///   generateMissingPrefixes: true
/// );
/// final encoder = TurtleEncoder(options: options);
/// ```
class TurtleEncoderOptions extends RdfGraphEncoderOptions {
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
  /// written as full IRIs in angle brackets (e.g., `<http://example.org/term>`).
  ///
  /// This option is particularly useful for:
  /// - Reducing the verbosity of the Turtle output
  /// - Making the serialized data more human-readable
  /// - Automatically handling unknown namespaces without manual prefix declaration
  final bool generateMissingPrefixes;

  /// Controls whether local names that start with a digit are written using prefix notation.
  ///
  /// According to the Turtle specification, local names that begin with a digit
  /// cannot be written directly in the prefixed notation, as this would produce
  /// invalid Turtle syntax.
  ///
  /// When set to `true`, the encoder will use prefixed notation for IRIs with
  /// local names that start with digits. This requires each of these local names
  /// to be escaped properly and is not recommended by default.
  ///
  /// When set to `false` (default), the encoder will always write IRIs with local
  /// names that start with a digit as full IRIs in angle brackets, regardless of
  /// whether a matching prefix exists.
  ///
  /// For example, with this option set to `false`:
  /// - The IRI `http://example.org/123` will be written as `<http://example.org/123>`
  ///   even if the prefix `ex:` is defined for `http://example.org/`
  ///
  /// This behavior ensures compliant Turtle output and improves readability
  /// while avoiding potential syntax errors.
  final bool useNumericLocalNames;

  /// Whether to include base URI declarations in the output
  ///
  /// This option only applies when a baseUri is provided during encoding.
  /// When true and a baseUri is provided, the serializer includes the base URI
  /// declaration in the format-specific way (e.g., @base in Turtle, @base in JSON-LD context).
  /// When false, the baseUri is still used for URI relativization but not declared in the output.
  /// Has no effect if no baseUri is provided during encoding.
  final bool includeBaseDeclaration;

  /// Controls how fragment IRIs are rendered in the output.
  ///
  /// When set to `true` (default), fragment IRIs from the current document are rendered
  /// as prefixed IRIs using an empty prefix declaration. For example:
  /// - `http://example.org/document#fragment` becomes `:fragment`
  /// - Requires an empty prefix declaration: `@prefix : <http://example.org/document#> .`
  ///
  /// When set to `false`, fragment IRIs are rendered as relative IRIs when they belong
  /// to the current document's namespace. For example:
  /// - `http://example.org/document#fragment` becomes `#fragment`
  /// - No empty prefix declaration is generated
  ///
  /// This setting only affects IRIs that have fragments and belong to a namespace
  /// that ends with '#'. Non-fragment IRIs are processed according to other
  /// compaction rules.
  ///
  /// Example with `renderFragmentsAsPrefixed: true` (default):
  /// ```turtle
  /// @prefix : <http://example.org/doc#> .
  ///
  /// :subject :property :object .
  /// ```
  ///
  /// Example with `renderFragmentsAsPrefixed: false`:
  /// ```turtle
  /// @base <http://example.org/doc> .
  ///
  /// <#subject> <#property> <#object> .
  /// ```
  final bool renderFragmentsAsPrefixed;

  /// Creates a new TurtleEncoderOptions instance.
  ///
  /// Parameters:
  /// - [customPrefixes] Custom namespace prefixes to use during encoding.
  ///   A mapping of prefix strings to namespace URIs that will be used
  ///   to generate compact prefix declarations in the Turtle output.
  /// - [generateMissingPrefixes] When true (default), the encoder will automatically
  ///   generate prefix declarations for IRIs that don't have a matching prefix.
  /// - [useNumericLocalNames] When false (default), IRIs with local names that start
  ///   with a digit will be written as full IRIs instead of using prefixed notation.
  /// - [includeBaseDeclaration] Whether to include base URI declarations in the output.
  ///   Defaults to true if not provided.
  /// - [renderFragmentsAsPrefixed] Whether to render fragment IRIs as prefixed IRIs (true, default)
  ///   or as relative IRIs (false).
  const TurtleEncoderOptions({
    super.customPrefixes = const {},
    super.iriRelativization = const IriRelativizationOptions.full(),
    this.generateMissingPrefixes = true,
    this.useNumericLocalNames = false,
    bool includeBaseDeclaration = true,
    this.renderFragmentsAsPrefixed = true,
  }) : includeBaseDeclaration = includeBaseDeclaration;

  /// Creates a TurtleEncoderOptions instance from generic RdfGraphEncoderOptions.
  ///
  /// This factory method enables proper type conversion when using the
  /// generic codec/encoder API with Turtle-specific options.
  ///
  /// Parameters:
  /// - [options] The options object to convert, which may or may not be
  ///   already a TurtleEncoderOptions instance.
  ///
  /// Returns:
  /// - The input as-is if it's already a TurtleEncoderOptions instance,
  ///   or a new instance with the input's customPrefixes and includeBaseDeclaration
  ///   flag, using default Turtle-specific settings for other options.
  static TurtleEncoderOptions from(RdfGraphEncoderOptions options) =>
      switch (options) {
        TurtleEncoderOptions _ => options,
        _ => TurtleEncoderOptions(
            customPrefixes: options.customPrefixes,
            iriRelativization: options.iriRelativization,
          ),
      };

  ///
  /// This method allows creating a new TurtleEncoderOptions instance based on
  /// the current options, selectively overriding specific fields while keeping
  /// all other settings unchanged.
  ///
  /// Parameters:
  /// - [customPrefixes] Optional replacement for the custom namespace prefixes
  /// - [generateMissingPrefixes] Optional replacement for the automatic prefix generation setting
  /// - [useNumericLocalNames] Optional replacement for the numeric local names handling setting
  /// - [includeBaseDeclaration] Optional replacement for the base declaration inclusion setting
  /// - [renderFragmentsAsPrefixed] Optional replacement for the fragment rendering setting
  ///
  /// Returns:
  /// - A new TurtleEncoderOptions instance with the specified changes applied
  ///
  /// Example:
  /// ```dart
  /// final originalOptions = TurtleEncoderOptions(
  ///   generateMissingPrefixes: true,
  ///   useNumericLocalNames: false
  /// );
  ///
  /// final modifiedOptions = originalOptions.copyWith(
  ///   generateMissingPrefixes: false,
  ///   customPrefixes: {'ex': 'http://example.org/'}
  /// );
  /// ```
  @override
  TurtleEncoderOptions copyWith(
          {Map<String, String>? customPrefixes,
          bool? generateMissingPrefixes,
          bool? useNumericLocalNames,
          bool? includeBaseDeclaration,
          bool? renderFragmentsAsPrefixed,
          IriRelativizationOptions? iriRelativization}) =>
      TurtleEncoderOptions(
        customPrefixes: customPrefixes ?? this.customPrefixes,
        generateMissingPrefixes:
            generateMissingPrefixes ?? this.generateMissingPrefixes,
        useNumericLocalNames: useNumericLocalNames ?? this.useNumericLocalNames,
        includeBaseDeclaration:
            includeBaseDeclaration ?? this.includeBaseDeclaration,
        renderFragmentsAsPrefixed:
            renderFragmentsAsPrefixed ?? this.renderFragmentsAsPrefixed,
        iriRelativization: iriRelativization ?? this.iriRelativization,
      );
}

const _integerDatatype = Xsd.integer;
const _decimalDatatype = Xsd.decimal;
const _booleanDatatype = Xsd.boolean;
const _stringDatatype = Xsd.string;

/// Encoder for serializing RDF graphs to Turtle syntax.
///
/// The Turtle format (Terse RDF Triple Language) is a textual syntax for RDF that allows
/// writing down RDF graphs in a compact and natural text form. This encoder implements
/// the W3C Turtle recommendation, with additional optimizations for readability and compactness.
///
/// Features:
/// - Automatic namespace prefix generation
/// - Compact representation for blank nodes and collections
/// - Proper indentation and formatting for readability
/// - Support for base URI relative references
/// - Special handling for common datatypes (integers, decimals, booleans)
///
/// Example usage:
/// ```dart
/// import 'package:rdf_core/rdf_core.dart';
///
/// final graph = RdfGraph();
/// graph.add(Triple(
///   IriTerm('http://example.org/subject'),
///   IriTerm('http://example.org/predicate'),
///   LiteralTerm('object')
/// ));
///
/// final encoder = TurtleEncoder();
/// final turtle = encoder.convert(graph);
/// // Outputs: @prefix ex: <http://example.org/> .
/// //
/// // ex:subject ex:predicate "object" .
/// ```
///
/// See: [Turtle - Terse RDF Triple Language](https://www.w3.org/TR/turtle/)
///
/// NOTE: Always use canonical RDF vocabularies (e.g., http://xmlns.com/foaf/0.1/) with http://, not https://
/// This encoder will warn if it detects use of https:// for a namespace that is canonical as http://.
class TurtleEncoder extends RdfGraphEncoder {
  /// Standard namespace mappings used to resolve well-known prefixes.
  ///
  /// These mappings provide a collection of commonly used RDF namespaces
  /// (like rdf, rdfs, xsd, etc.) that can be used to create more compact
  /// and readable Turtle output. They also serve as a source for
  /// automatic prefix generation.
  final RdfNamespaceMappings _namespaceMappings;

  late final IriCompaction _iriCompaction;

  /// Configuration options that control the encoding behavior.
  ///
  /// These options determine how the encoder handles prefix generation,
  /// custom namespace mappings, and other serialization details.
  final TurtleEncoderOptions _options;

  /// Creates a new Turtle encoder with the specified options.
  ///
  /// Parameters:
  /// - [namespaceMappings] Optional custom namespace mappings to use for
  ///   resolving prefixes. If not provided, default RDF namespace mappings are used.
  /// - [options] Configuration options that control encoding behavior.
  ///   Default options include automatic prefix generation.
  ///
  /// Example:
  /// ```dart
  /// // Create an encoder with custom options
  /// final encoder = TurtleEncoder(
  ///   namespaceMappings: extendedNamespaces,
  ///   options: TurtleEncoderOptions(generateMissingPrefixes: false)
  /// );
  /// ```
  TurtleEncoder({
    RdfNamespaceMappings? namespaceMappings,
    TurtleEncoderOptions options = const TurtleEncoderOptions(),
  })  : _options = options,
        // Use default namespace mappings if none provided
        _namespaceMappings = namespaceMappings ?? RdfNamespaceMappings() {
    _iriCompaction = IriCompaction(
      _namespaceMappings,
      IriCompactionSettings(
          generateMissingPrefixes: options.generateMissingPrefixes,
          renderFragmentsAsPrefixed: options.renderFragmentsAsPrefixed,
          iriRelativization: options.iriRelativization,
          allowedCompactionTypes: {
            ...allowedCompactionTypesAll,
            IriRole.predicate: {
              IriCompactionType.full,
              IriCompactionType.prefixed,
              // Allow relative IRIs for predicates when fragments should be rendered as relative
              if (!options.renderFragmentsAsPrefixed) IriCompactionType.relative
            },
            IriRole.type: {IriCompactionType.full, IriCompactionType.prefixed}
          },
          specialPredicates: {
            Rdf.type,
          },
          specialDatatypes: {
            _booleanDatatype,
            _decimalDatatype,
            //_doubleDatatype,
            _integerDatatype,
            _stringDatatype,
            Rdf.langString,
          }),
      (String localPart) => RdfNamespaceMappings.isValidLocalPart(localPart,
          allowNumericLocalNames: options.useNumericLocalNames),
    );
  }

  @override

  /// Creates a new encoder with the specified options, preserving the current namespace mappings.
  ///
  /// This method allows changing encoding options without creating a completely new
  /// encoder instance. It returns a new encoder that shares the same namespace mappings
  /// but uses the provided options.
  ///
  /// Parameters:
  /// - [options] New encoder options to use. If this is already a TurtleEncoderOptions
  ///   instance, it will be used directly. Otherwise, it will be converted to
  ///   TurtleEncoderOptions using the from() factory method.
  ///
  /// Returns:
  /// - A new TurtleEncoder instance with the updated options
  ///
  /// Example:
  /// ```dart
  /// // Create a new encoder with modified options
  /// final newEncoder = encoder.withOptions(
  ///   TurtleEncoderOptions(generateMissingPrefixes: false)
  /// );
  /// ```
  RdfGraphEncoder withOptions(RdfGraphEncoderOptions options) => TurtleEncoder(
        namespaceMappings: _namespaceMappings,
        options: TurtleEncoderOptions.from(options),
      );
  RdfGraphEncoderOptions get options => _options;

  @override

  /// Converts an RDF graph to a Turtle string representation.
  ///
  /// This method serializes the given RDF graph to the Turtle format with
  /// advanced formatting features including:
  /// - Automatically detecting and writing prefix declarations
  /// - Grouping triples by subject for more compact output
  /// - Proper indentation and formatting for readability
  /// - Optimizing blank nodes that appear only once as objects by inlining them
  /// - Serializing RDF collections (lists) in the compact Turtle '(item1 item2)' notation
  ///
  /// Parameters:
  /// - [graph] The RDF graph to serialize to Turtle
  /// - [baseUri] Optional base URI to use for resolving relative IRIs and
  ///   generating shorter references. When provided and includeBaseDeclaration
  ///   is true, a @base directive will be included in the output. When
  ///   includeBaseDeclaration is false, the baseUri is still used for URI
  ///   relativization but not declared in the output.
  ///
  /// Returns:
  /// - A properly formatted Turtle string representation of the input graph.
  ///
  /// Example:
  /// ```dart
  /// final graph = RdfGraph();
  /// // Add some triples to the graph
  /// final turtle = encoder.convert(graph, baseUri: 'http://example.org/');
  /// ```
  String convert(RdfGraph graph, {String? baseUri}) {
    _log.info('Serializing graph to Turtle');

    final buffer = StringBuffer();

    // Write base directive if provided and includeBaseDeclaration is true
    if (baseUri != null && _options.includeBaseDeclaration) {
      buffer.writeln('@base <$baseUri> .');
    }

    // Map to store generated blank node labels for this serialization
    final Map<BlankNodeTerm, String> blankNodeLabels = {};
    _generateBlankNodeLabels(graph, blankNodeLabels);

    // Count blank node occurrences to determine which can be inlined
    final Map<BlankNodeTerm, int> blankNodeOccurrences =
        _countBlankNodeOccurrences(graph);

    // 1. Write prefixes
    // Identify which prefixes are actually used in the graph
    final compactedIris = _iriCompaction
        .compactAllIris(graph, _options.customPrefixes, baseUri: baseUri);

    _writePrefixes(buffer, compactedIris.prefixes);

    // 2. Write triples grouped by subject
    _writeTriples(
      buffer,
      graph,
      compactedIris,
      blankNodeLabels,
      blankNodeOccurrences,
    );

    return buffer.toString();
  }

  /// Counts how many times each blank node is referenced in the graph.
  ///
  /// This method analyzes the graph to count how many times each blank node appears,
  /// which is crucial for determining which blank nodes can be inlined in the Turtle
  /// output for improved readability. Blank nodes referenced exactly once as objects
  /// can typically be inlined using Turtle's square bracket notation [ ... ].
  ///
  /// Parameters:
  /// - [graph] The RDF graph to analyze
  ///
  /// Returns:
  /// - A map where keys are blank node terms and values are the number of times
  ///   each blank node appears in the graph (as either subject or object)
  Map<BlankNodeTerm, int> _countBlankNodeOccurrences(RdfGraph graph) {
    final occurrences = <BlankNodeTerm, int>{};

    for (final triple in graph.triples) {
      // Count as a subject
      if (triple.subject is BlankNodeTerm) {
        final subject = triple.subject as BlankNodeTerm;
        occurrences[subject] = (occurrences[subject] ?? 0) + 1;
      }

      // Count as an object
      if (triple.object is BlankNodeTerm) {
        final object = triple.object as BlankNodeTerm;
        occurrences[object] = (occurrences[object] ?? 0) + 1;
      }
    }

    return occurrences;
  }

  /// Generates unique and consistent labels for all blank nodes in the graph.
  ///
  /// In Turtle format, blank nodes are typically represented with labels like "_:b0", "_:b1", etc.
  /// This method ensures that each distinct blank node in the graph receives a unique label,
  /// and that the same blank node always receives the same label throughout the serialization.
  ///
  /// The labels are generated sequentially (b0, b1, b2, ...) to maintain consistent
  /// and predictable output. These labels are used only for serialization and do not
  /// affect the actual identity of the blank nodes in the RDF graph.
  ///
  /// Parameters:
  /// - [graph] The RDF graph containing blank nodes to label
  /// - [blankNodeLabels] A map that will be populated with blank node to label mappings
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

  /// Writes prefix declarations to the output buffer.
  void _writePrefixes(StringBuffer buffer, Map<String, String> prefixes) {
    if (prefixes.isEmpty) {
      return;
    }

    // Write prefixes in alphabetical order for consistent output,
    // but handle empty prefix separately (should appear as ':')
    final sortedPrefixes = prefixes.entries.toList()
      ..sort((a, b) {
        // Empty prefix should come first in Turtle convention
        if (a.key.isEmpty) return -1;
        if (b.key.isEmpty) return 1;
        return a.key.compareTo(b.key);
      });

    for (final entry in sortedPrefixes) {
      final prefix = entry.key.isEmpty ? ':' : '${entry.key}:';
      buffer.writeln('@prefix $prefix <${entry.value}> .');
    }

    // Add blank line after prefixes
    buffer.writeln();
  }

  /// Checks if a blank node is the first node in an RDF collection.
  /// A collection is identified by the pattern of rdf:first and rdf:rest predicates.
  ///
  /// Returns a list of collection items if the node is a collection head,
  /// or null if it's not part of a collection.
  List<RdfObject>? _extractCollection(RdfGraph graph, BlankNodeTerm node) {
    // Get all triples where this node is the subject
    final outgoingTriples =
        graph.triples.where((t) => t.subject == node).toList();

    // Check if we have both rdf:first and rdf:rest predicates
    final firstTriples =
        outgoingTriples.where((t) => t.predicate == Rdf.first).toList();
    final restTriples =
        outgoingTriples.where((t) => t.predicate == Rdf.rest).toList();

    // If this is not a collection node, return null
    if (firstTriples.isEmpty || restTriples.isEmpty) {
      return null;
    }

    // Start building the collection
    final items = <RdfObject>[];
    var currentNode = node;

    // Traverse the linked list
    while (true) {
      // Find the rdf:first triple for the current node
      final firstTriple = graph.triples.firstWhere(
        (t) => t.subject == currentNode && t.predicate == Rdf.first,
        orElse: () => throw Exception(
          'Invalid RDF collection: missing rdf:first for $currentNode',
        ),
      );

      // Add the object to our items list
      items.add(firstTriple.object);

      // Find the rdf:rest triple for the current node
      final restTriple = graph.triples.firstWhere(
        (t) => t.subject == currentNode && t.predicate == Rdf.rest,
        orElse: () => throw Exception(
          'Invalid RDF collection: missing rdf:rest for $currentNode',
        ),
      );

      // If we've reached rdf:nil, we're done
      if (restTriple.object == Rdf.nil) {
        break;
      }

      // Otherwise, continue with the next node
      if (restTriple.object is! BlankNodeTerm) {
        throw Exception(
          'Invalid RDF collection: rdf:rest should point to a blank node or rdf:nil',
        );
      }

      currentNode = restTriple.object as BlankNodeTerm;
    }

    return items;
  }

  /// Marks all nodes in an RDF collection as processed to avoid duplicate serialization
  void _markCollectionNodesAsProcessed(
    RdfGraph graph,
    BlankNodeTerm collectionHead,
    Set<BlankNodeTerm> processedCollectionNodes,
  ) {
    var currentNode = collectionHead;
    processedCollectionNodes.add(currentNode);

    while (true) {
      // Find the rdf:rest triple
      final restTriples = graph.triples
          .where((t) => t.subject == currentNode && t.predicate == Rdf.rest)
          .toList();

      if (restTriples.isEmpty) {
        break;
      }

      final restTriple = restTriples.first;

      if (restTriple.object == Rdf.nil) {
        break;
      }

      if (restTriple.object is! BlankNodeTerm) {
        break;
      }

      currentNode = restTriple.object as BlankNodeTerm;
      processedCollectionNodes.add(currentNode);
    }
  }

  /// Writes an RDF collection to the buffer
  void _writeCollection(
    StringBuffer buffer,
    List<RdfObject> items,
    RdfGraph graph,
    Set<BlankNodeTerm> processedCollectionNodes,
    IriRole iriRole,
    IriCompactionResult compactedIris,
    Map<BlankNodeTerm, String> blankNodeLabels,
    Set<BlankNodeTerm> nodesToInline,
    Map<RdfSubject, List<Triple>> triplesBySubject,
  ) {
    buffer.write('(');

    for (var i = 0; i < items.length; i++) {
      if (i > 0) {
        buffer.write(' ');
      }

      final item = items[i];

      // Wenn das Item ein Blank Node ist
      if (item is BlankNodeTerm) {
        // Prüfen, ob es eine verschachtelte Collection ist
        final nestedItems = _extractCollection(graph, item);
        if (nestedItems != null) {
          // Es ist eine verschachtelte Collection
          _markCollectionNodesAsProcessed(
            graph,
            item,
            processedCollectionNodes,
          );
          _writeCollection(
            buffer,
            nestedItems,
            graph,
            processedCollectionNodes,
            iriRole,
            compactedIris,
            blankNodeLabels,
            nodesToInline,
            triplesBySubject,
          );
        } else if (triplesBySubject.containsKey(item) &&
            graph.triples.where((t) => t.object == item).length == 1 &&
            !_isPartOfRdfCollection(graph, item)) {
          // Es ist ein Blank Node, der inline dargestellt werden kann
          _writeInlineBlankNode(
            buffer,
            item,
            triplesBySubject[item]!,
            graph,
            processedCollectionNodes,
            compactedIris,
            blankNodeLabels,
            nodesToInline,
            triplesBySubject,
          );
        } else {
          // Normaler Blank Node
          buffer.write(
            writeTerm(
              item,
              iriRole: iriRole,
              compactedIris: compactedIris,
              blankNodeLabels: blankNodeLabels,
            ),
          );
        }
      } else {
        // Regulärer Term
        buffer.write(
          writeTerm(
            item,
            iriRole: iriRole,
            compactedIris: compactedIris,
            blankNodeLabels: blankNodeLabels,
          ),
        );
      }
    }

    buffer.write(')');
  }

  /// Writes all triples to the output buffer, grouped by subject.
  void _writeTriples(
    StringBuffer buffer,
    RdfGraph graph,
    IriCompactionResult compactedIris,
    Map<BlankNodeTerm, String> blankNodeLabels,
    Map<BlankNodeTerm, int> blankNodeOccurrences,
  ) {
    if (graph.triples.isEmpty) {
      return;
    }

    // Group triples by subject for more compact representation
    final Map<RdfSubject, List<Triple>> triplesBySubject = {};

    // Track blank nodes referenced as objects, to determine which can be inlined
    final Set<BlankNodeTerm> referencedAsObject = {};

    // Track which blank nodes are part of collections to avoid duplicating them
    final Set<BlankNodeTerm> processedCollectionNodes = {};

    // Set of blank nodes that will be inlined and should be skipped when processed as subjects
    final Set<BlankNodeTerm> nodesToInline = {};

    // First pass: group triples by subject and identify collections
    for (final triple in graph.triples) {
      // Skip triples that are part of a collection structure
      if ((triple.predicate == Rdf.first || triple.predicate == Rdf.rest) &&
          triple.subject is BlankNodeTerm &&
          processedCollectionNodes.contains(triple.subject)) {
        continue;
      }

      // Track blank nodes that appear as objects
      if (triple.object is BlankNodeTerm) {
        referencedAsObject.add(triple.object as BlankNodeTerm);
      }

      triplesBySubject.putIfAbsent(triple.subject, () => []).add(triple);
    }

    // Identify blank nodes that can be inlined (referenced only once as object)
    for (final node in referencedAsObject) {
      // Ein Blank Node sollte inline dargestellt werden, wenn:
      // 1. Es genau einmal als Objekt referenziert wird
      // 2. Es auch mindestens eine Triple als Subjekt hat
      // 3. Es nicht Teil einer RDF-Collection ist
      final objectRefCount =
          graph.triples.where((t) => t.object == node).length;
      if (objectRefCount == 1 &&
          triplesBySubject.containsKey(node) &&
          !_isPartOfRdfCollection(graph, node)) {
        nodesToInline.add(node);
      }
    }

    final sortedSubjects = triplesBySubject.keys.toList()
      ..sort((a, b) {
        // Sort by IRI for consistent output
        if (a is IriTerm && b is IriTerm) {
          return a.iri.compareTo(b.iri);
        }
        if (a is IriTerm) {
          return -1; // IRIs should come before blank nodes
        }
        if (b is IriTerm) {
          return 1; // IRIs should come before blank nodes
        }
        // Blank nodes are sorted by their hash code
        return identityHashCode(a).compareTo(identityHashCode(b));
      });
    // Write each subject group
    var processedSubjectCount = 0;
    for (final subject in sortedSubjects) {
      final triples = triplesBySubject[subject]!;

      // Check if this subject is a collection
      bool skipSubject = false;
      if (subject is BlankNodeTerm) {
        // Skip subjects that will be inlined
        if (nodesToInline.contains(subject)) {
          continue;
        }

        final collectionItems = _extractCollection(graph, subject);
        if (collectionItems != null) {
          // Mark all nodes in this collection as processed
          _markCollectionNodesAsProcessed(
            graph,
            subject,
            processedCollectionNodes,
          );

          // Skip this subject as we'll handle the collection where it's referenced
          skipSubject = true;
        }
      }

      if (skipSubject) {
        continue;
      }

      // Add blank line before each subject (except the first)
      if (processedSubjectCount > 0) {
        buffer.writeln();
        buffer.writeln(); // Zusätzliche Leerzeile zwischen Subjektgruppen
      }
      processedSubjectCount++;

      _writeSubjectGroup(
        buffer,
        subject,
        triples,
        graph,
        processedCollectionNodes,
        compactedIris,
        blankNodeLabels,
        nodesToInline,
        triplesBySubject,
      );
    }
  }

  /// Checks if a blank node is part of an RDF collection structure.
  bool _isPartOfRdfCollection(RdfGraph graph, BlankNodeTerm node) {
    // Check if this node is referenced by an rdf:rest predicate
    final isReferencedByRest = graph.triples.any(
      (t) => t.predicate == Rdf.rest && t.object == node,
    );

    // Check if this node has rdf:first or rdf:rest predicates
    final hasCollectionPredicates = graph.triples.any(
      (t) =>
          t.subject == node &&
          (t.predicate == Rdf.first || t.predicate == Rdf.rest),
    );

    return isReferencedByRest || hasCollectionPredicates;
  }

  /// Writes a group of triples that share the same subject.
  void _writeSubjectGroup(
    StringBuffer buffer,
    RdfSubject subject,
    List<Triple> triples,
    RdfGraph graph,
    Set<BlankNodeTerm> processedCollectionNodes,
    IriCompactionResult compactedIris,
    Map<BlankNodeTerm, String> blankNodeLabels,
    Set<BlankNodeTerm> nodesToInline,
    Map<RdfSubject, List<Triple>> triplesBySubject,
  ) {
    // Write subject
    final subjectStr = writeTerm(
      subject,
      iriRole: IriRole.subject,
      compactedIris: compactedIris,
      blankNodeLabels: blankNodeLabels,
    );
    buffer.write(subjectStr);

    // Group triples by predicate for more compact representation
    final Map<RdfPredicate, List<RdfObject>> triplesByPredicate = {};

    for (final triple in triples) {
      triplesByPredicate
          .putIfAbsent(triple.predicate, () => [])
          .add(triple.object);
    }
    final sortedPredicates = triplesByPredicate.keys.toList()
      ..sort((a, b) {
        // Rdf.type should always be first
        if (a == Rdf.type) return -1;
        if (b == Rdf.type) return 1;

        // For all other predicates, sort alphabetically by IRI
        return (a as IriTerm).iri.compareTo((b as IriTerm).iri);
      });
    // Write predicates and objects
    var predicateIndex = 0;
    for (final predicate in sortedPredicates) {
      final isType = predicate == Rdf.type;
      // Get objects and ensure uniqueness while preserving order
      final objects = <RdfObject>[];
      final seenObjects = <RdfObject>{};

      for (final obj in triplesByPredicate[predicate]!) {
        if (!seenObjects.contains(obj)) {
          objects.add(obj);
          seenObjects.add(obj);
        }
      }

      // First predicate on same line as subject, others indented on new lines
      if (predicateIndex == 0) {
        buffer.write(' ');
      } else {
        buffer.write(';\n    ');
      }
      predicateIndex++;

      // Write predicate
      buffer.write(
        writeTerm(
          predicate,
          iriRole: IriRole.predicate,
          compactedIris: compactedIris,
          blankNodeLabels: blankNodeLabels,
        ),
      );
      buffer.write(' ');

      // Write objects
      var objectIndex = 0;
      for (final object in objects) {
        if (objectIndex > 0) {
          buffer.write(', ');
        }
        objectIndex++;

        // Check if this is rdf:nil which should be serialized as ()
        if (object == Rdf.nil) {
          buffer.write('()');
          continue;
        }

        // Check if this object is a blank node that should be inlined
        if (object is BlankNodeTerm && nodesToInline.contains(object)) {
          // Write this blank node inline
          _writeInlineBlankNode(
            buffer,
            object,
            triplesBySubject[object]!,
            graph,
            processedCollectionNodes,
            compactedIris,
            blankNodeLabels,
            nodesToInline,
            triplesBySubject,
          );
          continue;
        }

        // Check if this object is a collection
        if (object is BlankNodeTerm) {
          final collectionItems = _extractCollection(graph, object);
          if (collectionItems != null) {
            // Mark this node and all related nodes as processed
            _markCollectionNodesAsProcessed(
              graph,
              object,
              processedCollectionNodes,
            );

            // Write the collection in compact form
            _writeCollection(
              buffer,
              collectionItems,
              graph,
              processedCollectionNodes,
              IriRole.object,
              compactedIris,
              blankNodeLabels,
              nodesToInline,
              triplesBySubject,
            );
          } else {
            // Regular blank node
            buffer.write(
              writeTerm(
                object,
                iriRole: isType ? IriRole.type : IriRole.object,
                compactedIris: compactedIris,
                blankNodeLabels: blankNodeLabels,
              ),
            );
          }
        } else {
          // Regular term
          buffer.write(
            writeTerm(
              object,
              iriRole: isType ? IriRole.type : IriRole.object,
              compactedIris: compactedIris,
              blankNodeLabels: blankNodeLabels,
            ),
          );
        }
      }
    }

    // End the subject group
    buffer.write(' .');
  }

  /// Writes a blank node inline in Turtle's square bracket notation
  void _writeInlineBlankNode(
    StringBuffer buffer,
    BlankNodeTerm node,
    List<Triple> triples,
    RdfGraph graph,
    Set<BlankNodeTerm> processedCollectionNodes,
    IriCompactionResult compactedIris,
    Map<BlankNodeTerm, String> blankNodeLabels,
    Set<BlankNodeTerm> nodesToInline,
    Map<RdfSubject, List<Triple>> triplesBySubject,
  ) {
    buffer.write('[ ');

    // Group triples by predicate
    final Map<RdfPredicate, List<RdfObject>> triplesByPredicate = {};
    for (final triple in triples) {
      triplesByPredicate
          .putIfAbsent(triple.predicate, () => [])
          .add(triple.object);
    }

    // Write predicates and objects for this inline blank node
    var predicateIndex = 0;
    for (final entry in triplesByPredicate.entries) {
      final predicate = entry.key;
      final objects = entry.value;
      final isType = predicate == Rdf.type;
      final objectIriRole = isType ? IriRole.type : IriRole.object;
      // Add separator between predicate-object groups
      if (predicateIndex > 0) {
        buffer.write(' ; ');
      }
      predicateIndex++;

      // Write predicate
      buffer.write(
        writeTerm(
          predicate,
          iriRole: IriRole.predicate,
          compactedIris: compactedIris,
          blankNodeLabels: blankNodeLabels,
        ),
      );
      buffer.write(' ');

      // Write objects
      var objectIndex = 0;
      for (final object in objects) {
        if (objectIndex > 0) {
          buffer.write(', ');
        }
        objectIndex++;

        // Handle different object types
        if (object is BlankNodeTerm && nodesToInline.contains(object)) {
          // Write nested inline blank node
          _writeInlineBlankNode(
            buffer,
            object,
            triplesBySubject[object]!,
            graph,
            processedCollectionNodes,
            compactedIris,
            blankNodeLabels,
            nodesToInline,
            triplesBySubject,
          );
        } else if (object is BlankNodeTerm &&
            _extractCollection(graph, object) != null) {
          // Object is a collection
          final collectionItems = _extractCollection(graph, object)!;

          // Mark all nodes in the collection as processed
          _markCollectionNodesAsProcessed(
            graph,
            object,
            processedCollectionNodes,
          );

          // Write collection
          _writeCollection(
            buffer,
            collectionItems,
            graph,
            processedCollectionNodes,
            objectIriRole,
            compactedIris,
            blankNodeLabels,
            nodesToInline,
            triplesBySubject,
          );
        } else {
          // Regular term
          buffer.write(
            writeTerm(
              object,
              iriRole: objectIriRole,
              compactedIris: compactedIris,
              blankNodeLabels: blankNodeLabels,
            ),
          );
        }
      }
    }

    buffer.write(' ]');
  }

  /// Convert RDF terms to Turtle syntax string representation
  String writeTerm(RdfTerm term,
      {required IriRole iriRole,
      required IriCompactionResult compactedIris,
      required Map<BlankNodeTerm, String> blankNodeLabels}) {
    switch (term) {
      case IriTerm _:
        // Check if the predicate is a known prefix
        final compacted = compactedIris.compactIri(term, iriRole);
        switch (compacted) {
          case PrefixedIri prefixed:
            return prefixed.colonSeparated;
          case FullIri(iri: var iri):
            // If we have a full IRI without a prefix
            return '<$iri>';
          case RelativeIri(relative: var relativeIri):
            return '<$relativeIri>';
          case SpecialIri(iri: var iri):
            if (term == Rdf.type) {
              return 'a';
            }
            throw ArgumentError(
              'Unexpected special IRI: $iri. It should have been treated before',
            );
        }
      case BlankNodeTerm blankNode:
        // Use the pre-generated label for this blank node
        var label = blankNodeLabels[blankNode];
        if (label == null) {
          // This shouldn't happen if all blank nodes were collected correctly
          _log.warning(
            'No label generated for blank node, using fallback label',
          );
          label = 'b${identityHashCode(blankNode)}';
          blankNodeLabels[blankNode] = label;
        }
        return '_:$label';
      case LiteralTerm literal:
        // Special cases for native Turtle literal representations
        if (literal.datatype == _integerDatatype) {
          return literal.value;
        }
        if (literal.datatype == _decimalDatatype) {
          return literal.value;
        }
        if (literal.datatype == _booleanDatatype) {
          return literal.value;
        }

        var escapedLiteralValue = _escapeTurtleString(literal.value);

        if (literal.language != null) {
          return '"$escapedLiteralValue"@${literal.language}';
        }
        if (literal.datatype != _stringDatatype) {
          return '"$escapedLiteralValue"^^${writeTerm(literal.datatype, iriRole: IriRole.datatype, compactedIris: compactedIris, blankNodeLabels: blankNodeLabels)}';
        }
        return '"$escapedLiteralValue"';
    }
  }

  /// Escapes a string according to Turtle syntax rules
  ///
  /// Handles standard escape sequences (\n, \r, \t, etc.) and
  /// escapes Unicode characters outside the ASCII range as \uXXXX or \UXXXXXXXX
  String _escapeTurtleString(String value) {
    final StringBuffer buffer = StringBuffer();

    for (int i = 0; i < value.length; i++) {
      final int codeUnit = value.codeUnitAt(i);

      // Handle common escape sequences
      switch (codeUnit) {
        case 0x08: // backspace
          buffer.write('\\b');
          break;
        case 0x09: // tab
          buffer.write('\\t');
          break;
        case 0x0A: // line feed
          buffer.write('\\n');
          break;
        case 0x0C: // form feed
          buffer.write('\\f');
          break;
        case 0x0D: // carriage return
          buffer.write('\\r');
          break;
        case 0x22: // double quote
          buffer.write('\\"');
          break;
        case 0x5C: // backslash
          buffer.write('\\\\');
          break;
        default:
          if (codeUnit < 0x20 || codeUnit >= 0x7F) {
            // Escape non-printable ASCII and non-ASCII Unicode characters
            if (codeUnit <= 0xFFFF) {
              buffer.write(
                '\\u${codeUnit.toRadixString(16).padLeft(4, '0').toUpperCase()}',
              );
            } else {
              buffer.write(
                '\\U${codeUnit.toRadixString(16).padLeft(8, '0').toUpperCase()}',
              );
            }
          } else {
            // Regular printable ASCII character
            buffer.writeCharCode(codeUnit);
          }
      }
    }

    return buffer.toString();
  }
}
