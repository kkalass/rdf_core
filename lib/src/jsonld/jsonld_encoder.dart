/// JSON-LD Serializer Implementation
///
/// Implements the [JsonLdEncoder] class to convert RDF graphs to JSON-LD format.
///
/// Example usage:
/// ```dart
/// import 'package:rdf_core/src/jsonld/jsonld_serializer.dart';
/// final serializer = JsonLdSerializer();
/// final jsonld = serializer.write(graph);
/// ```
///
/// See: [JSON-LD 1.1 Specification](https://www.w3.org/TR/json-ld11/)
library jsonld_serializer;

import 'dart:convert';

import 'package:logging/logging.dart';
import 'package:rdf_core/src/graph/rdf_graph.dart';
import 'package:rdf_core/src/graph/rdf_term.dart';
import 'package:rdf_core/src/graph/triple.dart';
import 'package:rdf_core/src/rdf_encoder.dart';
import 'package:rdf_core/src/vocab/namespaces.dart';
import 'package:rdf_core/src/vocab/rdf.dart';
import 'package:rdf_core/src/vocab/xsd.dart';

final _log = Logger("rdf.jsonld");

class JsonLdEncoderOptions extends RdfGraphEncoderOptions {
  const JsonLdEncoderOptions({Map<String, String> customPrefixes = const {}})
    : super(customPrefixes: customPrefixes);

  static JsonLdEncoderOptions from(RdfGraphEncoderOptions options) =>
      switch (options) {
        JsonLdEncoderOptions _ => options,
        _ => JsonLdEncoderOptions(customPrefixes: options.customPrefixes),
      };
}

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
/// The serializer produces compacted JSON-LD by default, using prefixes
/// to make property names more readable.
final class JsonLdEncoder extends RdfGraphEncoder {
  /// Well-known common prefixes used for more readable JSON-LD output.
  final RdfNamespaceMappings _namespaceMappings;
  final JsonLdEncoderOptions _options;

  /// Creates a new JSON-LD serializer.
  const JsonLdEncoder({
    RdfNamespaceMappings? namespaceMappings,
    JsonLdEncoderOptions options = const JsonLdEncoderOptions(),
  }) : _options = options,
       _namespaceMappings = namespaceMappings ?? const RdfNamespaceMappings();

  @override
  RdfGraphEncoder withOptions(RdfGraphEncoderOptions options) => JsonLdEncoder(
    namespaceMappings: _namespaceMappings,
    options: JsonLdEncoderOptions.from(options),
  );

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

    // Create context with prefixes
    final context = _createContext(graph, _options.customPrefixes);

    // Group triples by subject
    final subjectGroups = _groupTriplesBySubject(graph.triples);

    // Check if we have only one subject group or multiple
    // For a single subject we create a JSON object, for multiple we use a JSON array
    if (subjectGroups.length == 1) {
      final Map<String, dynamic> result = {'@context': context};

      // Add the single subject node
      final entry = subjectGroups.entries.first;
      final subjectNode = _createNodeObject(
        entry.key,
        entry.value,
        context,
        blankNodeLabels,
      );
      result.addAll(subjectNode);

      return JsonEncoder.withIndent('  ').convert(result);
    } else {
      // Create a @graph structure for multiple subjects
      final Map<String, dynamic> result = {
        '@context': context,
        '@graph':
            subjectGroups.entries.map((entry) {
              return _createNodeObject(
                entry.key,
                entry.value,
                context,
                blankNodeLabels,
              );
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
  Map<String, String> _createContext(
    RdfGraph graph,
    Map<String, String> customPrefixes,
  ) {
    final context = <String, String>{};

    // Add all custom prefixes
    context.addAll(customPrefixes);

    // Add common prefixes that are used in the graph
    final allPrefixes = {..._namespaceMappings.asMap(), ...customPrefixes};
    final usedPrefixes = _extractUsedPrefixes(graph, allPrefixes);

    // Add prefixes that don't conflict with custom ones
    for (final entry in usedPrefixes.entries) {
      if (!customPrefixes.containsKey(entry.key)) {
        context[entry.key] = entry.value;
      }
    }

    return context;
  }

  /// Extracts only those prefixes that are actually used in the graph's triples.
  Map<String, String> _extractUsedPrefixes(
    RdfGraph graph,
    Map<String, String> prefixCandidates,
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
        );
      }

      // Check predicate
      if (triple.predicate is IriTerm) {
        _checkTermForPrefix(
          triple.predicate as IriTerm,
          iriToPrefixMap,
          usedPrefixes,
          prefixCandidates,
        );
      }

      // Check object
      if (triple.object is IriTerm) {
        _checkTermForPrefix(
          triple.object as IriTerm,
          iriToPrefixMap,
          usedPrefixes,
          prefixCandidates,
        );
      } else if (triple.object is LiteralTerm) {
        final literal = triple.object as LiteralTerm;
        if (literal.datatype != Xsd.string) {
          _checkTermForPrefix(
            literal.datatype,
            iriToPrefixMap,
            usedPrefixes,
            prefixCandidates,
          );
        }
      }
    }

    return usedPrefixes;
  }

  /// Checks if a term's IRI matches any prefix and adds it to the usedPrefixes if it does.
  void _checkTermForPrefix(
    IriTerm term,
    Map<String, String> iriToPrefixMap,
    Map<String, String> usedPrefixes,
    Map<String, String> prefixCandidates,
  ) {
    final iri = term.iri;

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
      if (iri.startsWith(namespace) && namespace.length > bestMatch.length) {
        bestMatch = namespace;
        bestPrefix = entry.key;
      }
    }

    if (bestPrefix.isNotEmpty) {
      usedPrefixes[bestPrefix] = bestMatch;
    }
  }

  /// Groups triples by their subject for easier JSON-LD structure creation.
  Map<RdfSubject, List<Triple>> _groupTriplesBySubject(List<Triple> triples) {
    final Map<RdfSubject, List<Triple>> result = {};

    for (final triple in triples) {
      result.putIfAbsent(triple.subject, () => []).add(triple);
    }

    return result;
  }

  /// Creates a JSON object representing an RDF node with all its properties.
  Map<String, dynamic> _createNodeObject(
    RdfSubject subject,
    List<Triple> triples,
    Map<String, String> context,
    Map<BlankNodeTerm, String> blankNodeLabels,
  ) {
    final result = <String, dynamic>{
      '@id': _getSubjectId(subject, blankNodeLabels),
    };

    // Group triples by predicate
    final predicateGroups = <String, List<RdfObject>>{};
    final typeObjects = <RdfObject>[];

    for (final triple in triples) {
      if (triple.predicate == Rdf.type) {
        // Handle rdf:type specially
        typeObjects.add(triple.object);
      } else {
        final predicateKey = _getPredicateKey(triple.predicate, context);
        predicateGroups.putIfAbsent(predicateKey, () => []).add(triple.object);
      }
    }

    // Add types to the result
    if (typeObjects.isNotEmpty) {
      if (typeObjects.length == 1) {
        // Single type
        result['@type'] = _getObjectValue(typeObjects[0], blankNodeLabels);
      } else {
        // Multiple types
        result['@type'] =
            typeObjects
                .map((obj) => _getObjectValue(obj, blankNodeLabels))
                .toList();
      }
    }

    // Add other predicates to the result
    for (final entry in predicateGroups.entries) {
      if (entry.value.length == 1) {
        // Single value for predicate
        result[entry.key] = _getObjectValue(entry.value[0], blankNodeLabels);
      } else {
        // Multiple values for predicate
        result[entry.key] =
            entry.value
                .map((obj) => _getObjectValue(obj, blankNodeLabels))
                .toList();
      }
    }

    return result;
  }

  /// Returns the appropriate string ID for a subject term.
  String _getSubjectId(
    RdfSubject subject,
    Map<BlankNodeTerm, String> blankNodeLabels,
  ) {
    if (subject is IriTerm) {
      return subject.iri;
    } else if (subject is BlankNodeTerm) {
      final label = blankNodeLabels[subject];
      if (label == null) {
        _log.warning(
          'No label generated for blank node subject, using fallback label',
        );
        return '_:b${identityHashCode(subject)}';
      }
      return '_:$label';
    } else {
      return subject.toString();
    }
  }

  /// Returns the appropriate key name for a predicate.
  /// Uses prefixed notation when a matching prefix is available in the context.
  String _getPredicateKey(RdfPredicate predicate, Map<String, String> context) {
    if (predicate is! IriTerm) {
      return predicate.toString();
    }

    final iri = predicate.iri;

    // Find the longest (most specific) matching prefix in the context
    var bestMatch = '';
    var bestPrefix = '';

    for (final entry in context.entries) {
      final prefix = entry.key;
      final namespace = entry.value;

      if (iri.startsWith(namespace) && namespace.length > bestMatch.length) {
        bestMatch = namespace;
        bestPrefix = prefix;
      }
    }

    // If we found a matching prefix, use it to compact the IRI
    if (bestPrefix.isNotEmpty) {
      final localName = iri.substring(bestMatch.length);
      if (localName.isNotEmpty) {
        return '$bestPrefix:$localName';
      } else {
        return '$bestPrefix:';
      }
    }

    // If no prefix matches, use the full IRI
    return iri;
  }

  /// Converts an RDF object to its appropriate JSON-LD representation.
  dynamic _getObjectValue(
    RdfObject object,
    Map<BlankNodeTerm, String> blankNodeLabels,
  ) {
    if (object is IriTerm) {
      return {'@id': object.iri};
    } else if (object is BlankNodeTerm) {
      final label = blankNodeLabels[object];
      if (label == null) {
        _log.warning(
          'No label generated for blank node object, using fallback label',
        );
        return {'@id': '_:b${identityHashCode(object)}'};
      }
      return {'@id': '_:$label'};
    } else if (object is LiteralTerm) {
      return _getLiteralValue(object);
    } else {
      return object.toString();
    }
  }

  /// Converts an RDF literal to its appropriate JSON-LD representation.
  dynamic _getLiteralValue(LiteralTerm literal) {
    final value = literal.value;

    // Handle language-tagged strings
    if (literal.language != null) {
      return {'@value': value, '@language': literal.language};
    }

    // Handle different datatypes
    final datatype = literal.datatype;

    // String literals (default datatype)
    if (datatype == Xsd.string) {
      return value;
    }

    // Number literals
    if (datatype == Xsd.integer) {
      return int.tryParse(value) ?? {'@value': value, '@type': datatype.iri};
    }

    if (datatype == Xsd.double || datatype == Xsd.decimal) {
      return double.tryParse(value) ?? {'@value': value, '@type': datatype.iri};
    }

    // Boolean literals
    if (datatype == Xsd.boolean) {
      if (value == 'true') return true;
      if (value == 'false') return false;
      return {'@value': value, '@type': datatype.iri};
    }

    // Other typed literals
    return {'@value': value, '@type': datatype.iri};
  }
}
