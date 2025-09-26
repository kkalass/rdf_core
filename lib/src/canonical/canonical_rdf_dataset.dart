/// Canonical RDF Dataset Implementation
///
/// Provides a wrapper around [RdfDataset] that implements semantic equality and
/// hashing based on RDF canonicalization. This class offers the same functionality
/// as [RdfDataset] but with equality and hash code operations that are based on
/// the canonical serialized form rather than syntactic triple matching.
///
/// ## Key Differences from RdfDataset
///
/// - **Semantic equality**: Two [CanonicalRdfDataset] instances are equal if they
///   represent the same RDF data semantically, even with different blank node labels
/// - **Consistent hashing**: Hash code is computed from the canonical form, ensuring
///   semantically equivalent datasets have the same hash
/// - **Performance trade-off**: Equality and hashing operations are more expensive
///   due to canonicalization, but provide true semantic equivalence
///
/// ## When to Use
///
/// Use [CanonicalRdfDataset] when:
/// - You need semantic equality for datasets that may have different blank node labels
/// - You want to use datasets as keys in maps or elements in sets with semantic equality
/// - You're implementing algorithms that require RDF graph isomorphism
///
/// For performance-critical scenarios where syntactic equality is sufficient,
/// use [RdfDataset] directly.
///
/// ## Canonicalization
///
/// The canonical form is computed using the RDF Canonicalization algorithm as specified
/// in the [RDF Dataset Canonicalization](https://www.w3.org/TR/rdf-canon/) specification.
/// The canonical N-Quads representation is computed lazily and cached for performance.
///
/// ## Usage Example
///
/// ```dart
/// import 'package:rdf_core/rdf_core.dart';
/// import 'package:rdf_core/src/canonical/canonical_rdf_dataset.dart';
///
/// // Create datasets with different blank node labels but same structure
/// final dataset1 = RdfDataset.withDefaultGraph(RdfGraph(triples: [
///   Triple(BlankNodeTerm(), foaf.name, LiteralTerm.string('John'))
/// ]));
/// final dataset2 = RdfDataset.withDefaultGraph(RdfGraph(triples: [
///   Triple(BlankNodeTerm(), foaf.name, LiteralTerm.string('John'))
/// ]));
///
/// // Syntactic comparison
/// assert(dataset1 != dataset2); // Different blank node instances
///
/// // Semantic comparison using canonical wrapper
/// final canonical1 = CanonicalRdfDataset(dataset1);
/// final canonical2 = CanonicalRdfDataset(dataset2);
/// assert(canonical1 == canonical2); // Semantically equivalent
///
/// // Can be used as map keys with semantic equality
/// final Map<CanonicalRdfDataset, String> semanticMap = {
///   canonical1: 'First dataset',
///   canonical2: 'Same as first', // Will overwrite due to equality
/// };
/// assert(semanticMap.length == 1);
/// ```
///
/// See [RdfDataset] documentation for detailed information about dataset operations,
/// as this class delegates all dataset functionality to the wrapped instance.
library canonical_rdf_dataset;

import 'package:rdf_core/rdf_core.dart';

/// A wrapper around [RdfDataset] that provides semantic equality and hashing
/// based on RDF canonicalization.
///
/// This class implements all the same operations as [RdfDataset] by delegation,
/// but overrides equality and hash code operations to use the canonical
/// serialized form. This ensures that two datasets with the same semantic
/// content but different blank node labels are considered equal.
///
/// The canonical form is computed lazily using the RDF Dataset Canonicalization
/// algorithm with exactly-once semantics. The first access to [canonicalNQuads],
/// [hashCode], or [operator ==] will trigger canonicalization; subsequent operations
/// access the cached result with zero overhead.
///
/// ## Performance Considerations
///
/// - **First access**: Expensive due to canonicalization computation (exactly once, thread-safe)
/// - **Subsequent access**: Zero overhead - direct field access with no synchronization
/// - **Memory usage**: Additional memory for cached canonical form
/// - **Thread safety**: Fully thread-safe. Concurrent first access will block until
///   computation completes, ensuring exactly-once evaluation. No synchronization overhead
///   on subsequent accesses.
///
/// ## Delegation Pattern
///
/// All dataset operations (graph access, iteration, etc.) are delegated to the
/// wrapped [RdfDataset] instance, so performance characteristics match the
/// underlying implementation except for equality and hashing operations.
final class CanonicalRdfDataset {
  /// The wrapped RdfDataset instance that provides the actual dataset functionality
  final RdfDataset _inputDataset;

  /// Get the canonical N-Quads serialization of this dataset, computed lazily.
  ///
  /// The canonical form is computed using the RDF Dataset Canonicalization
  /// algorithm as specified in the W3C RDF-Canon specification. The result
  /// is cached after the first computation for performance.
  ///
  /// This canonical form serves as the basis for [operator ==] and [hashCode]
  /// operations, ensuring that semantically equivalent datasets (those with
  /// the same structure but potentially different blank node labels) have
  /// identical canonical representations.
  ///
  /// Returns:
  /// The canonical N-Quads serialization as a string
  late final String canonicalNQuads = canonicalize(_inputDataset);

  /// Creates a canonical wrapper around the given dataset
  ///
  /// The provided dataset is wrapped (not copied) and used for all dataset
  /// operations. The canonical form will be computed lazily on first access
  /// to [canonicalNQuads], [hashCode], or [operator ==].
  ///
  /// Parameters:
  /// - [dataset] The RDF dataset to wrap with canonical equality semantics
  CanonicalRdfDataset(RdfDataset dataset) : _inputDataset = dataset;

  /// Access the wrapped RdfDataset instance
  ///
  /// This provides access to the underlying dataset for operations that
  /// don't require canonical equality semantics or for interoperability
  /// with code expecting [RdfDataset] instances.
  ///
  /// Returns:
  /// The wrapped [RdfDataset] instance
  RdfDataset get asRdfDataset => _inputDataset;

  /// Hash code based on the canonical serialization
  ///
  /// This ensures that semantically equivalent datasets have the same hash code,
  /// making it safe to use [CanonicalRdfDataset] instances as keys in maps or
  /// elements in sets with semantic equality semantics.
  ///
  /// The hash is computed from the canonical N-Quads representation, which
  /// normalizes blank node labels according to the canonicalization algorithm.
  @override
  int get hashCode => canonicalNQuads.hashCode;

  /// Semantic equality based on canonical serialization
  ///
  /// Two [CanonicalRdfDataset] instances are considered equal if their
  /// canonical N-Quads representations are identical. This provides true
  /// semantic equality - datasets with the same RDF structure but different
  /// blank node labels will be considered equal.
  ///
  /// This is in contrast to [RdfDataset.operator ==] which performs syntactic
  /// equality and considers datasets with different blank node instances to
  /// be unequal even if they represent the same semantic content.
  ///
  /// Parameters:
  /// - [other] The object to compare with this dataset
  ///
  /// Returns:
  /// `true` if the other object is a [CanonicalRdfDataset] with the same
  /// canonical form, `false` otherwise
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is CanonicalRdfDataset &&
        other.canonicalNQuads == canonicalNQuads;
  }

  // Dataset operations - delegated to wrapped instance
  // See RdfDataset documentation for detailed descriptions

  /// Checks if the dataset contains a named graph with the given name
  ///
  /// Delegates to [RdfDataset.containsGraph]. See [RdfDataset] for full documentation.
  bool containsGraph(RdfGraphName name) => _inputDataset.containsGraph(name);

  /// Gets the default graph of this dataset
  ///
  /// Delegates to [RdfDataset.defaultGraph]. See [RdfDataset] for full documentation.
  RdfGraph get defaultGraph => _inputDataset.defaultGraph;

  /// Gets the named graph with the specified name, or null if not found
  ///
  /// Delegates to [RdfDataset.graph]. See [RdfDataset] for full documentation.
  RdfGraph? graph(RdfGraphName name) => _inputDataset.graph(name);

  /// Gets all graph names in this dataset
  ///
  /// Delegates to [RdfDataset.graphNames]. See [RdfDataset] for full documentation.
  Iterable<RdfGraphName> get graphNames => _inputDataset.graphNames;

  /// Gets all named graphs in this dataset
  ///
  /// Delegates to [RdfDataset.namedGraphs]. See [RdfDataset] for full documentation.
  Iterable<RdfNamedGraph> get namedGraphs => _inputDataset.namedGraphs;

  /// Gets all quads (4-tuples) in this dataset
  ///
  /// Delegates to [RdfDataset.quads]. See [RdfDataset] for full documentation.
  Iterable<Quad> get quads => _inputDataset.quads;
}

/// A wrapper around [RdfGraph] that provides semantic equality and hashing
/// based on RDF canonicalization.
///
/// This class implements all the same operations as [RdfGraph] by delegation,
/// but overrides equality and hash code operations to use the canonical
/// serialized form. This ensures that two graphs with the same semantic
/// content but different blank node labels are considered equal.
///
/// The canonical form is computed lazily using the RDF Graph Canonicalization
/// algorithm with exactly-once semantics. The first access to [canonicalNQuads],
/// [hashCode], or [operator ==] will trigger canonicalization; subsequent operations
/// access the cached result with zero overhead.
///
/// ## Key Differences from RdfGraph
///
/// - **Semantic equality**: Two [CanonicalRdfGraph] instances are equal if they
///   represent the same RDF data semantically, even with different blank node labels
/// - **Consistent hashing**: Hash code is computed from the canonical form, ensuring
///   semantically equivalent graphs have the same hash
/// - **Performance trade-off**: First access is expensive due to canonicalization,
///   but subsequent operations have zero overhead and provide true semantic equivalence
///
/// ## When to Use
///
/// Use [CanonicalRdfGraph] when:
/// - You need semantic equality for graphs that may have different blank node labels
/// - You want to use graphs as keys in maps or elements in sets with semantic equality
/// - You're implementing algorithms that require RDF graph isomorphism
///
/// For performance-critical scenarios where syntactic equality is sufficient,
/// use [RdfGraph] directly.
///
/// ## Performance Considerations
///
/// - **First access**: Expensive due to canonicalization computation (exactly once, thread-safe)
/// - **Subsequent access**: Zero overhead - direct field access with no synchronization
/// - **Memory usage**: Additional memory for cached canonical form
/// - **Thread safety**: Fully thread-safe. Concurrent first access will block until
///   computation completes, ensuring exactly-once evaluation. No synchronization overhead
///   on subsequent accesses.
///
/// ## Usage Example
///
/// ```dart
/// import 'package:rdf_core/rdf_core.dart';
/// import 'package:rdf_core/src/canonical/canonical_rdf_dataset.dart';
///
/// // Create graphs with different blank node labels but same structure
/// final graph1 = RdfGraph(triples: [
///   Triple(BlankNodeTerm(), foaf.name, LiteralTerm.string('John'))
/// ]);
/// final graph2 = RdfGraph(triples: [
///   Triple(BlankNodeTerm(), foaf.name, LiteralTerm.string('John'))
/// ]);
///
/// // Syntactic comparison
/// assert(graph1 != graph2); // Different blank node instances
///
/// // Semantic comparison using canonical wrapper
/// final canonical1 = CanonicalRdfGraph(graph1);
/// final canonical2 = CanonicalRdfGraph(graph2);
/// assert(canonical1 == canonical2); // Semantically equivalent
///
/// // Can be used as map keys with semantic equality
/// final Map<CanonicalRdfGraph, String> semanticMap = {
///   canonical1: 'First graph',
///   canonical2: 'Same as first', // Will overwrite due to equality
/// };
/// assert(semanticMap.length == 1);
/// ```
///
/// See [RdfGraph] documentation for detailed information about graph operations,
/// as this class delegates all graph functionality to the wrapped instance.
final class CanonicalRdfGraph {
  /// The wrapped RdfGraph instance that provides the actual graph functionality
  final RdfGraph _inputGraph;

  /// Get the canonical N-Quads serialization of this graph, computed lazily.
  ///
  /// The canonical form is computed using the RDF Graph Canonicalization
  /// algorithm as specified in the W3C RDF-Canon specification. The result
  /// is cached after the first computation for performance.
  ///
  /// This canonical form serves as the basis for [operator ==] and [hashCode]
  /// operations, ensuring that semantically equivalent graphs (those with
  /// the same structure but potentially different blank node labels) have
  /// identical canonical representations.
  ///
  /// Returns:
  /// The canonical N-Quads serialization as a string
  late final String canonicalNQuads = canonicalizeGraph(_inputGraph);

  /// Creates a canonical wrapper around the given graph
  ///
  /// The provided graph is wrapped (not copied) and used for all graph
  /// operations. The canonical form will be computed lazily on first access
  /// to [canonicalNQuads], [hashCode], or [operator ==].
  ///
  /// Parameters:
  /// - [graph] The RDF graph to wrap with canonical equality semantics
  CanonicalRdfGraph(RdfGraph graph) : _inputGraph = graph;

  /// Access the wrapped RdfGraph instance
  ///
  /// This provides access to the underlying graph for operations that
  /// don't require canonical equality semantics or for interoperability
  /// with code expecting [RdfGraph] instances.
  ///
  /// Returns:
  /// The wrapped [RdfGraph] instance
  RdfGraph get asRdfGraph => _inputGraph;

  /// Hash code based on the canonical serialization
  ///
  /// This ensures that semantically equivalent graphs have the same hash code,
  /// making it safe to use [CanonicalRdfGraph] instances as keys in maps or
  /// elements in sets with semantic equality semantics.
  ///
  /// The hash is computed from the canonical N-Quads representation, which
  /// normalizes blank node labels according to the canonicalization algorithm.
  @override
  int get hashCode => canonicalNQuads.hashCode;

  /// Semantic equality based on canonical serialization
  ///
  /// Two [CanonicalRdfGraph] instances are considered equal if their
  /// canonical N-Quads representations are identical. This provides true
  /// semantic equality - graphs with the same RDF structure but different
  /// blank node labels will be considered equal.
  ///
  /// This is in contrast to [RdfGraph.operator ==] which performs syntactic
  /// equality and considers graphs with different blank node instances to
  /// be unequal even if they represent the same semantic content.
  ///
  /// Parameters:
  /// - [other] The object to compare with this graph
  ///
  /// Returns:
  /// `true` if the other object is a [CanonicalRdfGraph] with the same
  /// canonical form, `false` otherwise
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is CanonicalRdfGraph &&
        other.canonicalNQuads == canonicalNQuads;
  }

  // Graph operations - delegated to wrapped instance
  // See RdfGraph documentation for detailed descriptions

  /// Find triples matching the given pattern
  ///
  /// Delegates to [RdfGraph.findTriples]. See [RdfGraph] for full documentation.
  List<Triple> findTriples(
          {RdfSubject? subject, RdfPredicate? predicate, RdfObject? object}) =>
      _inputGraph.findTriples(
          subject: subject, predicate: predicate, object: object);

  /// Get objects for a given subject and predicate
  ///
  /// Delegates to [RdfGraph.getObjects]. See [RdfGraph] for full documentation.
  List<RdfObject> getObjects(RdfSubject subject, RdfPredicate predicate) =>
      _inputGraph.getObjects(subject, predicate);

  /// Get subjects with a given predicate and object
  ///
  /// Delegates to [RdfGraph.getSubjects]. See [RdfGraph] for full documentation.
  List<RdfSubject> getSubjects(RdfPredicate predicate, RdfObject object) =>
      _inputGraph.getSubjects(predicate, object);

  /// Check if graph contains triples matching the given pattern
  ///
  /// Delegates to [RdfGraph.hasTriples]. See [RdfGraph] for full documentation.
  bool hasTriples(
          {RdfSubject? subject, RdfPredicate? predicate, RdfObject? object}) =>
      _inputGraph.hasTriples(
          subject: subject, predicate: predicate, object: object);

  /// Whether indexing is enabled for this graph
  ///
  /// Delegates to [RdfGraph.indexingEnabled]. See [RdfGraph] for full documentation.
  bool get indexingEnabled => _inputGraph.indexingEnabled;

  /// Whether this graph is empty
  ///
  /// Delegates to [RdfGraph.isEmpty]. See [RdfGraph] for full documentation.
  bool get isEmpty => _inputGraph.isEmpty;

  /// Whether this graph is not empty
  ///
  /// Delegates to [RdfGraph.isNotEmpty]. See [RdfGraph] for full documentation.
  bool get isNotEmpty => _inputGraph.isNotEmpty;

  /// Create a new canonical graph containing only matching triples
  ///
  /// Delegates to [RdfGraph.matching]. See [RdfGraph] for full documentation.
  /// Returns a [CanonicalRdfGraph] wrapper around the filtered graph.
  CanonicalRdfGraph matching(
          {RdfSubject? subject, RdfPredicate? predicate, RdfObject? object}) =>
      CanonicalRdfGraph(_inputGraph.matching(
          subject: subject, predicate: predicate, object: object));

  /// Merge this graph with another, returning a new canonical graph
  ///
  /// Delegates to [RdfGraph.merge]. See [RdfGraph] for full documentation.
  /// Returns a [CanonicalRdfGraph] wrapper around the merged graph.
  CanonicalRdfGraph merge(RdfGraph other, {removeDuplicates = true}) =>
      CanonicalRdfGraph(
          _inputGraph.merge(other, removeDuplicates: removeDuplicates));

  /// Get all unique objects in this graph
  ///
  /// Delegates to [RdfGraph.objects]. See [RdfGraph] for full documentation.
  Set<RdfObject> get objects => _inputGraph.objects;

  /// Get all unique predicates in this graph
  ///
  /// Delegates to [RdfGraph.predicates]. See [RdfGraph] for full documentation.
  Set<RdfPredicate> get predicates => _inputGraph.predicates;

  /// Number of triples in this graph
  ///
  /// Delegates to [RdfGraph.size]. See [RdfGraph] for full documentation.
  int get size => _inputGraph.size;

  /// Extract a subgraph starting from a root subject
  ///
  /// Delegates to [RdfGraph.subgraph]. See [RdfGraph] for full documentation.
  /// Returns a [CanonicalRdfGraph] wrapper around the subgraph.
  CanonicalRdfGraph subgraph(RdfSubject root, {TraversalFilter? filter}) =>
      CanonicalRdfGraph(_inputGraph.subgraph(root, filter: filter));

  /// Get all unique subjects in this graph
  ///
  /// Delegates to [RdfGraph.subjects]. See [RdfGraph] for full documentation.
  Set<RdfSubject> get subjects => _inputGraph.subjects;

  /// Get all triples in this graph
  ///
  /// Delegates to [RdfGraph.triples]. See [RdfGraph] for full documentation.
  List<Triple> get triples => _inputGraph.triples;

  /// Create a new canonical graph with modified configuration options
  ///
  /// Delegates to [RdfGraph.withOptions]. See [RdfGraph] for full documentation.
  /// Returns a [CanonicalRdfGraph] wrapper around the reconfigured graph.
  CanonicalRdfGraph withOptions({bool? enableIndexing}) => CanonicalRdfGraph(
      _inputGraph.withOptions(enableIndexing: enableIndexing));

  /// Create a new canonical graph with the specified triple added
  ///
  /// Delegates to [RdfGraph.withTriple]. See [RdfGraph] for full documentation.
  /// Returns a [CanonicalRdfGraph] wrapper around the extended graph.
  CanonicalRdfGraph withTriple(Triple triple) =>
      CanonicalRdfGraph(_inputGraph.withTriple(triple));

  /// Create a new canonical graph with all the specified triples added
  ///
  /// Delegates to [RdfGraph.withTriples]. See [RdfGraph] for full documentation.
  /// Returns a [CanonicalRdfGraph] wrapper around the extended graph.
  CanonicalRdfGraph withTriples(Iterable<Triple> triples,
          {bool removeDuplicates = true}) =>
      CanonicalRdfGraph(
          _inputGraph.withTriples(triples, removeDuplicates: removeDuplicates));

  /// Create a new canonical graph by removing triples from another graph
  ///
  /// Delegates to [RdfGraph.without]. See [RdfGraph] for full documentation.
  /// Returns a [CanonicalRdfGraph] wrapper around the filtered graph.
  CanonicalRdfGraph without(RdfGraph other) =>
      CanonicalRdfGraph(_inputGraph.without(other));

  /// Create a new canonical graph by removing triples that match a pattern
  ///
  /// Delegates to [RdfGraph.withoutMatching]. See [RdfGraph] for full documentation.
  /// Returns a [CanonicalRdfGraph] wrapper around the filtered graph.
  CanonicalRdfGraph withoutMatching(
          {RdfSubject? subject, RdfPredicate? predicate, RdfObject? object}) =>
      CanonicalRdfGraph(_inputGraph.withoutMatching(
          subject: subject, predicate: predicate, object: object));

  /// Create a new canonical graph with the specified triples removed
  ///
  /// Delegates to [RdfGraph.withoutTriples]. See [RdfGraph] for full documentation.
  /// Returns a [CanonicalRdfGraph] wrapper around the filtered graph.
  CanonicalRdfGraph withoutTriples(Iterable<Triple> triples) =>
      CanonicalRdfGraph(_inputGraph.withoutTriples(triples));
}
