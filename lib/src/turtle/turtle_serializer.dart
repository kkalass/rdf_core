import 'package:logging/logging.dart';
import 'package:rdf_core/src/graph/rdf_graph.dart';
import 'package:rdf_core/src/graph/rdf_term.dart';
import 'package:rdf_core/src/graph/triple.dart';
import 'package:rdf_core/src/rdf_serializer.dart';
import 'package:rdf_core/src/vocab/namespaces.dart';
import 'package:rdf_core/src/vocab/rdf.dart';
import 'package:rdf_core/src/vocab/xsd.dart';

final _log = Logger("rdf.turtle");

/// Turtle Serializer Implementation
///
/// Implements the [TurtleSerializer] class for serializing RDF graphs to Turtle syntax.
///
/// Example usage:
/// ```dart
/// import 'package:rdf_core/src/turtle/turtle_serializer.dart';
/// final serializer = TurtleSerializer();
/// final turtle = serializer.write(graph);
/// ```
///
/// See: [Turtle - Terse RDF Triple Language](https://www.w3.org/TR/turtle/)
/// NOTE: Always use canonical RDF vocabularies (e.g., http://xmlns.com/foaf/0.1/) with http://, not https://
/// This serializer will warn if it detects use of https:// for a namespace that is canonical as http://.
class TurtleSerializer implements RdfSerializer {
  /// A map of well-known common RDF prefixes used in Turtle serialization.
  /// These prefixes provide shorthand notation for commonly used RDF namespaces
  /// and do not need to be specified explicitly for serialization.
  final RdfNamespaceMappings _namespaceMappings;

  TurtleSerializer({RdfNamespaceMappings? namespaceMappings})
    : _namespaceMappings = namespaceMappings ?? RdfNamespaceMappings();

  @override
  String write(
    RdfGraph graph, {
    String? baseUri,
    Map<String, String> customPrefixes = const {},
  }) {
    _log.info('Serializing graph to Turtle');
    // TODO KK - support base IRIs - store all refs to IRIs within this
    // pod relative to the pod root (or the application root within the pod?)

    final buffer = StringBuffer();

    // Map to store generated blank node labels for this serialization
    final Map<BlankNodeTerm, String> blankNodeLabels = {};
    _generateBlankNodeLabels(graph, blankNodeLabels);

    // 1. Write prefixes
    final prefixCandidates = {..._namespaceMappings.asMap(), ...customPrefixes};
    // Identify which prefixes are actually used in the graph
    final prefixes = _extractUsedPrefixes(graph, prefixCandidates);

    _writePrefixes(buffer, prefixes);

    final prefixesByIri = prefixes.map((prefix, iri) {
      return MapEntry(iri, prefix);
    });

    // 2. Write triples grouped by subject
    _writeTriples(buffer, graph, prefixesByIri, blankNodeLabels);

    return buffer.toString();
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

  /// Extracts only those prefixes that are actually used in the graph's triples.
  ///
  /// @param graph The RDF graph containing triples to analyze
  /// @param prefixCandidates Map of potential prefixes to their IRIs
  /// @return A filtered map containing only the prefixes used in the graph
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
        if (literal.datatype == XsdTypes.string ||
            literal.datatype == RdfTypes.langString) {
          // string and langString will not actually be written, they are implicit.
          continue;
        }
        _checkTermForPrefix(
          literal.datatype,
          iriToPrefixMap,
          usedPrefixes,
          prefixCandidates,
        );
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
    if (term == RdfPredicates.type) {
      // This IRI has special handling in Turtle besides the prefix stuff:
      // it will be rendered simply as "a" - no prefix needed
      return;
    }
    // Warn if https:// is used and http:// is in the prefix map for the same path
    final iri = term.iri;
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
      usedPrefixes[bestPrefix] = bestMatch;
    }
  }

  /// Writes prefix declarations to the output buffer.
  void _writePrefixes(StringBuffer buffer, Map<String, String> prefixes) {
    if (prefixes.isEmpty) {
      return;
    }

    // Write prefixes in alphabetical order for consistent output,
    // but handle empty prefix separately (should appear as ':')
    final sortedPrefixes =
        prefixes.entries.toList()..sort((a, b) {
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
        outgoingTriples
            .where((t) => t.predicate == RdfPredicates.first)
            .toList();
    final restTriples =
        outgoingTriples
            .where((t) => t.predicate == RdfPredicates.rest)
            .toList();

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
        (t) => t.subject == currentNode && t.predicate == RdfPredicates.first,
        orElse:
            () =>
                throw Exception(
                  'Invalid RDF collection: missing rdf:first for $currentNode',
                ),
      );

      // Add the object to our items list
      items.add(firstTriple.object);

      // Find the rdf:rest triple for the current node
      final restTriple = graph.triples.firstWhere(
        (t) => t.subject == currentNode && t.predicate == RdfPredicates.rest,
        orElse:
            () =>
                throw Exception(
                  'Invalid RDF collection: missing rdf:rest for $currentNode',
                ),
      );

      // If we've reached rdf:nil, we're done
      if (restTriple.object == RdfResources.nil) {
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

  /// Writes all triples to the output buffer, grouped by subject.
  void _writeTriples(
    StringBuffer buffer,
    RdfGraph graph,
    Map<String, String> prefixesByIri,
    Map<BlankNodeTerm, String> blankNodeLabels,
  ) {
    if (graph.triples.isEmpty) {
      return;
    }

    // Group triples by subject for more compact representation
    final Map<RdfSubject, List<Triple>> triplesBySubject = {};

    // Track which blank nodes are part of collections to avoid duplicating them
    final Set<BlankNodeTerm> processedCollectionNodes = {};

    // First pass: group triples by subject and identify collections
    for (final triple in graph.triples) {
      // Skip triples that are part of a collection structure
      if ((triple.predicate == RdfPredicates.first ||
              triple.predicate == RdfPredicates.rest) &&
          triple.subject is BlankNodeTerm &&
          processedCollectionNodes.contains(triple.subject)) {
        continue;
      }

      triplesBySubject.putIfAbsent(triple.subject, () => []).add(triple);
    }

    // Write each subject group
    var isFirst = true;
    for (final entry in triplesBySubject.entries) {
      final subject = entry.key;
      final triples = entry.value;

      if (!isFirst) {
        buffer.writeln();
        buffer.writeln();
      }
      isFirst = false;

      // Check if this subject is a collection
      if (subject is BlankNodeTerm) {
        final collectionItems = _extractCollection(graph, subject);
        if (collectionItems != null) {
          // Mark all nodes in this collection as processed
          var currentNode = subject;
          while (true) {
            processedCollectionNodes.add(currentNode);

            // Find the rdf:rest triple
            final restTriple = graph.triples.firstWhere(
              (t) =>
                  t.subject == currentNode && t.predicate == RdfPredicates.rest,
            );

            if (restTriple.object == RdfResources.nil) {
              break;
            }

            currentNode = restTriple.object as BlankNodeTerm;
          }

          // Skip this subject as we'll handle the collection where it's referenced
          continue;
        }
      }

      _writeSubjectGroup(
        buffer,
        subject,
        triples,
        graph,
        processedCollectionNodes,
        prefixesByIri,
        blankNodeLabels,
      );
    }
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
  ) {
    // Write subject
    final subjectStr = writeTerm(
      subject,
      prefixesByIri: prefixesByIri,
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

    // Write predicates and objects
    var predicateIndex = 0;
    for (final entry in triplesByPredicate.entries) {
      final predicate = entry.key;
      final objects = entry.value;

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
        if (object == RdfResources.nil) {
          buffer.write('()');
          continue;
        }

        // Check if this object is a collection
        if (object is BlankNodeTerm) {
          final collectionItems = _extractCollection(graph, object);
          if (collectionItems != null) {
            // Mark this node and all related nodes as processed
            var currentNode = object;
            while (true) {
              processedCollectionNodes.add(currentNode);

              // Find the rdf:rest triple
              final restTriples =
                  graph.triples
                      .where(
                        (t) =>
                            t.subject == currentNode &&
                            t.predicate == RdfPredicates.rest,
                      )
                      .toList();

              if (restTriples.isEmpty) {
                // This shouldn't happen in a valid collection
                break;
              }

              if (restTriples.first.object == RdfResources.nil) {
                break;
              }

              if (restTriples.first.object is! BlankNodeTerm) {
                // This shouldn't happen in a valid collection
                break;
              }

              currentNode = restTriples.first.object as BlankNodeTerm;
            }

            // Write the collection in compact form
            buffer.write('(');
            for (var i = 0; i < collectionItems.length; i++) {
              if (i > 0) {
                buffer.write(' ');
              }

              final item = collectionItems[i];

              // If the item is itself another collection, process it recursively
              if (item is BlankNodeTerm) {
                final nestedItems = _extractCollection(graph, item);
                if (nestedItems != null) {
                  // Mark all nodes in the nested collection as processed too
                  var nestedNode = item;
                  while (true) {
                    processedCollectionNodes.add(nestedNode);

                    // Find the rdf:rest triple
                    final restTriples =
                        graph.triples
                            .where(
                              (t) =>
                                  t.subject == nestedNode &&
                                  t.predicate == RdfPredicates.rest,
                            )
                            .toList();

                    if (restTriples.isEmpty) {
                      break;
                    }

                    if (restTriples.first.object == RdfResources.nil) {
                      break;
                    }

                    if (restTriples.first.object is! BlankNodeTerm) {
                      break;
                    }

                    nestedNode = restTriples.first.object as BlankNodeTerm;
                  }

                  // Write the nested collection
                  buffer.write('(');
                  for (var j = 0; j < nestedItems.length; j++) {
                    if (j > 0) {
                      buffer.write(' ');
                    }
                    buffer.write(
                      writeTerm(
                        nestedItems[j],
                        prefixesByIri: prefixesByIri,
                        blankNodeLabels: blankNodeLabels,
                      ),
                    );
                  }
                  buffer.write(')');
                } else {
                  // It's a blank node but not a collection
                  buffer.write(
                    writeTerm(
                      item,
                      prefixesByIri: prefixesByIri,
                      blankNodeLabels: blankNodeLabels,
                    ),
                  );
                }
              } else {
                // Regular term
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

  /// Convert RDF terms to Turtle syntax string representation
  String writeTerm(
    RdfTerm term, {
    Map<String, String> prefixesByIri = const {},
    Map<BlankNodeTerm, String> blankNodeLabels = const {},
  }) {
    switch (term) {
      case IriTerm _:
        if (term == RdfPredicates.type) {
          return 'a';
        } else {
          // Check if the predicate is a known prefix
          final String baseIri;
          final String localPart;

          final iri = term.iri;
          final hashIndex = iri.lastIndexOf('#');
          final slashIndex = iri.lastIndexOf('/');

          if (hashIndex > slashIndex && hashIndex != -1) {
            baseIri = iri.substring(0, hashIndex + 1);
            localPart = iri.substring(hashIndex + 1);
          } else if (slashIndex != -1) {
            baseIri = iri.substring(0, slashIndex + 1);
            localPart = iri.substring(slashIndex + 1);
          } else {
            baseIri = iri;
            localPart = '';
          }

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
        if (literal.datatype == XsdTypes.integer) {
          return literal.value;
        }
        if (literal.datatype == XsdTypes.decimal) {
          return literal.value;
        }
        if (literal.datatype == XsdTypes.boolean) {
          return literal.value;
        }

        var escapedLiteralValue = _escapeTurtleString(literal.value);

        if (literal.language != null) {
          return '"$escapedLiteralValue"@${literal.language}';
        }
        if (literal.datatype != XsdTypes.string) {
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
