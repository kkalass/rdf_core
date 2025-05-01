/// RDF Core Vocabulary
///
/// Provides constants for the [RDF vocabulary](http://www.w3.org/1999/02/22-rdf-syntax-ns#),
/// which defines the core concepts and properties of the RDF data model.
///
/// Example usage:
/// ```dart
/// import 'package:rdf_core/src/vocab/rdf.dart';
/// final type = RdfPredicates.type;
/// ```
///
/// All constants are pre-constructed as IriTerm objects to enable direct use in
/// constructing RDF graphs without repeated string concatenation or term creation.
///
/// [Specification Reference](https://www.w3.org/TR/rdf11-concepts/)
library rdf_vocab;

import 'package:rdf_core/src/graph/rdf_term.dart';

/// Base RDF namespace and utility functions
class Rdf {
  // coverage:ignore-start
  const Rdf._();
  // coverage:ignore-end

  /// Base IRI for RDF vocabulary
  /// [Spec](http://www.w3.org/1999/02/22-rdf-syntax-ns#)
  static const String namespace = 'http://www.w3.org/1999/02/22-rdf-syntax-ns#';
  static const String prefix = 'rdf';
}

/// RDF type/class constants.
///
/// Contains IRIs that represent classes or types defined in the RDF vocabulary.
class RdfTypes {
  // coverage:ignore-start
  const RdfTypes._();
  // coverage:ignore-end

  /// IRI for rdf:langString datatype
  ///
  /// Represents the datatype for language-tagged string literals.
  /// According to the RDF specification, all language-tagged strings
  /// must have this datatype.
  ///
  /// Example in Turtle:
  /// ```turtle
  /// <http://example.org/book> <http://example.org/title> "The Title"@en .
  /// ```
  static const langString = IriTerm.prevalidated('${Rdf.namespace}langString');
}

/// RDF predicate constants.
///
/// Contains IRIs for properties defined in the RDF vocabulary.

class RdfPredicates {
  // coverage:ignore-start
  const RdfPredicates._();
  // coverage:ignore-end

  /// IRI for rdf:type predicate
  /// [Spec](https://www.w3.org/TR/rdf11-concepts/#section-triples)
  ///
  /// Represents the relationship between a resource and its type/class.
  /// This is one of the most commonly used properties in RDF.
  ///
  /// Example in Turtle:
  /// ```turtle
  /// <http://example.org/john> rdf:type foaf:Person .
  /// ```
  static const type = IriTerm.prevalidated('${Rdf.namespace}type');
}
