/// RDF Triple Implementation
///
/// Defines the [Triple] class, the atomic unit of RDF data, consisting of subject, predicate, and object.
///
/// Example usage:
/// ```dart
/// import 'package:rdf_core/src/graph/triple.dart';
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
/// Performance:
/// - Triple equality and hashCode are O(1).
///
/// See: [RDF 1.1 Concepts - Triples](https://www.w3.org/TR/rdf11-concepts/#section-triples)
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
  /// Must be either an IRI or a blank node.
  final RdfSubject subject;

  /// The predicate of the triple, representing the property or relationship.
  /// Must be an IRI.
  final RdfPredicate predicate;

  /// The object of the triple, representing the value or related resource.
  /// Can be an IRI, a blank node, or a literal.
  final RdfObject object;

  /// Creates a new triple with the specified subject, predicate, and object.
  ///
  /// The constructor accepts any values that conform to the RDF term types
  /// that are allowed in each position, ensuring that only valid RDF triples
  /// can be created.
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

  @override
  String toString() => '$subject $predicate $object .';
}
