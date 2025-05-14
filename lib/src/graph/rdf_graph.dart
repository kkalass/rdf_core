/// RDF Graph Implementation
///
/// Defines the [RdfGraph] class for managing collections of RDF triples and related utilities.
/// This implementation provides an immutable graph model that follows the W3C RDF 1.1 specification
/// for representing and manipulating RDF data.
///
/// Key features:
/// - Immutable data structure for thread-safety and predictability
/// - Triple pattern matching for querying data
/// - Graph merge operations for combining datasets
/// - Convenient methods for property lookup and resource identification
///
/// Example usage:
/// ```dart
/// import 'package:rdf_core/rdf_core.dart';
///
/// // Create a graph with initial triples
/// final graph = RdfGraph(triples: [
///   Triple(john, name, LiteralTerm.string("John Smith")),
///   Triple(john, knows, jane)
/// ]);
///
/// // Advanced: merging two graphs
/// final merged = graph.merge(otherGraph);
///
/// // Pattern query: find all triples with a specific subject
/// final matches = graph.findTriples(subject: john);
///
/// // Blank node handling: add a triple with a blank node subject
/// final blankNode = BlankNodeTerm();
/// final newGraph = graph.withTriple(Triple(blankNode, predicate, object));
/// ```
///
/// Performance considerations:
/// - [RdfGraph.findTriples] is O(n) in the number of triples.
/// - [RdfGraph.merge] creates a new graph and is O(n + m) where n and m are
///   the number of triples in each graph.
/// - All operations maintain immutability, creating new graph instances.
///
/// Error handling:
/// - Adding invalid triples will throw [ArgumentError].
/// - Querying with nulls is supported for wildcards in pattern matching.
///
/// Related specifications:
/// - [RDF 1.1 Concepts - Graphs](https://www.w3.org/TR/rdf11-concepts/#section-rdf-graph)
/// - [RDF 1.1 Semantics - Graph Definitions](https://www.w3.org/TR/rdf11-mt/#dfn-rdf-graph)
library rdf_graph;

import 'package:rdf_core/src/graph/rdf_term.dart';
import 'package:rdf_core/src/graph/triple.dart';

/// Represents an immutable RDF graph with triple pattern matching capabilities
///
/// An RDF graph is formally defined as a set of RDF triples. This class provides
/// functionality for working with such graphs, including:
/// - Creating graphs from sets of triples
/// - Adding or removing triples (creating new graph instances)
/// - Merging graphs
/// - Querying triples based on patterns
///
/// The class is designed to be immutable for thread safety and to prevent
/// accidental modification. All operations that would modify the graph
/// return a new instance.
///
/// Example:
/// ```dart
/// // Create a graph with some initial triples
/// final graph = RdfGraph(triples: [
///   Triple(john, name, johnSmith),
///   Triple(john, knows, jane)
/// ]);
///
/// // Create a new graph with an additional triple
/// final updatedGraph = graph.withTriple(Triple(jane, name, janeSmith));
/// ```
final class RdfGraph {
  /// All triples in this graph
  final List<Triple> _triples;

  /// Creates an immutable RDF graph from a list of triples
  ///
  /// The constructor makes a defensive copy of the provided triples list
  /// to ensure immutability. The graph can be initialized with an empty
  /// list to create an empty graph.
  ///
  /// Example:
  /// ```dart
  /// // Empty graph
  /// final emptyGraph = RdfGraph();
  ///
  /// // Graph with initial triples
  /// final graph = RdfGraph(triples: myTriples);
  /// ```
  RdfGraph({List<Triple> triples = const []})
    : _triples = List.unmodifiable(List.from(triples));

  /// Creates an RDF graph from a list of triples (factory constructor)
  ///
  /// This is a convenience factory method equivalent to the default constructor.
  ///
  /// Example:
  /// ```dart
  /// final graph = RdfGraph.fromTriples(myTriples);
  /// ```
  static RdfGraph fromTriples(List<Triple> triples) =>
      RdfGraph(triples: triples);

  /// Creates a new graph with the specified triple added
  ///
  /// Since RdfGraph is immutable, this returns a new instance with
  /// all the existing triples plus the new one. The original graph
  /// remains unchanged.
  ///
  /// Parameters:
  /// - [triple] The triple to add to the graph
  ///
  /// Returns:
  /// A new graph instance with the added triple
  ///
  /// Example:
  /// ```dart
  /// // Add a statement that John has email john@example.com
  /// final newGraph = graph.withTriple(
  ///   Triple(john, email, LiteralTerm.string('john@example.com'))
  /// );
  /// ```
  RdfGraph withTriple(Triple triple) {
    final newTriples = List<Triple>.from(_triples)..add(triple);
    return RdfGraph(triples: newTriples);
  }

  /// Creates a new graph with all the specified triples added
  ///
  /// Since RdfGraph is immutable, this returns a new instance with
  /// all existing and new triples. The original graph remains unchanged.
  ///
  /// Parameters:
  /// - [triples] The list of triples to add to the graph
  ///
  /// Returns:
  /// A new graph instance with the added triples
  ///
  /// Example:
  /// ```dart
  /// // Add multiple statements about Jane
  /// final newGraph = graph.withTriples([
  ///   Triple(jane, email, LiteralTerm.string('jane@example.com')),
  ///   Triple(jane, age, LiteralTerm.integer(28))
  /// ]);
  /// ```
  RdfGraph withTriples(List<Triple> triples) {
    final newTriples = List<Triple>.from(_triples)..addAll(triples);
    return RdfGraph(triples: newTriples);
  }

  /// Creates a new graph by filtering out triples that match a pattern
  ///
  /// This method removes triples that match the specified pattern components.
  /// If multiple pattern components are provided, they are treated as an OR condition
  /// (i.e., if any of them match, the triple is removed).
  ///
  /// Parameters:
  /// - [subject] Optional subject to match for removal
  /// - [predicate] Optional predicate to match for removal
  /// - [object] Optional object to match for removal
  ///
  /// Returns:
  /// A new graph instance with matching triples removed
  ///
  /// Example:
  /// ```dart
  /// // Remove all triples about Jane
  /// final withoutJane = graph.withoutMatching(subject: jane);
  ///
  /// // Remove all name and email triples
  /// final withoutContactInfo = graph.withoutMatching(
  ///   predicate: name,
  ///   object: email
  /// );
  /// ```
  RdfGraph withoutMatching({
    RdfSubject? subject,
    RdfPredicate? predicate,
    RdfObject? object,
  }) {
    final filteredTriples =
        _triples.where((triple) {
          if (subject != null && triple.subject == subject) return false;
          if (predicate != null && triple.predicate == predicate) return false;
          if (object != null && triple.object == object) return false;
          return true;
        }).toList();

    return RdfGraph(triples: filteredTriples);
  }

  /// Find all triples matching the given pattern
  ///
  /// This method returns triples that match all the specified pattern components.
  /// Unlike withoutMatching, this method uses AND logic - all specified components
  /// must match. If a pattern component is null, it acts as a wildcard.
  ///
  /// Parameters:
  /// - [subject] Optional subject to match
  /// - [predicate] Optional predicate to match
  /// - [object] Optional object to match
  ///
  /// Returns:
  /// List of matching triples as an unmodifiable collection. The list may be
  /// empty if no matching triples exist.
  ///
  /// Example:
  /// ```dart
  /// // Find all statements about John
  /// final johnsTriples = graph.findTriples(subject: john);
  ///
  /// // Find all name statements
  /// final nameTriples = graph.findTriples(predicate: name);
  ///
  /// // Find John's name specifically
  /// final johnsName = graph.findTriples(subject: john, predicate: name);
  /// ```
  List<Triple> findTriples({
    RdfSubject? subject,
    RdfPredicate? predicate,
    RdfObject? object,
  }) {
    return List.unmodifiable(
      _triples.where((triple) {
        if (subject != null && triple.subject != subject) return false;
        if (predicate != null && triple.predicate != predicate) return false;
        if (object != null && triple.object != object) return false;
        return true;
      }),
    );
  }

  /// Get all objects for a given subject and predicate
  ///
  /// This is a convenience method when you're looking for the value(s)
  /// of a particular property for a resource. It returns all objects from
  /// triples where the subject and predicate match the specified values.
  ///
  /// In RDF terms, this retrieves all values for a particular property
  /// of a resource, which is a common operation in semantic data processing.
  ///
  /// Parameters:
  /// - [subject] The subject resource to query properties for
  /// - [predicate] The property (predicate) to retrieve values of
  ///
  /// Returns:
  /// An unmodifiable list of all object values that match the pattern.
  /// The list may be empty if no matching triples exist.
  ///
  /// Example:
  /// ```dart
  /// // Get all John's email addresses
  /// final johnEmails = graph.getObjects(john, email);
  ///
  /// // Get all of John's known associates
  /// final johnsContacts = graph.getObjects(john, knows);
  ///
  /// // Check if John has any type information
  /// final types = graph.getObjects(john, rdf.type);
  /// ```
  List<RdfObject> getObjects(RdfSubject subject, RdfPredicate predicate) {
    return List.unmodifiable(
      findTriples(
        subject: subject,
        predicate: predicate,
      ).map((triple) => triple.object),
    );
  }

  /// Get all subjects with a given predicate and object
  ///
  /// This is a convenience method for "reverse lookups" - finding resources
  /// that have a particular property value. It returns all subjects from
  /// triples where the predicate and object match the specified values.
  ///
  /// In RDF terms, this retrieves all resources that have a specific property
  /// with a specific value, which is useful for finding resources by attribute.
  ///
  /// Parameters:
  /// - [predicate] The property (predicate) to search by
  /// - [object] The value that matching resources must have for the property
  ///
  /// Returns:
  /// An unmodifiable list of all subject resources that match the pattern.
  /// The list may be empty if no matching triples exist.
  ///
  /// Example:
  /// ```dart
  /// // Find all people who know Jane
  /// final peopleWhoKnowJane = graph.getSubjects(knows, jane);
  ///
  /// // Find all resources of type Person
  /// final allPersons = graph.getSubjects(rdf.type, foaf.Person);
  ///
  /// // Find resources with a specific email address
  /// final resourcesWithEmail = graph.getSubjects(email, LiteralTerm.string('john@example.com'));
  /// ```
  List<RdfSubject> getSubjects(RdfPredicate predicate, RdfObject object) {
    return List.unmodifiable(
      findTriples(
        predicate: predicate,
        object: object,
      ).map((triple) => triple.subject),
    );
  }

  /// Merges this graph with another, producing a new graph
  ///
  /// This creates a union of the two graphs, combining all their triples.
  /// If both graphs contain the same triple, it will appear only once in
  /// the result (since RDF graphs are sets).
  ///
  /// Parameters:
  /// - [other] The graph to merge with this one
  ///
  /// Returns:
  /// A new graph containing all triples from both graphs
  ///
  /// Example:
  /// ```dart
  /// // Merge two graphs to combine their information
  /// final combinedGraph = personGraph.merge(addressGraph);
  /// ```
  RdfGraph merge(RdfGraph other) {
    return withTriples(other._triples);
  }

  /// Get all triples in the graph
  ///
  /// Returns an unmodifiable view of all triples in the graph.
  ///
  /// This property provides direct access to the underlying triples,
  /// which may be useful for external processing or iteration.
  ///
  /// Returns:
  /// An unmodifiable list of all triples in the graph
  List<Triple> get triples => _triples;

  /// Number of triples in this graph
  ///
  /// Provides the count of triples contained in this graph.
  /// This is equivalent to `graph.triples.length`.
  int get size => _triples.length;

  /// Whether this graph contains any triples
  ///
  /// Returns true if the graph contains no triples.
  /// This is equivalent to `graph.triples.isEmpty`.
  bool get isEmpty => _triples.isEmpty;

  /// Whether this graph contains at least one triple
  ///
  /// Returns true if the graph contains at least one triple.
  /// This is equivalent to `graph.triples.isNotEmpty`.
  bool get isNotEmpty => _triples.isNotEmpty;

  /// We are implementing equals ourselves instead of using equatable,
  /// because we want to compare the sets of triples, not the order
  ///
  /// Compares this graph to another object for equality.
  /// Two RDF graphs are equal if they contain the same set of triples,
  /// regardless of the order in which they were added.
  ///
  /// This implementation treats RDF graphs as sets rather than lists,
  /// which aligns with the semantic definition of RDF graphs in the specification.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! RdfGraph) return false;

    // Compare triple sets (order doesn't matter in RDF graphs)
    final Set<Triple> thisTriples = _triples.toSet();
    final Set<Triple> otherTriples = other._triples.toSet();
    return thisTriples.length == otherTriples.length &&
        thisTriples.containsAll(otherTriples);
  }

  /// Provides a consistent hash code for this graph based on its triples.
  ///
  /// The hash code is order-independent to match the equality implementation,
  /// ensuring that two graphs with the same triples in different orders
  /// will have the same hash code.
  @override
  int get hashCode => Object.hashAllUnordered(_triples);
}
