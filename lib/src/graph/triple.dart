/// RDF Triple Implementation
///
/// Defines the [Triple] class, the atomic unit of RDF data, consisting of subject,
/// predicate, and object. This library implements the core data structures for
/// representing RDF statements according to the W3C RDF 1.1 Concepts specification.
///
/// An RDF triple represents a statement about a resource and consists of:
/// - A subject: what the statement is about (an IRI or blank node)
/// - A predicate: the property or relation being described (always an IRI)
/// - An object: the value of the property or the related resource (an IRI, blank node, or literal)
///
/// Example usage:
/// ```dart
/// import 'package:rdf_core/rdf_core.dart';
///
/// // Basic triple with IRI terms
/// final subject = IriTerm('http://example.org/resource');
/// final predicate = IriTerm('http://example.org/property');
/// final object = IriTerm('http://example.org/value');
/// final triple = Triple(subject, predicate, object);
///
/// // Advanced: blank node as subject
/// final bnode = BlankNodeTerm();
/// final triple2 = Triple(bnode, predicate, object);
///
/// // Advanced: literal as object
/// final literal = LiteralTerm('Alice', datatype: Xsd.string);
/// final triple3 = Triple(subject, predicate, literal);
/// ```
///
/// Error handling:
/// - Throws [ArgumentError] if subject, predicate, or object are null.
///
/// Performance considerations:
/// - Triple equality and hashCode operations are O(1).
/// - Triples are immutable and can be safely used as keys in hash maps.
///
/// Related specifications:
/// - [RDF 1.1 Concepts - Triples](https://www.w3.org/TR/rdf11-concepts/#section-triples)
/// - [RDF 1.1 Semantics](https://www.w3.org/TR/rdf11-mt/)
library rdf_triple;

import 'package:rdf_core/src/graph/rdf_term.dart';

/// Represents an RDF triple.
///
/// A triple is the atomic unit of data in RDF, consisting of three components:
/// - subject: The resource being described (IRI or BlankNode)
/// - predicate: The property or relationship (always an IRI)
/// - object: The value or related resource (IRI, BlankNode, or Literal)
///
/// Triple data structures implement the constraints of the RDF data model using
/// Dart's type system to ensure that only valid RDF statements can be created.
/// The type system enforces that:
/// - Subjects can only be IRIs or blank nodes
/// - Predicates can only be IRIs
/// - Objects can be IRIs, blank nodes, or literals
///
/// Example in Turtle syntax:
/// ```turtle
/// # A triple stating that "John has the name 'John Smith'"
/// <http://example.com/john> <http://xmlns.com/foaf/0.1/name> "John Smith" .
///
/// # A triple stating that "John knows Jane"
/// <http://example.com/john> <http://xmlns.com/foaf/0.1/knows> <http://example.com/jane> .
/// ```
class Triple {
  /// The subject of the triple, representing the resource being described.
  ///
  /// In RDF, the subject must be either an IRI or a blank node. The RDF 1.1
  /// specification does not allow literals as subjects.
  ///
  /// The [RdfSubject] type ensures that only valid terms can be used as subjects,
  /// enforcing the RDF data model constraints at compile time.
  final RdfSubject subject;

  /// The predicate of the triple, representing the property or relationship.
  ///
  /// In RDF, the predicate must be an IRI. The RDF 1.1 specification does not
  /// allow blank nodes or literals as predicates.
  ///
  /// The [RdfPredicate] type ensures that only valid terms can be used as predicates,
  /// enforcing the RDF data model constraints at compile time.
  final RdfPredicate predicate;

  /// The object of the triple, representing the value or related resource.
  ///
  /// In RDF, the object can be an IRI, a blank node, or a literal value.
  /// This is the most flexible position in a triple, allowing any valid RDF term.
  ///
  /// The [RdfObject] type represents this flexibility, allowing any of the three
  /// term types to be used in this position.
  final RdfObject object;

  /// Creates a new triple with the specified subject, predicate, and object.
  ///
  /// The constructor accepts any values that conform to the RDF term types
  /// that are allowed in each position, ensuring that only valid RDF triples
  /// can be created.
  ///
  /// Parameters:
  /// - [subject] The subject of the triple (must be an IRI or blank node)
  /// - [predicate] The predicate of the triple (must be an IRI)
  /// - [object] The object of the triple (can be an IRI, blank node, or literal)
  ///
  /// Example:
  /// ```dart
  /// // Create a triple: <http://example.org/john> <http://xmlns.com/foaf/0.1/name> "John Smith"
  /// final john = IriTerm('http://example.org/john');
  /// final name = IriTerm('http://xmlns.com/foaf/0.1/name');
  /// final johnSmith = LiteralTerm.string('John Smith');
  /// final triple = Triple(john, name, johnSmith);
  /// ```
  Triple(this.subject, this.predicate, this.object);

  @override
  bool operator ==(Object other) {
    return other is Triple &&
        subject == other.subject &&
        predicate == other.predicate &&
        object == other.object;
  }

  @override
  int get hashCode => Object.hash(subject, predicate, object);

  /// Returns a string representation of the triple in a Turtle-like syntax.
  ///
  /// The output format is similar to Turtle's triple pattern with a period:
  /// `<subject> <predicate> <object> .`
  ///
  /// This representation is useful for debugging and logging purposes, but
  /// it's not guaranteed to be valid Turtle syntax, as it relies on the
  /// string representations of the individual terms.
  ///
  /// Example:
  /// ```dart
  /// final triple = Triple(
  ///   IriTerm('http://example.org/john'),
  ///   IriTerm('http://xmlns.com/foaf/0.1/name'),
  ///   LiteralTerm.string('John Smith')
  /// );
  ///
  /// print(triple); // Prints: <http://example.org/john> <http://xmlns.com/foaf/0.1/name> "John Smith" .
  /// ```
  @override
  String toString() => '$subject $predicate $object .';
}
