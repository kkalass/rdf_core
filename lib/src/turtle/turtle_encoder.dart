import 'package:logging/logging.dart';
import 'package:rdf_core/src/graph/rdf_graph.dart';
import 'package:rdf_core/src/graph/rdf_term.dart';
import 'package:rdf_core/src/graph/triple.dart';
import 'package:rdf_core/src/rdf_encoder.dart';
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
  const TurtleEncoderOptions({
    Map<String, String> customPrefixes = const {},
    this.generateMissingPrefixes = true,
    this.useNumericLocalNames = false,
  }) : super(customPrefixes: customPrefixes);

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
  ///   or a new instance with the input's customPrefixes and default
  ///   Turtle-specific settings.
  static TurtleEncoderOptions from(RdfGraphEncoderOptions options) =>
      switch (options) {
        TurtleEncoderOptions _ => options,
        _ => TurtleEncoderOptions(customPrefixes: options.customPrefixes),
      };
}

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
        _namespaceMappings = namespaceMappings ?? RdfNamespaceMappings();

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
  ///   generating shorter references. If provided, a @base directive will be
  ///   included in the output.
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

    // Write base directive if provided
    if (baseUri != null) {
      buffer.writeln('@base <$baseUri> .');
    }

    // Map to store generated blank node labels for this serialization
    final Map<BlankNodeTerm, String> blankNodeLabels = {};
    _generateBlankNodeLabels(graph, blankNodeLabels);

    // Count blank node occurrences to determine which can be inlined
    final Map<BlankNodeTerm, int> blankNodeOccurrences =
        _countBlankNodeOccurrences(graph);

    // 1. Write prefixes
    final prefixCandidates = {
      ..._namespaceMappings.asMap(),
      ..._options.customPrefixes,
    };
    // Identify which prefixes are actually used in the graph
    final prefixes = _extractUsedAndGenerateMissingPrefixes(
      graph,
      prefixCandidates,
      baseUri,
    );

    _writePrefixes(buffer, prefixes);

    final prefixesByIri = prefixes.map((prefix, iri) {
      return MapEntry(iri, prefix);
    });

    // 2. Write triples grouped by subject
    _writeTriples(
      buffer,
      graph,
      prefixesByIri,
      blankNodeLabels,
      blankNodeOccurrences,
      baseUri,
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

  /// Analyzes an RDF graph to extract and generate necessary namespace prefixes.
  ///
  /// This method performs two main functions:
  /// 1. Identifies which prefixes from the available candidates are actually used
  ///    in the graph, to avoid including unused prefixes in the output
  /// 2. Generates new prefixes for namespaces that appear in the graph but don't
  ///    have predefined prefixes, if [generateMissingPrefixes] is enabled
  ///
  /// The method examines all IRIs in subjects, predicates, objects, and datatype IRIs
  /// to determine which namespaces are used. It also handles special cases like
  /// rdf:type (which is serialized as 'a') and IRIs that will be serialized as
  /// relative references.
  ///
  /// Parameters:
  /// - [graph] The RDF graph to analyze for namespace usage
  /// - [prefixCandidates] Map of available prefixes (prefix → namespace IRI)
  /// - [baseUri] Optional base URI for determining relative references
  ///
  /// Returns:
  /// - A map of prefixes to namespace IRIs that should be included in the serialized output
  Map<String, String> _extractUsedAndGenerateMissingPrefixes(
    RdfGraph graph,
    Map<String, String> prefixCandidates,
    String? baseUri,
  ) {
    final usedPrefixes = <String, String>{};

    // Create an inverted index for quick lookup
    final iriToPrefixMap = Map<String, String>.fromEntries(
      prefixCandidates.entries.map((e) => MapEntry(e.value, e.key)),
    );

    for (final triple in graph.triples) {
      // Check subject
      if (triple.subject is IriTerm) {
        _checkTermForPrefix(
          triple.subject as IriTerm,
          iriToPrefixMap,
          usedPrefixes,
          prefixCandidates,
          baseUri,
        );
      }

      // Check predicate
      if (triple.predicate is IriTerm) {
        _checkTermForPrefix(
          triple.predicate as IriTerm,
          iriToPrefixMap,
          usedPrefixes,
          prefixCandidates,
          baseUri,
          isPredicate: true,
        );
      }

      // Check object
      if (triple.object is IriTerm) {
        _checkTermForPrefix(
          triple.object as IriTerm,
          iriToPrefixMap,
          usedPrefixes,
          prefixCandidates,
          baseUri,
        );
      } else if (triple.object is LiteralTerm) {
        final literal = triple.object as LiteralTerm;
        if (literal.datatype == Xsd.string ||
            literal.datatype == Rdf.langString) {
          // string and langString will not actually be written, they are implicit.
          continue;
        }
        _checkTermForPrefix(
          literal.datatype,
          iriToPrefixMap,
          usedPrefixes,
          prefixCandidates,
          baseUri,
        );
      }
    }

    return usedPrefixes;
  }

  /// Processes an IRI term to determine if it needs a prefix in the serialization.
  ///
  /// This method examines an IRI term and decides how it should be serialized in Turtle:
  /// - As a relative IRI if it falls under the base URI
  /// - Using an existing prefix if one matches the namespace
  /// - Using a newly generated prefix if no existing prefix matches (and generation is enabled)
  /// - As a full IRI in angle brackets if none of the above apply
  ///
  /// The method also performs important optimizations:
  /// - Skips processing for rdf:type, which has special 'a' syntax in Turtle
  /// - Uses the longest matching prefix when multiple prefixes could apply
  /// - Warns about canonical namespace mismatches (http:// vs https://)
  /// - Skips generating prefixes for IRIs without proper namespace delimiters
  ///
  /// Parameters:
  /// - [term] The IRI term to process
  /// - [iriToPrefixMap] Inverse mapping of namespace IRIs to prefixes for quick lookup
  /// - [usedPrefixes] Map of prefixes that will be included in the output, which this method may modify
  /// - [prefixCandidates] All available prefix mappings, including those not yet marked as used
  /// - [baseUri] Optional base URI for determining relative references
  void _checkTermForPrefix(
    IriTerm term,
    Map<String, String> iriToPrefixMap,
    Map<String, String> usedPrefixes,
    Map<String, String> prefixCandidates,
    String? baseUri, {
    bool isPredicate = false,
  }) {
    if (term == Rdf.type) {
      // This IRI has special handling in Turtle besides the prefix stuff:
      // it will be rendered simply as "a" - no prefix needed
      return;
    }

    final iri = term.iri;

    // Never skip prefix generation for predicates - always use prefixes if available
    // For subjects and objects, allow relative IRIs under base URI, but only
    // if there's no better matching prefix (handled later)
    if (!isPredicate && baseUri != null && iri.startsWith(baseUri)) {
      // For subjects and objects under baseUri, we need to be careful:
      // 1. Check if there's a matching prefix that's longer than baseUri
      // 2. If yes, use that prefix
      // 3. If no, don't generate a new prefix - we'll use relative IRIs

      // Find the longest matching prefix (if any)
      var longerPrefixExists = false;
      for (final entry in prefixCandidates.entries) {
        final namespace = entry.value;
        if (iri.startsWith(namespace) && namespace.length > baseUri.length) {
          longerPrefixExists = true;
          break;
        }
      }

      // If no longer prefix exists, skip all prefix generation for this term
      // It will be serialized as a relative IRI instead
      if (!longerPrefixExists) {
        return;
      }
    }

    // Extract namespace and local part with validation for numeric local names
    final (
      namespace,
      localPart,
    ) = RdfNamespaceMappings.extractNamespaceAndLocalPart(
      iri,
      allowNumericLocalNames: _options.useNumericLocalNames,
    );

    // If the local part is empty after validation, skip this IRI for prefix usage
    // (This happens with IRIs having numeric local names when useNumericLocalNames=false)
    if (localPart.isEmpty && namespace == iri) {
      return;
    }

    // Warn if https:// is used and http:// is in the prefix map for the same path
    if (iri.startsWith('https://')) {
      final httpIri = 'http://' + iri.substring('https://'.length);
      if (prefixCandidates.containsValue(httpIri)) {
        _log.warning(
          'Namespace mismatch: Found IRI $iri, but canonical prefix uses $httpIri. Consider using the canonical http:// form.',
        );
      }
    }

    // First try direct match (for namespaces that are used completely)
    if (iriToPrefixMap.containsKey(iri)) {
      final prefix = iriToPrefixMap[iri]!;
      usedPrefixes[prefix] = iri;
      return;
    }

    // For prefix match, use the longest matching prefix (most specific)
    // This handles overlapping prefixes correctly (e.g., http://example.org/ and http://example.org/vocabulary/)
    var bestMatch = '';
    var bestPrefix = '';

    for (final entry in prefixCandidates.entries) {
      final namespace = entry.value;
      // Skip empty namespaces to avoid generating invalid prefixes
      if (namespace.isEmpty) continue;

      if (iri.startsWith(namespace) && namespace.length > bestMatch.length) {
        bestMatch = namespace;
        bestPrefix = entry.key;
      }
    }

    // Only add valid prefixes with non-empty namespaces
    if ((bestPrefix.isNotEmpty || bestPrefix == '') && bestMatch.isNotEmpty) {
      // Don't add a prefix for the base URI namespace, unless it's for a predicate
      if (baseUri != null && bestMatch == baseUri && !isPredicate) {
        return;
      }
      usedPrefixes[bestPrefix] = bestMatch;
    } else if (bestMatch.isEmpty && _options.generateMissingPrefixes) {
      // No existing prefix found, generate a new one using namespace mappings

      // Extract namespace from IRI
      final (
        namespace,
        localPart,
      ) = RdfNamespaceMappings.extractNamespaceAndLocalPart(
        iri,
        allowNumericLocalNames: _options.useNumericLocalNames,
      );

      // Skip generating prefixes for protocol-only URIs like "http://" or "https://"
      if (namespace == "http://" ||
          namespace == "https://" ||
          namespace == "ftp://" ||
          namespace == "file://") {
        // If it's just a protocol URI, don't add a prefix
        return;
      }

      // Skip generating prefixes for namespaces that don't end with "/" or "#"
      // since these are not proper namespace delimiters in RDF
      if (!namespace.endsWith('/') && !namespace.endsWith('#')) {
        // For IRIs without proper namespace delimiters, don't add a prefix
        return;
      }

      // Get or generate a prefix for this namespace
      final (prefix, _) = _namespaceMappings.getOrGeneratePrefix(
        namespace,
        customMappings: prefixCandidates,
      );

      // Add the generated prefix to all relevant maps
      usedPrefixes[prefix] = namespace;
      prefixCandidates[prefix] = namespace;
      iriToPrefixMap[namespace] = prefix;
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
    Map<String, String> prefixesByIri,
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
            prefixesByIri,
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
            prefixesByIri,
            blankNodeLabels,
            nodesToInline,
            triplesBySubject,
          );
        } else {
          // Normaler Blank Node
          buffer.write(
            writeTerm(
              item,
              prefixesByIri: prefixesByIri,
              blankNodeLabels: blankNodeLabels,
            ),
          );
        }
      } else {
        // Regulärer Term
        buffer.write(
          writeTerm(
            item,
            prefixesByIri: prefixesByIri,
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
    Map<String, String> prefixesByIri,
    Map<BlankNodeTerm, String> blankNodeLabels,
    Map<BlankNodeTerm, int> blankNodeOccurrences,
    String? baseUri,
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
        prefixesByIri,
        blankNodeLabels,
        nodesToInline,
        triplesBySubject,
        baseUri,
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
    Map<String, String> prefixesByIri,
    Map<BlankNodeTerm, String> blankNodeLabels,
    Set<BlankNodeTerm> nodesToInline,
    Map<RdfSubject, List<Triple>> triplesBySubject,
    String? baseUri,
  ) {
    // Write subject
    final subjectStr = writeTerm(
      subject,
      prefixesByIri: prefixesByIri,
      blankNodeLabels: blankNodeLabels,
      baseUri: baseUri,
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
          prefixesByIri: prefixesByIri,
          blankNodeLabels: blankNodeLabels,
          isPredicate: true,
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
            prefixesByIri,
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
              prefixesByIri,
              blankNodeLabels,
              nodesToInline,
              triplesBySubject,
            );
          } else {
            // Regular blank node
            buffer.write(
              writeTerm(
                object,
                prefixesByIri: prefixesByIri,
                blankNodeLabels: blankNodeLabels,
              ),
            );
          }
        } else {
          // Regular term
          buffer.write(
            writeTerm(
              object,
              prefixesByIri: prefixesByIri,
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
    Map<String, String> prefixesByIri,
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

      // Add separator between predicate-object groups
      if (predicateIndex > 0) {
        buffer.write(' ; ');
      }
      predicateIndex++;

      // Write predicate
      buffer.write(
        writeTerm(
          predicate,
          prefixesByIri: prefixesByIri,
          blankNodeLabels: blankNodeLabels,
          isPredicate: true,
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
            prefixesByIri,
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
            prefixesByIri,
            blankNodeLabels,
            nodesToInline,
            triplesBySubject,
          );
        } else {
          // Regular term
          buffer.write(
            writeTerm(
              object,
              prefixesByIri: prefixesByIri,
              blankNodeLabels: blankNodeLabels,
            ),
          );
        }
      }
    }

    buffer.write(' ]');
  }

  /// Convert RDF terms to Turtle syntax string representation
  String writeTerm(
    RdfTerm term, {
    Map<String, String> prefixesByIri = const {},
    Map<BlankNodeTerm, String> blankNodeLabels = const {},
    String? baseUri,
    bool isPredicate = false,
  }) {
    switch (term) {
      case IriTerm _:
        if (term == Rdf.type) {
          return 'a';
        } else {
          // Check if the predicate is a known prefix
          final iri = term.iri;
          final (
            baseIri,
            localPart,
          ) = RdfNamespaceMappings.extractNamespaceAndLocalPart(
            iri,
            allowNumericLocalNames: _options.useNumericLocalNames,
          );

          // If we have a valid local part
          if (localPart.isNotEmpty || baseIri == iri) {
            final prefix = prefixesByIri[baseIri];
            if (prefix != null) {
              // Handle empty prefix specially
              return prefix.isEmpty ? ':$localPart' : '$prefix:$localPart';
            } else {
              final prefix = prefixesByIri[iri];
              if (prefix != null) {
                return prefix.isEmpty ? ':' : '$prefix:';
              }
            }
          }
        }

        // For predicates or terms with baseUri:
        // - For predicates, always use prefixes if they exist (handled above)
        // - For subject/object under baseUri, check if there's a better prefix
        //   that is longer than baseUri, if not, use relative IRI

        // If we have a baseUri and this term starts with it
        if (baseUri != null && term.iri.startsWith(baseUri)) {
          // For non-predicates that start with baseUri, check if there's a
          // namespace prefix that's longer than baseUri
          if (!isPredicate) {
            bool betterPrefixExists = false;
            for (final entry in prefixesByIri.entries) {
              final namespace = entry.key;
              // If there's a namespace that:
              // 1. Is a prefix of this IRI
              // 2. Is longer than baseUri
              // 3. Has an associated prefix
              if (term.iri.startsWith(namespace) &&
                  namespace.length > baseUri.length) {
                betterPrefixExists = true;
                break;
              }
            }

            // If no better prefix exists, use relative IRI
            if (!betterPrefixExists) {
              final localPart = term.iri.substring(baseUri.length);
              return '<$localPart>';
            }
            // Otherwise, fall through to the full IRI case below
            // (which might still find a prefix to use)
          }
        }

        return '<${term.iri}>';
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
        if (literal.datatype == Xsd.integer) {
          return literal.value;
        }
        if (literal.datatype == Xsd.decimal) {
          return literal.value;
        }
        if (literal.datatype == Xsd.boolean) {
          return literal.value;
        }

        var escapedLiteralValue = _escapeTurtleString(literal.value);

        if (literal.language != null) {
          return '"$escapedLiteralValue"@${literal.language}';
        }
        if (literal.datatype != Xsd.string) {
          return '"$escapedLiteralValue"^^${writeTerm(literal.datatype, prefixesByIri: prefixesByIri, blankNodeLabels: blankNodeLabels)}';
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
