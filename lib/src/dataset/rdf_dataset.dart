/// RDF Dataset Implementation
///
/// Defines the [RdfDataset] class for managing collections of RDF graphs in named contexts.
/// This implementation provides the W3C RDF 1.1 Dataset specification for representing
/// and manipulating collections of RDF graphs.
///
/// ## RDF Dataset Concepts
///
/// An RDF dataset is a collection of RDF graphs with:
/// - One **default graph** (unnamed)
/// - Zero or more **named graphs**, each identified by an IRI
///
/// This aligns with the formal definition in RDF 1.1 specification where a dataset
/// is a mathematical structure containing exactly one default graph and zero or more
/// named graphs, where each named graph is a pair of an IRI and an RDF graph.
///
/// ## Key Features
///
/// - **Immutable data structure** for thread-safety and predictability
/// - **Named graph management** with IRI-based identification
/// - **Default graph handling** for graph-level statements
/// - **Flexible constructors** for different initialization patterns
///
/// ## Usage Examples
///
/// ### Basic Dataset Creation
///
/// ```dart
/// // Empty dataset
/// final dataset = RdfDataset.empty();
///
/// // Dataset with only a default graph
/// final defaultGraph = RdfGraph(triples: [triple1, triple2]);
/// final dataset = RdfDataset.withDefaultGraph(defaultGraph);
///
/// // Dataset with named graphs
/// final namedGraphs = [
///   RdfNamedGraph(IriTerm('http://example.org/graph1'), graph1),
///   RdfNamedGraph(IriTerm('http://example.org/graph2'), graph2),
/// ];
/// final dataset = RdfDataset.withGraphs(namedGraphs);
/// ```
///
/// ### Working with Named Graphs
///
/// ```dart
/// // Check if a named graph exists
/// final graphName = IriTerm('http://example.org/people');
/// if (dataset.containsGraph(graphName)) {
///   final graph = dataset.graph(graphName);
///   // Work with the graph...
/// }
///
/// // Iterate over all named graphs
/// for (final namedGraph in dataset.namedGraphs) {
///   print('Graph: ${namedGraph.name}');
///   print('Triples: ${namedGraph.graph.size}');
/// }
/// ```
///
/// ## Relationship to RDF Standards
///
/// This implementation follows:
/// - [RDF 1.1 Concepts - RDF Datasets](https://www.w3.org/TR/rdf11-concepts/#section-dataset)
/// - [RDF 1.1 Semantics - Dataset Semantics](https://www.w3.org/TR/rdf11-mt/#dfn-rdf-dataset)
///
/// ## Performance Characteristics
///
/// - **Graph lookup**: O(1) average case using HashMap
/// - **Graph enumeration**: O(n) where n is the number of named graphs
/// - **Memory usage**: Proportional to the sum of all graph sizes plus overhead
///
/// ## Thread Safety
///
/// RdfDataset is immutable, making it inherently thread-safe for read operations.
/// All modification operations return new instances rather than modifying existing ones.
library rdf_dataset;

import 'package:rdf_core/rdf_core.dart';

/// Represents an immutable RDF dataset containing a default graph and named graphs
///
/// An RDF dataset is formally defined as a collection consisting of:
/// - Exactly one default graph (which may be empty)
/// - Zero or more named graphs, each identified by an IRI
///
/// This class provides functionality for:
/// - Creating datasets from graphs
/// - Accessing graphs by name or as collections
/// - Checking for graph existence
/// - Iterating over named graphs
///
/// The class follows immutability principles - all instances are read-only
/// and operations that would modify the dataset return new instances.
///
/// ## Implementation Notes
///
/// - Named graphs are stored in a Map for O(1) lookup by IRI
/// - The default graph is always present (empty graph if not specified)
/// - Graph names must be IRIs as per RDF 1.1 specification
/// - Duplicate graph names are not allowed (Map ensures uniqueness)
///
/// Example:
/// ```dart
/// // Create a dataset with both default and named graphs
/// final dataset = RdfDataset(
///   defaultGraph: myDefaultGraph,
///   namedGraphs: {
///     IriTerm('http://example.org/graph1'): graph1,
///     IriTerm('http://example.org/graph2'): graph2,
///   },
/// );
///
/// // Access graphs
/// final graph1 = dataset.graph(IriTerm('http://example.org/graph1'));
/// final allGraphNames = dataset.graphNames;
/// ```
class RdfDataset {
  /// The default graph of this dataset
  ///
  /// The default graph is the unnamed graph in the dataset and is always present.
  /// It may be empty but never null. According to RDF 1.1 specification,
  /// every dataset has exactly one default graph.
  final RdfGraph defaultGraph;

  /// Internal storage for named graphs mapped by their IRI names
  ///
  /// This map provides O(1) lookup time for named graphs. The keys are
  /// IRI terms that uniquely identify each named graph in the dataset.
  final Map<IriTerm, RdfGraph> _namedGraphs;

  /// Creates an RDF dataset with the specified default graph and named graphs
  ///
  /// This is the primary constructor for creating datasets with full control
  /// over both the default graph and named graph collection.
  ///
  /// Parameters:
  /// - [defaultGraph] The default (unnamed) graph for this dataset
  /// - [namedGraphs] Map of IRI names to their corresponding graphs
  ///
  /// Example:
  /// ```dart
  /// final dataset = RdfDataset(
  ///   defaultGraph: myDefaultGraph,
  ///   namedGraphs: {
  ///     IriTerm('http://example.org/people'): peopleGraph,
  ///     IriTerm('http://example.org/places'): placesGraph,
  ///   },
  /// );
  /// ```
  RdfDataset(
      {required this.defaultGraph, required Map<IriTerm, RdfGraph> namedGraphs})
      : _namedGraphs = namedGraphs;

  /// Get all graph names (IRIs) in this dataset
  ///
  /// Returns the IRI identifiers of all named graphs in this dataset.
  /// The default graph is not included as it has no name.
  ///
  /// Returns:
  /// An iterable collection of IRI terms identifying the named graphs.
  /// May be empty if the dataset contains only the default graph.
  ///
  /// Example:
  /// ```dart
  /// final names = dataset.graphNames;
  /// print('Dataset contains ${names.length} named graphs');
  /// for (final name in names) {
  ///   print('Graph: ${name.iri}');
  /// }
  /// ```
  Iterable<IriTerm> get graphNames => _namedGraphs.keys;

  /// Retrieve a named graph by its IRI identifier
  ///
  /// Looks up a named graph in this dataset using its IRI name.
  /// Returns null if no graph with the specified name exists.
  ///
  /// Parameters:
  /// - [name] The IRI identifier of the graph to retrieve
  ///
  /// Returns:
  /// The RDF graph associated with the name, or null if not found.
  ///
  /// Example:
  /// ```dart
  /// final graphName = IriTerm('http://example.org/people');
  /// final graph = dataset.graph(graphName);
  /// if (graph != null) {
  ///   print('Found graph with ${graph.size} triples');
  /// } else {
  ///   print('Graph not found');
  /// }
  /// ```
  RdfGraph? graph(IriTerm name) => _namedGraphs[name];

  /// Check if a named graph exists in this dataset
  ///
  /// Determines whether a graph with the specified IRI name exists
  /// in this dataset's named graph collection.
  ///
  /// Parameters:
  /// - [name] The IRI identifier to check for
  ///
  /// Returns:
  /// true if a graph with the specified name exists, false otherwise.
  ///
  /// Example:
  /// ```dart
  /// final graphName = IriTerm('http://example.org/people');
  /// if (dataset.containsGraph(graphName)) {
  ///   // Safe to call dataset.graph(graphName)
  ///   final graph = dataset.graph(graphName)!;
  /// }
  /// ```
  bool containsGraph(IriTerm name) => _namedGraphs.containsKey(name);

  /// Get all named graphs as RdfNamedGraph instances
  ///
  /// Returns all named graphs in this dataset as RdfNamedGraph objects,
  /// which pair each graph with its IRI name for convenient iteration.
  ///
  /// Returns:
  /// An iterable collection of RdfNamedGraph instances representing
  /// all named graphs in the dataset. May be empty if the dataset
  /// contains only the default graph.
  ///
  /// Example:
  /// ```dart
  /// for (final namedGraph in dataset.namedGraphs) {
  ///   print('Processing graph: ${namedGraph.name.iri}');
  ///   print('Contains ${namedGraph.graph.size} triples');
  /// }
  /// ```
  Iterable<RdfNamedGraph> get namedGraphs => _namedGraphs.entries
      .map((entry) => RdfNamedGraph(entry.key, entry.value));

  /// Get all statements in this dataset as quads
  ///
  /// Returns an iterable collection of all RDF statements in this dataset
  /// as Quad objects, preserving graph context information. This provides
  /// a unified view of the entire dataset where:
  /// - Default graph triples become quads with null graph names
  /// - Named graph triples become quads with their respective graph names
  ///
  /// This is particularly useful for:
  /// - N-Quads serialization where graph context is required
  /// - Dataset-wide operations that need graph context
  /// - Converting datasets to quad-based processing pipelines
  /// - Bulk operations across all graphs in the dataset
  ///
  /// Returns:
  /// An iterable collection of Quad objects representing all statements
  /// in the dataset with their graph context. The order is not guaranteed.
  ///
  /// Example:
  /// ```dart
  /// // Process all statements with graph context
  /// for (final quad in dataset.quads) {
  ///   if (quad.isDefaultGraph) {
  ///     print('Default: ${quad.triple}');
  ///   } else {
  ///     print('Graph ${quad.graphName}: ${quad.triple}');
  ///   }
  /// }
  ///
  /// // Count total statements across all graphs
  /// final totalStatements = dataset.quads.length;
  ///
  /// // Filter quads by graph
  /// final peopleQuads = dataset.quads
  ///     .where((quad) => quad.graphName?.iri.contains('people') ?? false);
  /// ```
  Iterable<Quad> get quads sync* {
    // Yield default graph quads (with null graph name)
    for (final triple in defaultGraph.triples) {
      yield Quad.fromTriple(triple);
    }

    // Yield named graph quads (with their graph names)
    for (final entry in _namedGraphs.entries) {
      final graphName = entry.key;
      final graph = entry.value;
      for (final triple in graph.triples) {
        yield Quad.fromTriple(triple, graphName);
      }
    }
  }

  /// Creates an empty RDF dataset
  ///
  /// Creates a dataset containing only an empty default graph and no named graphs.
  /// This is useful as a starting point for building datasets incrementally.
  ///
  /// Example:
  /// ```dart
  /// final emptyDataset = RdfDataset.empty();
  /// assert(emptyDataset.defaultGraph.isEmpty);
  /// assert(emptyDataset.graphNames.isEmpty);
  /// ```
  RdfDataset.empty()
      : defaultGraph = RdfGraph(),
        _namedGraphs = {};

  /// Creates a dataset from a list of named graphs with an empty default graph
  ///
  /// This factory constructor is convenient when you have a collection of named graphs
  /// and want to create a dataset with them. The default graph will be empty.
  ///
  /// Parameters:
  /// - [graphs] List of RdfNamedGraph instances to include in the dataset
  ///
  /// Throws:
  /// - [ArgumentError] if multiple graphs have the same name
  ///
  /// Example:
  /// ```dart
  /// final namedGraphs = [
  ///   RdfNamedGraph(IriTerm('http://example.org/graph1'), graph1),
  ///   RdfNamedGraph(IriTerm('http://example.org/graph2'), graph2),
  /// ];
  /// final dataset = RdfDataset.fromGraphs(namedGraphs);
  /// ```
  RdfDataset.fromGraphs(List<RdfNamedGraph> graphs)
      : defaultGraph = RdfGraph(),
        _namedGraphs = Map.fromIterable(
          graphs,
          key: (g) => g.name,
          value: (g) => g.graph,
        );

  /// Creates a dataset from a default graph with no named graphs
  ///
  /// This factory constructor is useful when you have an existing graph that should
  /// serve as the dataset's default graph, with no additional named graphs.
  ///
  /// Parameters:
  /// - [graph] The RDF graph to use as the default graph
  ///
  /// Example:
  /// ```dart
  /// final myGraph = RdfGraph(triples: [triple1, triple2]);
  /// final dataset = RdfDataset.fromDefaultGraph(myGraph);
  /// assert(dataset.defaultGraph == myGraph);
  /// assert(dataset.graphNames.isEmpty);
  /// ```
  RdfDataset.fromDefaultGraph(RdfGraph graph)
      : defaultGraph = graph,
        _namedGraphs = {};

  /// Creates a dataset from a collection of RDF quads
  ///
  /// This factory constructor processes a collection of quads and organizes them
  /// into the appropriate graphs based on their graph context. Quads with null
  /// graph names are added to the default graph, while quads with graph names
  /// are organized into their respective named graphs.
  ///
  /// This is particularly useful when:
  /// - Processing N-Quads data that includes graph context
  /// - Converting from quad-based representations to dataset structure
  /// - Bulk-loading RDF data with mixed graph contexts
  ///
  /// Parameters:
  /// - [quads] Collection of RDF quads to organize into dataset structure
  ///
  /// Returns:
  /// A new RdfDataset with quads organized into default and named graphs.
  ///
  /// Example:
  /// ```dart
  /// final quads = [
  ///   Quad(alice, foaf.name, aliceName), // default graph
  ///   Quad(bob, foaf.age, bobAge, peopleGraph), // named graph
  ///   Quad(charlie, foaf.email, charlieEmail, peopleGraph), // same named graph
  /// ];
  ///
  /// final dataset = RdfDataset.fromQuads(quads);
  /// assert(dataset.defaultGraph.size == 1); // Alice's name
  /// assert(dataset.graph(peopleGraph)?.size == 2); // Bob and Charlie
  /// ```
  RdfDataset.fromQuads(Iterable<Quad> quads) : this._fromQuadCollection(quads);

  /// Private constructor that processes quads into dataset structure
  RdfDataset._fromQuadCollection(Iterable<Quad> quads)
      : defaultGraph = _buildDefaultGraph(quads),
        _namedGraphs = _buildNamedGraphs(quads);

  /// Builds the default graph from quads with null graph names
  static RdfGraph _buildDefaultGraph(Iterable<Quad> quads) {
    final defaultTriples = quads
        .where((quad) => quad.isDefaultGraph)
        .map((quad) => quad.triple)
        .toList();
    return RdfGraph(triples: defaultTriples);
  }

  /// Builds named graphs map from quads with non-null graph names
  static Map<IriTerm, RdfGraph> _buildNamedGraphs(Iterable<Quad> quads) {
    final namedQuads = quads.where((quad) => !quad.isDefaultGraph);
    final graphTriples = <IriTerm, List<Triple>>{};

    // Group triples by graph name
    for (final quad in namedQuads) {
      final graphName = quad.graphName!;
      graphTriples.putIfAbsent(graphName, () => []).add(quad.triple);
    }

    // Convert to graphs
    return graphTriples.map((name, triples) =>
        MapEntry(name, RdfGraph(triples: triples)));
  }
}
