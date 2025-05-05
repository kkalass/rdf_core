/// RDF Term Types
///
/// Defines the core RDF term types: [RdfTerm], [RdfSubject], [RdfPredicate], [RdfObject], [IriTerm], [BlankNodeTerm], [LiteralTerm].
///
/// Example usage:
/// ```dart
/// import 'package:rdf_core/src/graph/rdf_term.dart';
/// final subject = IriTerm('http://example.org/subject');
///
/// // Advanced: create a blank node (uses identity hash code)
/// final bnode = BlankNodeTerm();
///
/// // Advanced: create a literal
/// final literal = LiteralTerm('42', datatype: XsdTypes.int);
///
/// // Type checking
/// if (term is IriTerm) print('It is an IRI!');
///
/// // Equality
/// final a = IriTerm('x');
/// final b = IriTerm('x');
/// assert(a == b);
/// ```
///
/// Performance:
/// - Term equality and hashCode are O(1).
///
/// See: [RDF 1.1 Concepts - RDF Terms](https://www.w3.org/TR/rdf11-concepts/#section-rdf-terms) IRIs, blank nodes, or literals
///
/// This hierarchy of classes uses Dart's sealed classes to enforce the constraints
/// of the RDF specification regarding which terms can appear in which positions.
library rdf_terms;

import 'package:rdf_core/src/exceptions/rdf_validation_exception.dart';
import 'package:rdf_core/src/vocab/rdf.dart';
import 'package:rdf_core/src/vocab/xsd.dart';

/// Base type for all RDF terms
///
/// RDF terms are the atomic components used to build RDF triples.
/// This is the root of the RDF term type hierarchy.
sealed class RdfTerm {
  const RdfTerm();
}

/// Base type for values that can appear in the object position of a triple
///
/// In RDF, objects can be IRIs, blank nodes, or literals.
sealed class RdfObject extends RdfTerm {
  const RdfObject();
}

/// Base type for values that can appear in the subject position of a triple
///
/// In RDF, subjects can only be IRIs or blank nodes (not literals).
sealed class RdfSubject extends RdfObject {
  const RdfSubject();
}

/// Base type for values that can appear in the predicate position of a triple
///
/// In RDF, predicates can only be IRIs.
sealed class RdfPredicate extends RdfTerm {
  const RdfPredicate();
}

/// IRI (Internationalized Resource Identifier) in RDF
///
/// IRIs are used to identify resources in the RDF data model. They are
/// global identifiers that can refer to documents, concepts, or physical entities.
///
/// IRIs can be used in any position in a triple: subject, predicate, or object.
///
/// Example: `http://example.org/person/john` or `http://xmlns.com/foaf/0.1/name`
class IriTerm extends RdfPredicate implements RdfSubject {
  /// The string representation of the IRI
  final String iri;

  /// Creates an IRI term with the specified IRI string
  ///
  /// The IRI should be a valid absolute IRI according to RFC 3987.
  /// This constructor validates that the IRI is well-formed and absolute.
  ///
  /// Throws [RdfConstraintViolationException] if the IRI is not well-formed
  /// or not absolute.
  IriTerm(this.iri) {
    _validateAbsoluteIri(iri);
  }

  /// Creates an IRI term from a prevalidated IRI string.
  ///
  /// Use this constructor only when you are sure the IRI is valid and absolute
  /// and need to create a const instance.
  /// This is useful for performance optimization.
  const IriTerm.prevalidated(this.iri);

  /// Validates that the given string is a valid absolute IRI
  ///
  /// An absolute IRI must have a scheme component followed by a colon.
  /// This is a simplification of the RFC 3987 specification, focusing on
  /// the most important constraint that IRIs used in RDF should be absolute.
  ///
  /// Throws [RdfConstraintViolationException] if validation fails.
  static void _validateAbsoluteIri(String iri) {
    // Check for null or empty string
    if (iri.isEmpty) {
      throw RdfConstraintViolationException(
        'IRI cannot be empty',
        constraint: 'absolute-iri',
      );
    }

    // Basic check for scheme presence (scheme:rest)
    // Per RFC 3987, scheme is ALPHA *( ALPHA / DIGIT / "+" / "-" / "." )
    final schemeEndIndex = iri.indexOf(':');
    if (schemeEndIndex <= 0) {
      throw RdfConstraintViolationException(
        'IRI must be absolute with a scheme component followed by a colon',
        constraint: 'absolute-iri',
      );
    }

    // Validate scheme starts with a letter and contains only allowed characters
    final scheme = iri.substring(0, schemeEndIndex);
    if (!RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*$').hasMatch(scheme)) {
      throw RdfConstraintViolationException(
        'IRI scheme must start with a letter and contain only letters, digits, +, -, or .',
        constraint: 'scheme-format',
      );
    }
  }

  @override
  bool operator ==(Object other) {
    return other is IriTerm && iri.toLowerCase() == other.iri.toLowerCase();
  }

  @override
  int get hashCode => iri.hashCode;

  @override
  String toString() => 'IriTerm($iri)';
}

/// BlankNode (anonymous resource) in RDF
///
/// Blank nodes represent resources that don't need global identification.
/// They are used when we need to represent a resource but don't have or need
/// an IRI for it. Blank nodes are scoped to the document they appear in.
///
/// Blank nodes can appear in subject or object positions, but not as predicates.
///
/// In Turtle syntax, blank nodes are written as `_:label` or as `[]`.
class BlankNodeTerm extends RdfSubject {
  @override
  bool operator ==(Object other) {
    // Yes, this is the default implementation, but because it is so crucial
    // here we make it explicit - BlankNodeTerm *must* be compared by identity,
    // never by any label that may be associated with it in serialized form.
    return identical(this, other);
  }

  @override
  int get hashCode => identityHashCode(this);

  @override
  String toString() => 'BlankNodeTerm(${identityHashCode(this)})';
}

/// Literal value in RDF
///
/// Literals represent values like strings, numbers, dates, etc. Each literal
/// has a lexical value (string) and a datatype IRI that defines how to interpret
/// the string. Additionally, string literals can have language tags.
///
/// Literals can only appear in the object position of a triple, never as subjects
/// or predicates.
///
/// Examples in Turtle syntax:
/// - Simple string: `"Hello World"`
/// - Typed number: `"42"^^xsd:integer`
/// - Language-tagged string: `"Hello"@en`
class LiteralTerm extends RdfObject {
  /// The lexical value of the literal as a string
  final String value;

  /// The datatype IRI defining the literal's type
  final IriTerm datatype;

  /// Optional language tag for language-tagged string literals
  final String? language;

  /// Create a literal with optional datatype or language tag
  ///
  /// According to the RDF 1.1 specification:
  /// - A literal with a language tag must use rdf:langString datatype
  /// - A literal with rdf:langString datatype must have a language tag
  ///
  /// This constructor enforces those constraints with an assertion.
  const LiteralTerm(this.value, {required this.datatype, this.language})
    : assert(
        (language == null) != (datatype == RdfTypes.langString),
        'Language-tagged literals must use rdf:langString datatype, and rdf:langString must have a language tag',
      );

  /// Create a typed literal with XSD datatype
  ///
  /// This is a convenience factory for creating literals with common XSD types.
  ///
  /// Example:
  /// ```dart
  /// // Create an integer literal
  /// final intLiteral = LiteralTerm.typed("42", "integer");
  ///
  /// // Create a date literal
  /// final dateLiteral = LiteralTerm.typed("2023-04-01", "date");
  /// ```
  factory LiteralTerm.typed(String value, String xsdType) {
    return LiteralTerm(value, datatype: XsdTypes.makeIri(xsdType));
  }

  /// Create a plain string literal
  ///
  /// This is a convenience factory for creating literals with xsd:string datatype.
  ///
  /// Example:
  /// ```dart
  /// // Create a string literal
  /// final stringLiteral = LiteralTerm.string("Hello, World!");
  /// ```
  factory LiteralTerm.string(String value) {
    return LiteralTerm(value, datatype: XsdTypes.string);
  }

  /// Create an integer literal
  ///
  /// This is a convenience factory for creating literals with xsd:integer datatype.
  ///
  /// Example:
  /// ```dart
  /// // Create an integer literal
  /// final intLiteral = LiteralTerm.integer("42");
  /// ```
  factory LiteralTerm.integer(String value) {
    return LiteralTerm(value, datatype: XsdTypes.integer);
  }

  /// Create a decimal literal
  ///
  /// This is a convenience factory for creating literals with xsd:decimal datatype.
  ///
  /// Example:
  /// ```dart
  /// // Create a decimal literal
  /// final decimalLiteral = LiteralTerm.decimal("3.14");
  /// ```
  factory LiteralTerm.decimal(String value) {
    return LiteralTerm(value, datatype: XsdTypes.decimal);
  }

  /// Create a boolean literal
  ///
  /// This is a convenience factory for creating literals with xsd:boolean datatype.
  ///
  /// Example:
  /// ```dart
  /// // Create a boolean literal
  /// final boolLiteral = LiteralTerm.boolean("true");
  /// ```
  factory LiteralTerm.boolean(String value) {
    return LiteralTerm(value, datatype: XsdTypes.boolean);
  }

  /// Create a language-tagged literal
  ///
  /// This is a convenience factory for creating literals with language tags.
  /// These literals use the rdf:langString datatype.
  ///
  /// Example:
  /// ```dart
  /// // Create an English language literal
  /// final enLiteral = LiteralTerm.withLanguage("Hello", "en");
  ///
  /// // Create a German language literal
  /// final deLiteral = LiteralTerm.withLanguage("Hallo", "de");
  /// ```
  factory LiteralTerm.withLanguage(String value, String langTag) {
    return LiteralTerm(value, datatype: RdfTypes.langString, language: langTag);
  }

  @override
  bool operator ==(Object other) {
    return other is LiteralTerm &&
        value == other.value &&
        datatype == other.datatype &&
        language == other.language;
  }

  @override
  int get hashCode => Object.hash(value, datatype, language);

  @override
  String toString() => 'LiteralTerm($value, $datatype, $language)';
}
