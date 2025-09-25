/// RDF Named Graph Implementation
///
/// Defines the [RdfNamedGraph] class for representing named graphs in RDF datasets.
/// A named graph is a fundamental concept in RDF 1.1 that pairs an IRI identifier
/// with an RDF graph, enabling context and provenance tracking in RDF datasets.
///
/// ## Named Graph Concepts
///
/// In RDF datasets, named graphs provide:
/// - **Context identification**: Each graph has a unique IRI name
/// - **Graph isolation**: Triples are grouped by their containing graph
/// - **Provenance tracking**: The graph name can indicate data source or context
/// - **SPARQL compatibility**: Direct support for GRAPH clauses in SPARQL queries
///
/// ## Key Features
///
/// - **Type safety**: Strongly typed pairing of IRI name and graph content
/// - **Immutability**: Both name and graph are final, ensuring data integrity
/// - **Standard compliance**: Follows RDF 1.1 Dataset specification
/// - **API integration**: Seamless integration with RdfDataset operations
///
/// ## Usage Examples
///
/// ### Basic Named Graph Creation
///
/// ```dart
/// // Create a named graph for person data
/// final personGraph = RdfGraph(triples: [
///   Triple(john, foaf.name, LiteralTerm.string("John Doe")),
///   Triple(john, foaf.email, LiteralTerm.string("john@example.org")),
/// ]);
///
/// final namedGraph = RdfNamedGraph(
///   IriTerm('http://example.org/graphs/persons'),
///   personGraph
/// );
/// ```
///
/// ### Integration with Datasets
///
/// ```dart
/// // Create multiple named graphs
/// final peopleGraph = RdfNamedGraph(
///   IriTerm('http://example.org/people'),
///   personData
/// );
///
/// final placesGraph = RdfNamedGraph(
///   IriTerm('http://example.org/places'),
///   locationData
/// );
///
/// // Use in dataset construction
/// final dataset = RdfDataset.withGraphs([peopleGraph, placesGraph]);
/// ```
///
/// ### Accessing Graph Information
///
/// ```dart
/// // Work with named graph properties
/// print('Graph name: ${namedGraph.name.iri}');
/// print('Triple count: ${namedGraph.graph.size}');
/// print('Empty: ${namedGraph.graph.isEmpty}');
///
/// // Extract data from the graph
/// final names = namedGraph.graph.findTriples(predicate: foaf.name);
/// ```
///
/// ## Relationship to RDF Standards
///
/// This implementation aligns with:
/// - [RDF 1.1 Concepts - Named Graphs](https://www.w3.org/TR/rdf11-concepts/#section-dataset)
/// - [RDF 1.1 Semantics - Dataset Interpretation](https://www.w3.org/TR/rdf11-mt/#dfn-dataset-interpretation)
/// - [SPARQL 1.1 - GRAPH keyword](https://www.w3.org/TR/sparql11-query/#namedAndDefaultGraph)
///
/// ## Thread Safety and Immutability
///
/// RdfNamedGraph instances are immutable and thread-safe. Both the name (IRI)
/// and graph content are final, preventing accidental modification after construction.
/// This design ensures data integrity in concurrent environments and functional
/// programming patterns.
library rdf_named_graph;

import 'package:rdf_core/rdf_core.dart';

/// Represents an immutable named graph in an RDF dataset
///
/// A named graph is a pair consisting of:
/// - An IRI that uniquely identifies the graph within a dataset
/// - An RDF graph containing zero or more triples
///
/// This class provides a type-safe way to associate graph names with their
/// content, enabling:
/// - Clear separation of concerns in multi-graph datasets
/// - Provenance and context tracking for RDF data
/// - Support for SPARQL GRAPH operations
/// - Dataset construction and manipulation
///
/// ## Design Principles
///
/// - **Immutability**: Once created, neither name nor graph can be changed
/// - **Type Safety**: Prevents mismatched name-graph associations
/// - **Standard Compliance**: Follows RDF 1.1 specification exactly
/// - **Simplicity**: Minimal interface focused on the essential pairing
///
/// ## Performance Characteristics
///
/// - **Construction**: O(1) - simple field assignment
/// - **Access**: O(1) - direct field access
/// - **Memory**: Minimal overhead beyond the constituent name and graph
///
/// Example:
/// ```dart
/// // Create a named graph for organizational data
/// final orgGraph = RdfGraph(triples: organizationTriples);
/// final namedGraph = RdfNamedGraph(
///   IriTerm('http://example.org/graphs/organization'),
///   orgGraph
/// );
///
/// // Use in dataset operations
/// final dataset = RdfDataset.withGraphs([namedGraph]);
/// final retrievedGraph = dataset.graph(namedGraph.name);
/// assert(retrievedGraph == namedGraph.graph);
/// ```
class RdfNamedGraph {
  /// The IRI name that uniquely identifies this graph within a dataset
  ///
  /// This IRI serves as the unique identifier for the graph within an RDF dataset.
  /// According to RDF 1.1 specification, graph names must be IRIs, ensuring
  /// global uniqueness and enabling distributed RDF data management.
  ///
  /// The name is immutable once set during construction.
  final IriTerm name;

  /// The RDF graph containing the actual triple data
  ///
  /// This is the collection of RDF triples that make up the content of this
  /// named graph. The graph may be empty but is never null.
  ///
  /// The graph is immutable once set during construction, following the
  /// immutability principle of the RDF library.
  final RdfGraph graph;

  /// Creates a new named graph with the specified name and content
  ///
  /// Constructs an immutable named graph by pairing an IRI identifier
  /// with an RDF graph. Both parameters are required as every named
  /// graph must have both a name and content (even if empty).
  ///
  /// Parameters:
  /// - [name] The IRI that uniquely identifies this graph
  /// - [graph] The RDF graph containing the triples for this named graph
  ///
  /// Example:
  /// ```dart
  /// // Create a named graph for user preferences
  /// final prefsGraph = RdfGraph(triples: userPreferenceTriples);
  /// final namedPrefs = RdfNamedGraph(
  ///   IriTerm('http://example.org/users/john/preferences'),
  ///   prefsGraph
  /// );
  /// ```
  RdfNamedGraph(this.name, this.graph);
}
