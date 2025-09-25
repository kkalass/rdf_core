/// RDF Quad Implementation
///
/// Defines the [Quad] class for representing RDF statements with graph context.
/// A quad extends the RDF triple model by adding a fourth component that specifies
/// the named graph containing the statement, enabling context-aware RDF processing.
///
/// ## RDF Quad Concepts
///
/// An RDF quad consists of four components:
/// - **Subject**: The resource being described (IRI or blank node)
/// - **Predicate**: The property or relationship type (always an IRI)
/// - **Object**: The property value or related resource (IRI, blank node, or literal)
/// - **Graph**: The named graph containing this statement (IRI or null for default graph)
///
/// This aligns with the RDF 1.1 Dataset specification and N-Quads serialization format,
/// where each statement includes its graph context for provenance and organization.
///
/// ## Key Features
///
/// - **Standard compliance**: Follows (S, P, O, G) parameter order used across RDF libraries
/// - **Default graph support**: Null graph name indicates the default graph
/// - **Triple compatibility**: Easy conversion between triples and quads
/// - **Immutable design**: Thread-safe and prevents accidental modification
/// - **Type safety**: Leverages Dart's type system for RDF term validation
///
/// ## Usage Examples
///
/// ### Basic Quad Creation
///
/// ```dart
/// // Quad in a named graph
/// final quad = Quad(
///   john,
///   foaf.name,
///   LiteralTerm.string("John Doe"),
///   IriTerm('http://example.org/people')
/// );
///
/// // Quad in the default graph
/// final defaultQuad = Quad(jane, foaf.age, LiteralTerm.integer(25));
/// ```
///
/// ### Converting Between Triples and Quads
///
/// ```dart
/// // From triple to quad
/// final triple = Triple(john, foaf.knows, jane);
/// final quad = Quad.fromTriple(triple, peopleGraphName);
///
/// // From quad to triple (loses graph context)
/// final backToTriple = quad.triple;
/// ```
///
/// ### Working with Graph Context
///
/// ```dart
/// // Check graph context
/// if (quad.isDefaultGraph) {
///   print('Statement is in the default graph');
/// } else {
///   print('Statement is in graph: ${quad.graphName!.iri}');
/// }
///
/// // Group quads by graph
/// final quadsByGraph = <IriTerm?, List<Quad>>{};
/// for (final quad in quads) {
///   quadsByGraph.putIfAbsent(quad.graphName, () => []).add(quad);
/// }
/// ```
///
/// ## Serialization Compatibility
///
/// Quads directly support N-Quads serialization format:
/// - Default graph quads: `<s> <p> <o> .`
/// - Named graph quads: `<s> <p> <o> <g> .`
///
/// ## Performance Characteristics
///
/// - **Construction**: O(1) - direct field assignment
/// - **Triple extraction**: O(1) - creates new Triple instance
/// - **Comparison**: O(1) for equality checks
/// - **Memory**: Minimal overhead beyond the four RDF terms
///
/// ## Relationship to RDF Standards
///
/// This implementation follows:
/// - [RDF 1.1 Concepts - RDF Datasets](https://www.w3.org/TR/rdf11-concepts/#section-dataset)
/// - [N-Quads - A line-based syntax for RDF datasets](https://www.w3.org/TR/n-quads/)
/// - Common RDF library conventions (RDFLib, Apache Jena, RDF.js)
library rdf_quad;

import 'package:rdf_core/rdf_core.dart';

/// Represents an immutable RDF quad with graph context
///
/// An RDF quad extends the triple model (subject, predicate, object) with a fourth
/// component that specifies the graph containing the statement. This enables:
///
/// - **Context tracking**: Know which graph contains each statement
/// - **Provenance management**: Track the source or context of RDF data
/// - **Dataset operations**: Work with multi-graph RDF datasets efficiently
/// - **N-Quads support**: Direct compatibility with quad-based serialization
///
/// The graph component can be null to indicate the default graph, following
/// RDF 1.1 Dataset semantics where every dataset has exactly one default graph
/// and zero or more named graphs.
///
/// ## Design Principles
///
/// - **Standard Parameter Order**: Uses (S, P, O, G) order consistent with other RDF libraries
/// - **Immutability**: All components are final, ensuring thread safety
/// - **Null Graph Handling**: Null graph name represents the default graph
/// - **Triple Compatibility**: Easy bidirectional conversion with Triple class
///
/// Example:
/// ```dart
/// // Create quad with named graph
/// final namedQuad = Quad(
///   IriTerm('http://example.org/alice'),
///   IriTerm('http://xmlns.com/foaf/0.1/name'),
///   LiteralTerm.string('Alice'),
///   IriTerm('http://example.org/graphs/people')
/// );
///
/// // Create quad in default graph
/// final defaultQuad = Quad(alice, foaf.email, aliceEmail);
/// ```
final class Quad {
  /// The subject of this RDF statement
  ///
  /// The resource being described in this quad. Must be either an IRI or blank node
  /// according to RDF 1.1 specification. Cannot be a literal.
  final RdfSubject subject;

  /// The predicate (property) of this RDF statement
  ///
  /// The property or relationship type connecting the subject to the object.
  /// Must always be an IRI according to RDF 1.1 specification.
  final RdfPredicate predicate;

  /// The object (value) of this RDF statement
  ///
  /// The property value or related resource. Can be an IRI, blank node, or literal
  /// according to RDF 1.1 specification.
  final RdfObject object;

  /// The graph containing this statement
  ///
  /// The IRI name of the graph containing this quad. If null, this quad belongs
  /// to the default graph. This follows RDF 1.1 Dataset semantics where graph
  /// names are IRIs and the default graph has no name.
  final IriTerm? graphName;

  /// Creates a new RDF quad with the specified components
  ///
  /// Constructs an immutable quad using the standard RDF parameter order:
  /// subject, predicate, object, graph. The graph parameter is optional and
  /// defaults to null (indicating the default graph).
  ///
  /// Parameters:
  /// - [subject] The subject resource (IRI or blank node)
  /// - [predicate] The predicate IRI
  /// - [object] The object (IRI, blank node, or literal)
  /// - [graphName] Optional IRI identifying the containing graph (null = default graph)
  ///
  /// Example:
  /// ```dart
  /// // Quad in named graph
  /// final quad = Quad(john, foaf.name, johnName, peopleGraph);
  ///
  /// // Quad in default graph
  /// final defaultQuad = Quad(jane, foaf.age, janeAge);
  /// ```
  const Quad(this.subject, this.predicate, this.object, [this.graphName]);

  /// Creates a quad from an existing triple and optional graph name
  ///
  /// This factory constructor provides convenient conversion from Triple to Quad
  /// by adding graph context. If no graph name is provided, the quad will
  /// belong to the default graph.
  ///
  /// Parameters:
  /// - [triple] The RDF triple to convert
  /// - [graphName] Optional graph name (null = default graph)
  ///
  /// Returns:
  /// A new Quad with the same S-P-O components as the triple plus the graph context.
  ///
  /// Example:
  /// ```dart
  /// final triple = Triple(alice, foaf.knows, bob);
  /// final namedQuad = Quad.fromTriple(triple, socialGraphName);
  /// final defaultQuad = Quad.fromTriple(triple); // default graph
  /// ```
  Quad.fromTriple(Triple triple, [IriTerm? graphName])
      : subject = triple.subject,
        predicate = triple.predicate,
        object = triple.object,
        graphName = graphName;

  /// Extracts the triple component of this quad (without graph context)
  ///
  /// Creates a new Triple instance containing the subject, predicate, and object
  /// components of this quad. The graph context information is lost in this conversion.
  ///
  /// This is useful when you need to work with RDF operations that expect triples,
  /// or when processing quad data in a graph-agnostic manner.
  ///
  /// Returns:
  /// A new Triple with the same subject, predicate, and object as this quad.
  ///
  /// Example:
  /// ```dart
  /// final quad = Quad(alice, foaf.name, aliceName, peopleGraph);
  /// final triple = quad.triple; // Graph context is lost
  ///
  /// // Use triple in graph operations
  /// final graph = RdfGraph().withTriple(triple);
  /// ```
  Triple get triple => Triple(subject, predicate, object);

  /// Whether this quad belongs to the default graph
  ///
  /// Returns true if this quad's graph name is null, indicating it belongs
  /// to the default graph. According to RDF 1.1 Dataset specification,
  /// every dataset has exactly one default graph that has no name.
  ///
  /// Returns:
  /// true if this quad is in the default graph, false if it's in a named graph.
  ///
  /// Example:
  /// ```dart
  /// final defaultQuad = Quad(alice, foaf.name, aliceName);
  /// final namedQuad = Quad(bob, foaf.age, bobAge, peopleGraph);
  ///
  /// assert(defaultQuad.isDefaultGraph == true);
  /// assert(namedQuad.isDefaultGraph == false);
  /// ```
  bool get isDefaultGraph => graphName == null;

  /// Compares this quad to another object for equality
  ///
  /// Two quads are equal if all four components (subject, predicate, object, graph)
  /// are equal. This includes proper handling of null graph names for default graph quads.
  ///
  /// Parameters:
  /// - [other] The object to compare against
  ///
  /// Returns:
  /// true if the other object is a Quad with identical components, false otherwise.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Quad) return false;

    return subject == other.subject &&
        predicate == other.predicate &&
        object == other.object &&
        graphName == other.graphName;
  }

  /// Provides a hash code for this quad based on all four components
  ///
  /// The hash code combines the hash codes of subject, predicate, object, and graph
  /// components to ensure quads with identical components have identical hash codes,
  /// enabling proper behavior in hash-based collections.
  ///
  /// Returns:
  /// A hash code value for this quad.
  @override
  int get hashCode => Object.hash(subject, predicate, object, graphName);

  /// Returns a string representation of this quad
  ///
  /// The format follows N-Quads conventions:
  /// - Named graph quads: `<subject> <predicate> <object> <graph> .`
  /// - Default graph quads: `<subject> <predicate> <object> .`
  ///
  /// Returns:
  /// A string representation suitable for debugging and logging.
  @override
  String toString() {
    final triple = '${subject} ${predicate} ${object}';
    return graphName != null ? '$triple $graphName .' : '$triple .';
  }
}