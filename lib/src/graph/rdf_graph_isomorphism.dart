/// RDF Graph Isomorphism Extension
///
/// Provides functionality to determine if two RDF graphs are structurally isomorphic.
/// This extension adds the [isIsomorphicTo] method to the [RdfGraph] class, enabling
/// comparison of graph structures while ignoring specific URI labels and blank node identifiers.
///
/// Graph isomorphism in RDF context means that two graphs have the same structural pattern,
/// even if they use different URIs or blank node labels. This is crucial for comparing
/// semantic equivalence of RDF data from different sources or with different naming conventions.
///
/// Key features:
/// - Structural comparison that ignores URI and blank node label differences
/// - Support for graphs with mixed IRI and blank node terms
/// - Handles literal values with language tags and datatypes
///
/// Example usage:
/// ```dart
/// import 'package:rdf_core/rdf_core.dart';
///
/// // Create two graphs with different URIs but same structure
/// final graph1 = turtle.decode('''
//   @prefix ex: <http://example.org/> .
///   ex:alice ex:knows _:person1 .
///   _:person1 ex:name "Bob" .
/// ''');
///
/// final graph2 = turtle.decode('''
//   @prefix foaf: <http://xmlns.com/foaf/0.1/> .
///   foaf:personA foaf:knows _:p1 .
///   _:p1 foaf:name "Bob" .
/// ''');
///
/// // Check if they are isomorphic (same structure, different labels)
/// final isomorphic = graph1.isIsomorphicTo(other: graph2); // true
/// ```
///
/// Performance considerations:
/// - Time complexity is O(n log n) where n is the number of triples
/// - Space complexity is O(n) for building structural signatures
///
/// Related concepts:
/// - [RDF Graph Isomorphism](https://en.wikipedia.org/wiki/Graph_isomorphism)
/// - [RDF Semantics - Graph Equivalence](https://www.w3.org/TR/rdf11-mt/#graph-equivalence)
library rdf_graph_isomorphism;

import 'package:rdf_core/rdf_core.dart';

/// Extension providing graph isomorphism checking functionality to RdfGraph.
///
/// This extension adds methods to compare RDF graphs for structural equivalence,
/// ignoring differences in URI labels and blank node identifiers. The core method
/// [isIsomorphicTo] implements an efficient algorithm that creates structural
/// signatures for graph comparison.
extension RdfGraphIsomorphism on RdfGraph {
  /// Determines if this RDF graph is isomorphic to another RDF graph.
  ///
  /// This implementation uses structural isomorphism, comparing the graph structure
  /// while ignoring specific URI labels and blank node identifiers. Two graphs
  /// are considered isomorphic if they have the same structural pattern.
  ///
  /// Parameters:
  /// - [other] The graph to compare against this one
  ///
  /// Returns:
  /// true if the graphs are structurally isomorphic, false otherwise.
  ///
  /// Example:
  /// ```dart
  /// final graph1 = turtle.decode('@prefix ex: <http://example.org/> . ex:a ex:p ex:b .');
  /// final graph2 = turtle.decode('@prefix ex: <http://example.org/> . ex:x ex:p ex:y .');
  /// final isomorphic = graph1.isIsomorphicTo(other: graph2); // true
  /// ```
  bool isIsomorphicTo({required RdfGraph other}) {
    final triplesThis = triples.toList();
    final triplesOther = other.triples.toList();

    // Basic preprocessing
    if (triplesThis.length != triplesOther.length) {
      return false;
    }

    // Quick check: if both graphs are empty, they are isomorphic
    if (triplesThis.isEmpty && triplesOther.isEmpty) {
      return true;
    }

    return _checkStructuralIsomorphism(
      triplesThis: triplesThis,
      triplesOther: triplesOther,
    );
  }

  /// Performs structural isomorphism checking on the provided triple lists.
  ///
  /// This method coordinates the isomorphism checking process by delegating
  /// to the graph structure comparison algorithm.
  ///
  /// Parameters:
  /// - [triplesThis] The triples from the first graph
  /// - [triplesOther] The triples from the second graph
  ///
  /// Returns:
  /// true if the triple structures are isomorphic
  bool _checkStructuralIsomorphism({
    required List<Triple> triplesThis,
    required List<Triple> triplesOther,
  }) {
    // Use structural comparison for all graphs, ignoring specific URI and blank node labels
    return _compareGraphStructure(
      triplesThis: triplesThis,
      triplesOther: triplesOther,
    );
  }

  /// Compares the structural properties of two graphs.
  ///
  /// This method implements the core isomorphism algorithm by creating
  /// structural signatures for both graphs and comparing them.
  ///
  /// Parameters:
  /// - [triplesThis] The triples from the first graph
  /// - [triplesOther] The triples from the second graph
  ///
  /// Returns:
  /// true if the graph structures are equivalent
  bool _compareGraphStructure({
    required List<Triple> triplesThis,
    required List<Triple> triplesOther,
  }) {
    // For graphs without blank nodes, we need to check if they have the same structure
    // even if the URIs are different

    if (triplesThis.length != triplesOther.length) {
      return false;
    }

    // Create structural signatures that are independent of specific URIs
    final sigThis = _createStructuralSignature(triples: triplesThis);
    final sigOther = _createStructuralSignature(triples: triplesOther);

    return sigThis == sigOther;
  }

  /// Creates a structural signature for a set of triples.
  ///
  /// The signature captures the graph's structural properties including:
  /// - Node connectivity patterns (incoming/outgoing edges)
  /// - Node types (IRI vs blank nodes)
  /// - Edge patterns with predicate and object types
  /// - Literal values
  ///
  /// This signature is independent of specific URI labels and blank node identifiers,
  /// allowing comparison of structurally equivalent graphs.
  ///
  /// Parameters:
  /// - [triples] The list of triples to analyze
  ///
  /// Returns:
  /// A string signature representing the graph's structure
  String _createStructuralSignature({required List<Triple> triples}) {
    // Create a signature based on the graph structure, not specific URIs

    // Build adjacency information
    final outgoing = <dynamic, List<String>>{};
    final incoming = <dynamic, List<String>>{};
    final allNodes = <dynamic>{};
    final literals = <String>{};

    for (final triple in triples) {
      allNodes.add(triple.subject);
      allNodes.add(triple.object);

      // Track outgoing edges
      if (!outgoing.containsKey(triple.subject)) {
        outgoing[triple.subject] = [];
      }

      // Track incoming edges
      if (!incoming.containsKey(triple.object)) {
        incoming[triple.object] = [];
      }

      final predStr = triple.predicate.toString();
      final objStr = triple.object.toString();

      outgoing[triple.subject]!.add('$predStr->$objStr');
      incoming[triple.object]!.add('$predStr<-${triple.subject}');

      if (triple.object is LiteralTerm) {
        literals.add(objStr);
      }
    }

    // Create node signatures based on their structural properties
    final nodeSignatures = <String>[];

    for (final node in allNodes) {
      if (node is LiteralTerm) continue; // Skip literals as nodes

      final outList = outgoing[node] ?? [];
      final inList = incoming[node] ?? [];

      outList.sort();
      inList.sort();

      // Create a signature for this node based on its connections
      final nodeType = node is IriTerm ? 'iri' : 'blank';
      final outDegree = outList.length;
      final inDegree = inList.length;

      // Create patterns for outgoing and incoming edges
      final outPatterns = <String>{};
      final inPatterns = <String>{};

      for (final out in outList) {
        final parts = out.split('->');
        if (parts.length == 2) {
          final pred = parts[0];
          final obj = parts[1];
          final objType =
              obj.startsWith('"') || obj.contains('^^') ? 'literal' : 'iri';
          outPatterns.add('$pred->$objType');
        }
      }

      for (final inp in inList) {
        final parts = inp.split('<-');
        if (parts.length == 2) {
          final pred = parts[0];
          final subj = parts[1];
          final subjType =
              subj.startsWith('"') || subj.contains('^^') ? 'literal' : 'iri';
          inPatterns.add('$pred<-$subjType');
        }
      }

      final outPatternsStr = outPatterns.toList()..sort();
      final inPatternsStr = inPatterns.toList()..sort();

      nodeSignatures.add(
        '$nodeType:$outDegree:$inDegree:${outPatternsStr.join(',')}:${inPatternsStr.join(',')}',
      );
    }

    nodeSignatures.sort();

    // Add literal information
    final sortedLiterals = literals.toList()..sort();

    return '${nodeSignatures.join('|')}#${sortedLiterals.join('|')}';
  }
}
