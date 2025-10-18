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
/// - [RdfGraph.findTriples] is O(n) without indexing, O(1) for subject-based queries with indexing.
/// - Indexing is lazy - creating a graph with indexing enabled has no immediate memory cost.
///   The index is only built when first needed during a query operation.
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

/// Decision for traversal control during subgraph extraction
enum TraversalDecision {
  /// Include this triple and continue traversing from its object
  include,

  /// Skip this triple entirely and do not descend from its object
  skip,

  /// Skip this triple but do descend from its object. This breaks
  /// graph connectivity but can be useful to select specific triples, e.g.
  /// for finding specific list elements
  skipButDescend,

  /// Include this triple but do not descend from its object
  includeButDontDescend,
}

/// Function type for controlling subgraph traversal
///
/// This function is called for each triple encountered during subgraph traversal
/// to determine whether the triple should be included and whether traversal
/// should continue from its object.
///
/// Parameters:
/// - [triple] The current triple being evaluated
/// - [depth] The current traversal depth (root subject is at depth 0)
///
/// Returns:
/// A [TraversalDecision] indicating how to handle this triple
typedef TraversalFilter = TraversalDecision Function(Triple triple, int depth);

/// Represents an immutable RDF graph with triple pattern matching capabilities
///
/// An RDF graph is formally defined as a set of RDF triples. This class provides
/// functionality for working with such graphs, including:
/// - Creating graphs from sets of triples
/// - Adding or removing triples (creating new graph instances)
/// - Merging graphs
/// - Querying triples based on patterns
/// - Optional lazy indexing for improved query performance
///
/// The class is designed to be immutable for thread safety and to prevent
/// accidental modification. All operations that would modify the graph
/// return a new instance.
///
/// **Indexing Behavior:** When indexing is enabled (default), an internal
/// index is created lazily on the first query operation that can benefit from it.
/// This means there is no immediate memory cost for enabling indexing - the
/// memory is only used when and if queries are performed.
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
  final bool indexingEnabled;
  Map<RdfSubject, Map<RdfPredicate, List<Triple>>>? _index;

  /// Creates an immutable RDF graph from a list of triples
  ///
  /// The constructor makes a defensive copy of the provided triples list
  /// to ensure immutability. The graph can be initialized with an empty
  /// list to create an empty graph.
  ///
  /// Parameters:
  /// - [triples] The initial collection of triples to include in the graph.
  ///   Defaults to an empty collection.
  /// - [enableIndexing] Whether to enable lazy indexing for query optimization.
  ///   When enabled, an internal index is created lazily on first query to improve
  ///   performance for subsequent pattern matching operations. The index is only
  ///   built when actually needed, so enabling this option has no immediate
  ///   memory cost. Defaults to true.
  ///
  /// Example:
  /// ```dart
  /// // Empty graph with indexing enabled (default)
  /// final emptyGraph = RdfGraph();
  ///
  /// // Graph with initial triples and indexing disabled
  /// final graph = RdfGraph(triples: myTriples, enableIndexing: false);
  /// ```
  RdfGraph({Iterable<Triple> triples = const [], bool enableIndexing = true})
      : _triples = List.unmodifiable(triples),
        indexingEnabled = enableIndexing;

  /// Private constructor for creating graphs with pre-built indexes
  ///
  /// This constructor allows for efficient creation of filtered graphs
  /// by reusing parts of existing indexes when possible.
  RdfGraph._withIndex(
    Iterable<Triple> triples,
    Map<RdfSubject, Map<RdfPredicate, List<Triple>>>? index,
    bool enableIndexing,
  )   : _triples = List.unmodifiable(triples),
        indexingEnabled = enableIndexing,
        _index = index;

  /// Creates an RDF graph from a list of triples (factory constructor)
  ///
  /// This is a convenience factory method equivalent to the default constructor.
  ///
  /// Parameters:
  /// - [triples] The collection of triples to include in the graph.
  /// - [enableIndexing] Whether to enable lazy indexing for query optimization.
  ///   When enabled, an internal index is created lazily on first query to improve
  ///   performance. The index is only built when needed, so enabling this option
  ///   has no immediate memory cost. Defaults to true.
  ///
  /// Example:
  /// ```dart
  /// final graph = RdfGraph.fromTriples(myTriples);
  /// final unindexedGraph = RdfGraph.fromTriples(myTriples, enableIndexing: false);
  /// ```
  static RdfGraph fromTriples(Iterable<Triple> triples,
          {bool enableIndexing = true}) =>
      RdfGraph(triples: triples, enableIndexing: enableIndexing);

  /// Creates a new graph with modified configuration options
  ///
  /// This method allows you to create a copy of the graph with different
  /// configuration settings while preserving all the triples. This provides
  /// a way to adjust graph behavior without recreating the entire dataset.
  ///
  /// If the specified options are the same as the current graph's settings,
  /// returns the same instance for efficiency.
  ///
  /// Parameters:
  /// - [enableIndexing] Whether to enable lazy internal indexing for query optimization.
  ///   When enabled, an internal index is created lazily on first query to improve
  ///   performance for subsequent pattern matching operations. The index is only
  ///   built when actually needed, so enabling this option has no immediate memory cost.
  ///   If null, uses the current setting.
  ///
  /// Returns:
  /// A graph instance with the specified configuration options. May return the same
  /// instance if no changes are needed.
  ///
  /// Example:
  /// ```dart
  /// // Enable indexing for better query performance
  /// final optimizedGraph = graph.withOptions(enableIndexing: true);
  ///
  /// // Disable indexing to reduce memory usage
  /// final lightweightGraph = graph.withOptions(enableIndexing: false);
  /// ```
  RdfGraph withOptions({bool? enableIndexing}) {
    final effectiveIndexing = enableIndexing ?? indexingEnabled;
    if (effectiveIndexing == indexingEnabled) {
      return this;
    }
    return RdfGraph(triples: _triples, enableIndexing: effectiveIndexing);
  }

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
    return RdfGraph(triples: newTriples, enableIndexing: indexingEnabled);
  }

  /// Creates a new graph with all the specified triples added
  ///
  /// Since RdfGraph is immutable, this returns a new instance with
  /// all existing and new triples. The original graph remains unchanged.
  ///
  /// This method automatically removes duplicate triples, treating the graph
  /// as a mathematical set. The order of triples in the resulting graph is
  /// not guaranteed to be preserved from either the original graph or the
  /// added triples collection.
  ///
  /// Parameters:
  /// - [triples] The collection of triples to add to the graph
  ///
  /// Returns:
  /// A new graph instance with the added triples, duplicates removed,
  /// and no guaranteed ordering
  ///
  /// Example:
  /// ```dart
  /// // Add multiple statements about Jane
  /// final newGraph = graph.withTriples([
  ///   Triple(jane, email, LiteralTerm.string('jane@example.com')),
  ///   Triple(jane, age, LiteralTerm.integer(28))
  /// ]);
  ///
  /// // Duplicate triples are automatically removed
  /// final graphWithDuplicates = graph.withTriples([existingTriple, newTriple]);
  /// // Result contains each unique triple only once
  /// ```
  RdfGraph withTriples(Iterable<Triple> triples,
      {bool removeDuplicates = true}) {
    final newTriples = removeDuplicates
        ? {..._triples, ...triples}.toList()
        : (List<Triple>.from(_triples)..addAll(triples));

    return RdfGraph(triples: newTriples, enableIndexing: indexingEnabled);
  }

  /// Creates a new graph with the specified triples removed
  ///
  /// Since RdfGraph is immutable, this returns a new instance with
  /// all existing triples except those specified for removal. The original
  /// graph remains unchanged.
  ///
  /// This method performs set subtraction - it removes all triples that
  /// exactly match those in the provided collection. Triple matching is
  /// based on exact equality of subject, predicate, and object components.
  ///
  /// Parameters:
  /// - [triples] The collection of triples to remove from the graph
  ///
  /// Returns:
  /// A new graph instance with the specified triples removed. If none of the
  /// specified triples exist in the original graph, returns a new graph
  /// identical to the original.
  ///
  /// Example:
  /// ```dart
  /// // Remove multiple outdated statements about John
  /// final updatedGraph = graph.withoutTriples([
  ///   Triple(john, email, LiteralTerm.string('old@example.com')),
  ///   Triple(john, age, LiteralTerm.integer(25))
  /// ]);
  ///
  /// // Remove all triples from a temporary working set
  /// final cleanGraph = graph.withoutTriples(temporaryTriples);
  /// ```
  RdfGraph withoutTriples(Iterable<Triple> triples) {
    final newTriples = {..._triples}
      ..removeWhere((triple) => triples.contains(triple));
    return RdfGraph(
        triples: newTriples.toList(), enableIndexing: indexingEnabled);
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
    final filteredTriples = _triples.where((triple) {
      if (subject != null && triple.subject == subject) return false;
      if (predicate != null && triple.predicate == predicate) return false;
      if (object != null && triple.object == object) return false;
      return true;
    }).toList();

    return RdfGraph(triples: filteredTriples, enableIndexing: indexingEnabled);
  }

  /// Gets the internal index structure for efficient querying
  ///
  /// This private method builds and caches an index that maps subjects to
  /// predicates to lists of triples. The index is only built if indexing
  /// is enabled for this graph instance.
  ///
  /// **Lazy Creation:** The index is created lazily - it is only built when
  /// this method is first called during a query operation. Simply creating
  /// an RdfGraph with indexing enabled has no memory cost until the first
  /// query that uses the index.
  ///
  /// The index structure is: `Map<Subject, Map<Predicate, List<Triple>>>`
  /// This allows O(1) lookup of triples by subject and predicate combination.
  ///
  /// Returns:
  /// The index map if indexing is enabled, null otherwise. The index is
  /// lazily computed and cached on first access.
  Map<RdfSubject, Map<RdfPredicate, List<Triple>>>? get _effectiveIndex {
    if (!indexingEnabled) {
      return null;
    }
    if (_index != null) {
      return _index;
    }
    final index = _triples.fold(<RdfSubject, Map<RdfPredicate, List<Triple>>>{},
        (r, triple) {
      r[triple.subject] ??= <RdfPredicate, List<Triple>>{};
      r[triple.subject]![triple.predicate] ??= <Triple>[];
      r[triple.subject]![triple.predicate]!.add(triple);
      return r;
    });
    _index = index;
    return index;
  }

  /// Get all unique subjects in this graph
  ///
  /// Returns a set containing all subject resources that appear as the subject
  /// component of any triple in this graph. The result is computed efficiently
  /// using the internal index if available and indexing is enabled.
  ///
  /// **Performance:** If indexing is enabled, the first call to this method
  /// may trigger lazy creation of the internal index. Subsequent calls will
  /// use the cached index for O(1) performance.
  ///
  /// Returns:
  /// An unmodifiable set of all subjects in the graph. The set may be empty
  /// if the graph contains no triples.
  ///
  /// Example:
  /// ```dart
  /// // Find all resources that are subjects of statements
  /// final allSubjects = graph.subjects;
  /// print('Graph contains information about ${allSubjects.length} resources');
  /// ```
  Set<RdfSubject> get subjects => switch (_effectiveIndex) {
        null => _triples.map((triple) => triple.subject).toSet(),
        final index => index.keys.toSet(),
      };

  /// Get all unique predicates (properties) in this graph
  ///
  /// Returns a set containing all predicate resources that appear as the predicate
  /// component of any triple in this graph. The result is computed efficiently
  /// using the internal index if available and indexing is enabled.
  ///
  /// **Performance:** If indexing is enabled, the first call to this method
  /// may trigger lazy creation of the internal index. Subsequent calls will
  /// use the cached index for improved performance.
  ///
  /// Returns:
  /// An unmodifiable set of all predicates in the graph. The set may be empty
  /// if the graph contains no triples.
  ///
  /// Example:
  /// ```dart
  /// // Find all properties used in the graph
  /// final allProperties = graph.predicates;
  /// print('Graph uses ${allProperties.length} different properties');
  /// ```
  Set<RdfPredicate> get predicates => switch (_effectiveIndex) {
        null => _triples.map((triple) => triple.predicate).toSet(),
        final index =>
          index.values.expand((predicateMap) => predicateMap.keys).toSet(),
      };

  /// Get all unique objects (values) in this graph
  ///
  /// Returns a set containing all object resources and literals that appear as the
  /// object component of any triple in this graph. This includes both IRI resources
  /// and literal values.
  ///
  /// Returns:
  /// An unmodifiable set of all objects in the graph. The set may be empty
  /// if the graph contains no triples.
  ///
  /// Example:
  /// ```dart
  /// // Find all values used in the graph
  /// final allValues = graph.objects;
  /// print('Graph contains ${allValues.length} different values');
  ///
  /// // Filter for literal values only
  /// final literals = allValues.whereType<LiteralTerm>();
  /// print('Found ${literals.length} literal values');
  /// ```
  Set<RdfObject> get objects => _triples.map((triple) => triple.object).toSet();

  /// Find all triples matching the given pattern
  ///
  /// This method returns triples that match all the specified pattern components.
  /// Unlike withoutMatching, this method uses AND logic - all specified components
  /// must match. If a pattern component is null, it acts as a wildcard.
  ///
  /// **Set-based Queries:** The `*In` parameters allow efficient querying for
  /// triples that match any value in a set. When multiple values are provided
  /// via these parameters, the method returns triples matching ANY of those values
  /// (OR logic within the set), while different parameter types still use AND logic.
  ///
  /// **Performance:** When [subjectIn] is used with indexing enabled, this method
  /// leverages the internal index structure for optimal performance, especially
  /// beneficial when querying for multiple subjects.
  ///
  /// Parameters:
  /// - [subject] Optional subject to match (exact match)
  /// - [subjectIn] Optional set of subjects - matches triples with ANY of these subjects
  /// - [predicate] Optional predicate to match (exact match)
  /// - [predicateIn] Optional set of predicates - matches triples with ANY of these predicates
  /// - [object] Optional object to match (exact match)
  /// - [objectIn] Optional set of objects - matches triples with ANY of these objects
  ///
  /// Note: If both [subject] and [subjectIn] are provided, they are combined.
  /// The same applies to predicate/predicateIn and object/objectIn pairs.
  /// Empty sets in `*In` parameters will match nothing.
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
  ///
  /// // Find statements about John OR Jane (set-based query)
  /// final multipleSubjects = graph.findTriples(subjectIn: [john, jane]);
  ///
  /// // Find name OR email properties (set-based query)
  /// final contactInfo = graph.findTriples(predicateIn: [name, email]);
  ///
  /// // Combine set-based and exact match filters
  /// final johnOrJaneName = graph.findTriples(
  ///   subjectIn: [john, jane],
  ///   predicate: name,
  /// );
  ///
  /// // Complex query with multiple sets
  /// final results = graph.findTriples(
  ///   subjectIn: [john, jane, bob],
  ///   predicateIn: [name, email],
  ///   objectIn: [targetValue1, targetValue2],
  /// );
  /// ```
  List<Triple> findTriples({
    RdfSubject? subject,
    Iterable<RdfSubject>? subjectIn,
    RdfPredicate? predicate,
    Iterable<RdfPredicate>? predicateIn,
    RdfObject? object,
    Iterable<RdfObject>? objectIn,
  }) {
    final subjectSet = (subject != null || subjectIn != null)
        ? {if (subject != null) subject, ...?subjectIn}
        : null;

    final predicateSet = (predicate != null || predicateIn != null)
        ? {if (predicate != null) predicate, ...?predicateIn}
        : null;

    final objectSet = (object != null || objectIn != null)
        ? {if (object != null) object, ...?objectIn}
        : null;

    if (subjectSet != null && _effectiveIndex != null) {
      final index = _effectiveIndex!;
      // If subjectSet is empty, the for loop simply won't run, correctly returning [].
      final List<Triple> results = [];
      for (final s in subjectSet) {
        final subjectMap = index[s];
        if (subjectMap == null) continue;

        final Iterable<Triple> candidates;
        if (predicateSet != null) {
          // If predicateSet is empty, this correctly produces no candidates.
          candidates = predicateSet
              .map((p) => subjectMap[p])
              .nonNulls
              .expand((list) => list);
        } else {
          candidates = subjectMap.values.expand((list) => list);
        }

        if (objectSet != null) {
          // If objectSet is empty, .where() will correctly filter everything out.
          results.addAll(
              candidates.where((triple) => objectSet.contains(triple.object)));
        } else {
          results.addAll(candidates);
        }
      }
      return List.unmodifiable(results);
    }

    return List.unmodifiable(
      _triples.where(
          (triple) => _matches(triple, subjectSet, predicateSet, objectSet)),
    );
  }

  bool _matches(Triple triple, Set<RdfSubject>? subjectIn,
      Set<RdfPredicate>? predicateIn, Set<RdfObject>? objectIn) {
    if (subjectIn != null && !subjectIn.contains(triple.subject)) {
      return false;
    }
    if (predicateIn != null && !predicateIn.contains(triple.predicate)) {
      return false;
    }
    if (objectIn != null && !objectIn.contains(triple.object)) {
      return false;
    }
    return true;
  }

  /// Checks if the graph contains any triples matching the given pattern
  ///
  /// This method determines whether at least one triple in the graph matches
  /// all the specified pattern components. Unlike [findTriples], this method
  /// returns a boolean result and is more efficient when you only need to
  /// know if matching triples exist rather than retrieving them.
  ///
  /// Pattern matching uses AND logic - all non-null parameters must match
  /// for a triple to be considered a match. Null parameters act as wildcards
  /// and match any value in that position.
  ///
  /// **Set-based Queries:** The `*In` parameters allow efficient checking for
  /// triples that match any value in a set. When multiple values are provided
  /// via these parameters, the method checks if ANY of those values match
  /// (OR logic within the set), while different parameter types still use AND logic.
  ///
  /// **Performance:** When [subjectIn] is used with indexing enabled, this method
  /// leverages the internal index structure for optimal performance. The method
  /// short-circuits as soon as a match is found, making it very efficient for
  /// existence checks even with large sets.
  ///
  /// Parameters:
  /// - [subject] Optional subject to match (null acts as wildcard)
  /// - [subjectIn] Optional set of subjects - returns true if ANY of these subjects have matching triples
  /// - [predicate] Optional predicate to match (null acts as wildcard)
  /// - [predicateIn] Optional set of predicates - returns true if ANY of these predicates match
  /// - [object] Optional object to match (null acts as wildcard)
  /// - [objectIn] Optional set of objects - returns true if ANY of these objects match
  ///
  /// Note: If both [subject] and [subjectIn] are provided, they are combined.
  /// The same applies to predicate/predicateIn and object/objectIn pairs.
  /// Empty sets in `*In` parameters will always return false.
  ///
  /// Returns:
  /// `true` if at least one triple matches the pattern, `false` otherwise.
  /// Returns `true` for empty pattern (all parameters null) if graph is not empty.
  /// Returns `false` if any `*In` parameter is an empty set.
  ///
  /// Example:
  /// ```dart
  /// // Check if John has any statements about him
  /// if (graph.hasTriples(subject: john)) {
  ///   print('Found information about John');
  /// }
  ///
  /// // Check if anyone has a name property
  /// if (graph.hasTriples(predicate: foaf.name)) {
  ///   print('Graph contains name information');
  /// }
  ///
  /// // Check if John specifically has a name
  /// if (graph.hasTriples(subject: john, predicate: foaf.name)) {
  ///   print('John has a name in the graph');
  /// }
  ///
  /// // Check if graph has any triples at all
  /// if (graph.hasTriples()) {
  ///   print('Graph is not empty');
  /// }
  ///
  /// // Check if John OR Jane have any triples (set-based query)
  /// if (graph.hasTriples(subjectIn: [john, jane])) {
  ///   print('Found information about John or Jane');
  /// }
  ///
  /// // Check if any name OR email properties exist
  /// if (graph.hasTriples(predicateIn: [name, email])) {
  ///   print('Graph contains contact information');
  /// }
  ///
  /// // Complex existence check with multiple sets
  /// if (graph.hasTriples(
  ///   subjectIn: [john, jane, bob],
  ///   predicateIn: [name, email],
  /// )) {
  ///   print('At least one person has contact info');
  /// }
  ///
  /// // Empty set always returns false
  /// assert(graph.hasTriples(subjectIn: []) == false);
  /// ```
  bool hasTriples({
    RdfSubject? subject,
    Iterable<RdfSubject>? subjectIn,
    RdfPredicate? predicate,
    Iterable<RdfPredicate>? predicateIn,
    RdfObject? object,
    Iterable<RdfObject>? objectIn,
  }) {
    final subjectSet = (subject != null || subjectIn != null)
        ? {if (subject != null) subject, ...?subjectIn}
        : null;

    final predicateSet = (predicate != null || predicateIn != null)
        ? {if (predicate != null) predicate, ...?predicateIn}
        : null;

    final objectSet = (object != null || objectIn != null)
        ? {if (object != null) object, ...?objectIn}
        : null;
    // 2. Optimized path using the index
    if (subjectSet != null && _effectiveIndex != null) {
      final index = _effectiveIndex!;
      // If any subject in the set can be found with a matching triple, return true.
      return subjectSet.any((s) {
        final subjectMap = index[s];
        if (subjectMap == null) return false; // No triples for this subject

        final Iterable<Triple> candidates;
        if (predicateSet != null) {
          // If predicateSet is empty, this will result in an empty sequence,
          // correctly finding no candidates.
          candidates = predicateSet
              .map((p) => subjectMap[p])
              .where((list) => list != null)
              .expand((list) => list!);
        } else {
          candidates = subjectMap.values.expand((list) => list);
        }

        // Check if any candidate matches the object filter.
        if (objectSet != null) {
          return candidates.any((triple) => objectSet.contains(triple.object));
        } else {
          // If there's no object filter, having any candidates is a match.
          return candidates.isNotEmpty;
        }
      });
    }

    return _triples
        .any((triple) => _matches(triple, subjectSet, predicateSet, objectSet));
  }

  /// Creates a new graph containing only triples that match the given pattern
  ///
  /// This method returns a filtered graph containing all triples that match the specified
  /// pattern components. Unlike [findTriples], this method returns a new RdfGraph
  /// instance that can be used for further graph operations, chaining, and merging.
  ///
  /// **Performance Optimization:** When filtering by subject (with or without predicate)
  /// and indexing is enabled, this method can reuse parts of the existing index for
  /// improved performance of subsequent operations on the filtered graph.
  ///
  /// Pattern matching uses AND logic - all non-null parameters must match
  /// for a triple to be included. Null parameters act as wildcards and match
  /// any value in that position.
  ///
  /// Parameters:
  /// - [subject] Optional subject to match (null acts as wildcard)
  /// - [predicate] Optional predicate to match (null acts as wildcard)
  /// - [object] Optional object to match (null acts as wildcard)
  ///
  /// Returns:
  /// A new RdfGraph containing only the matching triples. The filtered graph may be
  /// empty if no triples match the pattern.
  ///
  /// Example:
  /// ```dart
  /// // Get all information about John as a separate graph
  /// final johnGraph = graph.matching(subject: john);
  ///
  /// // Get all type declarations
  /// final typeGraph = graph.matching(predicate: rdf.type);
  ///
  /// // Chain operations efficiently
  /// final result = graph
  ///   .matching(subject: john)
  ///   .merge(otherGraph)
  ///   .matching(predicate: foaf.knows);
  /// ```
  RdfGraph matching({
    RdfSubject? subject,
    RdfPredicate? predicate,
    RdfObject? object,
  }) {
    // Optimization: if filtering by subject and we have an index
    if (subject != null && object == null) {
      switch (_effectiveIndex) {
        case null:
          break;
        case final index:
          final subjectMap = index[subject];
          if (subjectMap == null) {
            // Subject not found - return empty graph
            return RdfGraph(enableIndexing: indexingEnabled);
          }

          if (predicate == null) {
            // Subject only: use entire subject map
            final subjectTriples = subjectMap.values.expand((list) => list);
            final reducedIndex = {subject: subjectMap};

            return RdfGraph._withIndex(
              subjectTriples,
              reducedIndex,
              indexingEnabled,
            );
          } else {
            // Subject + predicate: use specific predicate list
            final predicateTriples = subjectMap[predicate];
            if (predicateTriples == null) {
              // Subject+predicate not found - return empty graph
              return RdfGraph(enableIndexing: indexingEnabled);
            }

            final reducedIndex = {
              subject: {predicate: predicateTriples}
            };

            return RdfGraph._withIndex(
              predicateTriples,
              reducedIndex,
              indexingEnabled,
            );
          }
      }
    }

    // General case: delegate to findTriples and create new graph
    final matchingTriples = findTriples(
      subject: subject,
      predicate: predicate,
      object: object,
    );

    return RdfGraph(triples: matchingTriples, enableIndexing: indexingEnabled);
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
    var objects = findTriples(
      subject: subject,
      predicate: predicate,
    ).map((triple) => triple.object);
    return objects.isEmpty
        ? const []
        : List.unmodifiable(
            objects,
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
    var subjects = findTriples(
      predicate: predicate,
      object: object,
    ).map((triple) => triple.subject);
    return subjects.isEmpty
        ? const []
        : List.unmodifiable(
            subjects,
          );
  }

  /// Merges this graph with another, producing a new graph
  ///
  /// This creates a union of the two graphs, combining all their triples.
  /// Duplicate triples are automatically removed, as RDF graphs are mathematical
  /// sets where each triple can appear at most once. The order of triples in
  /// the resulting graph is not guaranteed to be preserved from either source graph.
  ///
  /// Parameters:
  /// - [other] The graph to merge with this one
  ///
  /// Returns:
  /// A new graph containing all unique triples from both graphs,
  /// with duplicates removed and no guaranteed ordering
  ///
  /// Example:
  /// ```dart
  /// // Merge two graphs to combine their information
  /// final combinedGraph = personGraph.merge(addressGraph);
  ///
  /// // Duplicate triples between graphs are automatically removed
  /// final merged = graph1.merge(graph2); // Each unique triple appears only once
  /// ```
  RdfGraph merge(RdfGraph other, {removeDuplicates = true}) {
    return withTriples(other._triples, removeDuplicates: removeDuplicates);
  }

  /// Creates a new graph by removing all triples from another graph
  ///
  /// This method performs graph subtraction - it removes all triples present
  /// in the other graph from this graph. Since RdfGraph is immutable, this
  /// returns a new instance with the remaining triples.
  ///
  /// This operation is useful for:
  /// - Removing a specific subset of knowledge from a graph
  /// - Computing the difference between two graphs
  /// - Undoing the effects of a previous merge operation
  ///
  /// Parameters:
  /// - [other] The graph whose triples should be removed from this graph
  ///
  /// Returns:
  /// A new graph containing all triples from this graph except those that
  /// also exist in the other graph. If the graphs share no common triples,
  /// returns a new graph identical to the original.
  ///
  /// Example:
  /// ```dart
  /// // Remove all personal information from a combined dataset
  /// final publicGraph = fullGraph.without(personalInfoGraph);
  ///
  /// // Compute the difference between two versions of a graph
  /// final changesOnly = newVersion.without(oldVersion);
  ///
  /// ```
  RdfGraph without(RdfGraph other) {
    return withoutTriples(other._triples);
  }

  Iterable<Triple> _getSubgraphTriples(
    RdfGraph subgraph,
    RdfSubject subject, {
    Set<RdfSubject>? visited,
    TraversalFilter? filter,
    int depth = 0,
  }) sync* {
    visited ??= <RdfSubject>{};
    if (visited.contains(subject)) {
      return;
    }
    visited.add(subject);

    for (final triple in subgraph.findTriples(subject: subject)) {
      final decision = filter?.call(triple, depth) ?? TraversalDecision.include;
      // Debug: Uncomment for debugging
      // print('Triple at depth $depth: $triple -> $decision');

      switch (decision) {
        case TraversalDecision.include:
          yield triple;
          final obj = triple.object;
          if (obj is RdfSubject) {
            yield* _getSubgraphTriples(
              subgraph,
              obj,
              visited: visited,
              filter: filter,
              depth: depth + 1,
            );
          }
          break;

        case TraversalDecision.includeButDontDescend:
          yield triple;
          break;

        case TraversalDecision.skip:
          // Don't yield the triple and don't descend
          break;
        case TraversalDecision.skipButDescend:
          final obj = triple.object;
          if (obj is RdfSubject) {
            yield* _getSubgraphTriples(
              subgraph,
              obj,
              visited: visited,
              filter: filter,
              depth: depth + 1,
            );
          }
          break;
      }
    }
  }

  /// Extracts a subgraph starting from a root subject with optional traversal control
  ///
  /// This method creates a true graph-theory subgraph by following reachable nodes
  /// from the specified root subject. Unlike [matching], which performs pattern-based
  /// filtering, this method traverses the graph structure by following object references
  /// that are IRIs or blank nodes.
  ///
  /// **Traversal Behavior:**
  /// - Starts from the root subject
  /// - For each triple where the root is the subject, includes the triple
  /// - If the object is an IRI or blank node, recursively traverses from that object
  /// - Includes cycle detection to prevent infinite loops
  /// - Optional filter callback allows fine-grained control over traversal
  ///
  /// **Traversal Control:**
  /// The optional [filter] callback is invoked for each triple encountered during
  /// traversal, allowing you to control which triples are included and whether
  /// traversal should continue from their objects.
  ///
  /// Parameters:
  /// - [root] The subject to start traversal from
  /// - [filter] Optional callback to control traversal behavior for each triple
  ///
  /// Returns:
  /// A new RdfGraph containing all reachable triples from the root subject,
  /// filtered according to the traversal decisions.
  ///
  /// Example:
  /// ```dart
  /// // Simple subgraph extraction
  /// final aliceSubgraph = graph.subgraph(alice);
  ///
  /// // Controlled traversal - exclude email and don't descend from addresses
  /// final filtered = graph.subgraph(alice, filter: (triple, depth) {
  ///   // Don't include email triples at all
  ///   if (triple.predicate.iri.endsWith('email')) {
  ///     return TraversalDecision.skip;
  ///   }
  ///
  ///   // Include address info but don't traverse into address details
  ///   if (triple.predicate.iri.endsWith('hasAddress')) {
  ///     return TraversalDecision.includeButDontDescend;
  ///   }
  ///
  ///   // Limit traversal depth
  ///   if (depth > 2) {
  ///     return TraversalDecision.includeButDontDescend;
  ///   }
  ///
  ///   return TraversalDecision.include;
  /// });
  ///
  /// // List filtering example using skipButDescend
  /// // Extract only list values from RDF lists, skipping structural elements
  /// final listValues = graph.subgraph(listRoot, filter: (triple, depth) {
  ///   // Skip rdf:rest (list structure) but continue following the list
  ///   if (triple.predicate.iri == 'http://www.w3.org/1999/02/22-rdf-syntax-ns#rest') {
  ///     return TraversalDecision.skipButDescend;
  ///   }
  ///   // Include rdf:first (actual values) and other content
  ///   return TraversalDecision.include;
  /// });
  /// ```
  RdfGraph subgraph(RdfSubject root, {TraversalFilter? filter}) {
    final subgraphTriples = _getSubgraphTriples(
      this,
      root,
      filter: filter,
    ).toList();
    return RdfGraph(triples: subgraphTriples, enableIndexing: indexingEnabled);
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
  /// **Important:** This implementation performs syntactic equality based on
  /// exact triple matching. Two graphs that are semantically equivalent but
  /// have different [BlankNodeTerm] instances will NOT be considered equal,
  /// even if they represent the same RDF structure. [BlankNodeTerm] instances
  /// are only equal if they are the identical object instance.
  ///
  /// **For semantic graph comparison:** Use [isIsomorphicGraphs] from
  /// `lib/src/canonical/canonical_util.dart`, which implements RDF graph
  /// isomorphism based on the RDF Canonicalization specification. This
  /// provides true semantic equality but is more computationally expensive
  /// and not consistent with [hashCode].
  ///
  /// **Alternative:** Consider using [CanonicalRdfGraph] which lazily computes
  /// a canonical serialized form and uses it for both comparison and hashing,
  /// providing consistent semantic equality with proper hash code behavior.
  ///
  /// This implementation treats RDF graphs as sets rather than lists,
  /// which aligns with the syntactic definition of RDF graphs in the specification.
  ///
  /// Example:
  /// ```dart
  /// // These graphs are syntactically different due to different blank nodes
  /// final graph1 = RdfGraph(triples: [Triple(BlankNodeTerm(), knows, alice)]);
  /// final graph2 = RdfGraph(triples: [Triple(BlankNodeTerm(), knows, alice)]);
  /// assert(graph1 != graph2); // Different BlankNodeTerm instances
  ///
  /// // For semantic comparison:
  /// import 'package:rdf_core/src/canonical/canonical_util.dart';
  /// assert(isIsomorphicGraphs(graph1, graph2)); // Semantically equivalent
  /// ```
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
