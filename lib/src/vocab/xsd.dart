///
/// XML Schema Definition (XSD) Vocabulary
///
/// Provides constants for the [XML Schema Definition vocabulary](http://www.w3.org/2001/XMLSchema#),
/// which defines data types used in RDF literals.
///
/// Example usage:
/// ```dart
/// import 'package:rdf_core/src/vocab/xsd.dart';
/// final integerType = Xsd.integer;
/// ```
///
/// All constants are pre-constructed as IriTerm objects to enable direct use in
/// constructing RDF graphs without repeated string concatenation or term creation.
///
/// [Specification Reference](https://www.w3.org/TR/xmlschema11-2/)
library xsd_vocab;

import 'package:rdf_core/src/graph/rdf_term.dart';

/// XSD namespace and datatype constants
///
/// Contains IRIs for XML Schema datatypes commonly used in RDF.
///
/// This class provides access to the standard XML Schema datatypes that are used
/// in RDF for typing literal values. The RDF specification adopts XSD datatypes
/// as its primary type system for literal values.
///
/// These constants are particularly important when creating typed literals in RDF graphs.

class Xsd {
  // coverage:ignore-start
  const Xsd._();
  // coverage:ignore-end

  /// Base IRI for XMLSchema datatypes
  /// [Spec](https://www.w3.org/TR/xmlschema-2/)
  static const String namespace = 'http://www.w3.org/2001/XMLSchema#';

  static const String prefix = 'xsd';

  /// IRI for xsd:string datatype
  /// [Spec](https://www.w3.org/TR/xmlschema-2/#string)
  ///
  /// Represents character strings in XML Schema and RDF.
  /// This is the default datatype for string literals in RDF when no type is specified.
  ///
  /// Example in Turtle:
  /// ```turtle
  /// <http://example.org/name> "John Smith"^^xsd:string .
  /// ```
  static const string = IriTerm.prevalidated('${Xsd.namespace}string');

  /// IRI for xsd:boolean datatype
  ///
  /// Represents boolean values: true or false.
  ///
  /// Example in Turtle:
  /// ```turtle
  /// <http://example.org/isActive> "true"^^xsd:boolean .
  /// ```
  static const boolean = IriTerm.prevalidated('${Xsd.namespace}boolean');

  /// IRI for xsd:integer datatype
  ///
  /// Represents integer numbers (without a fractional part).
  ///
  /// Example in Turtle:
  /// ```turtle
  /// <http://example.org/age> "42"^^xsd:integer .
  /// ```
  static const integer = IriTerm.prevalidated('${Xsd.namespace}integer');

  /// IRI for xsd:decimal datatype
  ///
  /// Represents decimal numbers with arbitrary precision.
  ///
  /// Example in Turtle:
  /// ```turtle
  /// <http://example.org/price> "19.99"^^xsd:decimal .
  /// ```
  static const decimal = IriTerm.prevalidated('${Xsd.namespace}decimal');

  /// IRI for xsd:double datatype
  ///
  /// Represents double-precision 64-bit floating point numbers.
  ///
  /// Example in Turtle:
  /// ```turtle
  /// <http://example.org/coefficient> "3.14159265359"^^xsd:double .
  /// ```
  static const double = IriTerm.prevalidated('${Xsd.namespace}double');

  /// Creates an XSD datatype IRI from a local name
  ///
  /// This utility method allows creating IRI terms for XSD datatypes that
  /// aren't explicitly defined as constants in this class.
  ///
  /// Parameters:
  /// - [xsdType]: The local name of the XSD datatype (e.g., "string", "integer", "gYear")
  ///
  /// Returns:
  /// - An IriTerm representing the full XSD datatype IRI
  ///
  /// Example:
  /// ```dart
  /// // Create an IRI for xsd:gMonth datatype
  /// final gMonthType = Xsd.makeIri("gMonth");
  /// ```
  static IriTerm makeIri(String xsdType) => IriTerm('${Xsd.namespace}$xsdType');
}
