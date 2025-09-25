/// RDF Term Types
///
/// Defines the core RDF term types: [RdfTerm], [RdfSubject], [RdfPredicate], [RdfObject], [IriTerm], [BlankNodeTerm], [LiteralTerm].
///
/// Example usage:
/// ```dart
/// import 'package:rdf_core/src/graph/rdf_term.dart';
/// final subject = IriTerm.validated('http://example.org/subject');
///
/// // Advanced: create a blank node (uses identity hash code)
/// final bnode = BlankNodeTerm();
///
/// // Advanced: create a literal
/// final literal = LiteralTerm('42', datatype: Xsd.int);
///
/// // Type checking
/// if (term is IriTerm) print('It is an IRI!');
///
/// // Equality
/// final a = IriTerm.validated('x');
/// final b = IriTerm.validated('x');
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

sealed class RdfGraphName extends RdfSubject {
  const RdfGraphName();
}

/// Base type for values that can appear in the predicate position of a triple
///
/// In RDF, predicates can only be IRIs.
sealed class RdfPredicate extends RdfTerm {
  const RdfPredicate();
}

typedef IriTermFactory = IriTerm Function(String iri);

/// IRI (Internationalized Resource Identifier) in RDF
///
/// IRIs are used to identify resources in the RDF data model. They are
/// global identifiers that can refer to documents, concepts, or physical entities.
///
/// IRIs can be used in any position in a triple: subject, predicate, or object.
///
/// Example: `http://example.org/person/john` or `http://xmlns.com/foaf/0.1/name`
class IriTerm extends RdfPredicate implements RdfGraphName {
  /// The string representation of the IRI
  final String value;

  @Deprecated('Use value property instead')
  String get iri => value;

  /// Creates an IRI term from a prevalidated IRI string.
  ///
  /// Use this constructor only when you are sure the IRI is valid and absolute
  /// and need to create a const instance.
  /// This is useful for performance optimization.
  const IriTerm(this.value);

  /// Creates an IRI term with the specified IRI string
  ///
  /// The IRI should be a valid absolute IRI according to RFC 3987.
  /// This constructor validates that the IRI is well-formed and absolute.
  ///
  /// Throws [RdfConstraintViolationException] if the IRI is not well-formed
  /// or not absolute.
  ///
  /// If you need to create an IRI in a const context (e.g., for annotations),
  /// use the [IriTerm] constructor instead, but ensure the IRI
  /// is valid at compile time.
  IriTerm.validated(this.value) {
    _validateAbsoluteIri(value);
  }

  /// Ensures the IRI is valid and absolute - useful for late validation if
  /// you assume that the const constructor was used without validation.
  void ensureValid() {
    _validateAbsoluteIri(value);
  }

  factory IriTerm.encodeFull(String rawIri) {
    return IriTerm.validated(Uri.encodeFull(rawIri));
  }

  /// Creates an IRI term from a prevalidated IRI string.
  ///
  /// Use this constructor only when you are sure the IRI is valid and absolute
  /// and need to create a const instance.
  /// This is useful for performance optimization.
  @Deprecated('Use IriTerm constructor instead')
  const IriTerm.prevalidated(this.value);

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
    if (iri.contains(" ")) {
      throw RdfConstraintViolationException(
        'IRI cannot contain spaces',
        constraint: 'iri-format',
      );
    }
  }

  @override
  bool operator ==(Object other) {
    return other is IriTerm && value == other.value;
  }

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => '<$value>';
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
class BlankNodeTerm extends RdfGraphName {
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
  String toString() => '_:b${identityHashCode(this)}';
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
/// In RDF 1.1, all literals have a datatype:
/// - Plain literals use xsd:string by default
/// - Language-tagged literals use rdf:langString
/// - Typed literals use an explicit datatype IRI (typically an XSD datatype)
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

  /// Creates a literal with an optional datatype or language tag
  ///
  /// This is the primary constructor for creating RDF literals. It handles
  /// the complex rules of the RDF 1.1 specification regarding datatypes and language tags:
  ///
  /// - If [datatype] is provided, it is used as the literal's datatype
  /// - If [language] is provided but no datatype, rdf:langString is used automatically
  /// - If neither datatype nor language is provided, xsd:string is used by default
  ///
  /// According to the RDF 1.1 specification:
  /// - A literal with a language tag must use rdf:langString datatype
  /// - A literal with rdf:langString datatype must have a language tag
  ///
  /// This constructor enforces these constraints with an assertion.
  ///
  /// Example:
  /// ```dart
  /// // Simple string literal (implicit xsd:string datatype)
  /// final plainLiteral = LiteralTerm('Hello');
  ///
  /// // Typed literal
  /// final intLiteral = LiteralTerm('42', datatype: Xsd.integer);
  ///
  /// // Language-tagged string (implicit rdf:langString datatype)
  /// final langLiteral = LiteralTerm('Bonjour', language: 'fr');
  /// ```
  const LiteralTerm(this.value, {IriTerm? datatype, this.language})
      : assert(
          datatype == null ||
              (language == null && datatype != Rdf.langString) ||
              (language != null && datatype == Rdf.langString),
          'Language-tagged literals must use rdf:langString datatype, and rdf:langString must have a language tag',
        ),
        datatype = datatype != null
            ? datatype
            : (language == null ? Xsd.string : Rdf.langString);

  /// Create a typed literal with XSD datatype
  ///
  /// This is a convenience factory for creating literals with XSD datatypes.
  /// It accepts any XSD type name and uses the [Xsd.makeIri] method to resolve
  /// the full datatype IRI.
  ///
  /// Common XSD types include:
  /// - `string` - String values
  /// - `integer` - Integer values
  /// - `decimal` - Decimal numbers
  /// - `boolean` - Boolean values (true/false)
  /// - `date` - ISO date (YYYY-MM-DD)
  /// - `dateTime` - ISO date and time with timezone
  /// - `time` - ISO time
  /// - `anyURI` - URI values
  ///
  /// Parameters:
  /// - [value] The lexical value as a string
  /// - [xsdType] The XSD type name (without the xsd: prefix)
  ///
  /// Example:
  /// ```dart
  /// // Create an integer literal
  /// final intLiteral = LiteralTerm.typed("42", "integer");
  ///
  /// // Create a date literal
  /// final dateLiteral = LiteralTerm.typed("2023-04-01", "date");
  ///
  /// // Create a boolean literal
  /// final boolLiteral = LiteralTerm.typed("true", "boolean");
  /// ```
  factory LiteralTerm.typed(String value, String xsdType) {
    return LiteralTerm(value, datatype: Xsd.makeIri(xsdType));
  }

  /// Create a plain string literal
  ///
  /// This is a convenience factory for creating literals with xsd:string datatype.
  /// In RDF, plain string literals use the xsd:string datatype, which is also
  /// the default when no datatype is specified.
  ///
  /// Note: This factory is equivalent to using the primary constructor without
  /// any datatype or language parameters, but makes the intent clearer in the code.
  ///
  /// Parameters:
  /// - [value] The string value
  ///
  /// Example:
  /// ```dart
  /// // Create a string literal
  /// final stringLiteral = LiteralTerm.string("Hello, World!");
  ///
  /// // The following two literals are equivalent
  /// final a = LiteralTerm.string("Hello");
  /// final b = LiteralTerm("Hello");
  /// ```
  factory LiteralTerm.string(String value) {
    return LiteralTerm(value, datatype: Xsd.string);
  }

  /// Create an integer literal
  ///
  /// This is a convenience factory for creating literals with xsd:integer datatype.
  /// Integer literals in RDF represent whole numbers without fractional components.
  ///
  /// Parameters:
  /// - [value] The integer value to encode as a literal
  ///
  /// Returns:
  /// A new [LiteralTerm] with value converted to string and datatype set to xsd:integer
  ///
  /// Example:
  /// ```dart
  /// // Create an integer literal
  /// final intLiteral = LiteralTerm.integer(42);
  ///
  /// // Equivalent to manually creating a typed literal
  /// final manualInt = LiteralTerm("42", datatype: Xsd.integer);
  /// ```
  factory LiteralTerm.integer(int value) {
    return LiteralTerm(value.toString(), datatype: Xsd.integer);
  }

  /// Create a decimal literal
  ///
  /// This is a convenience factory for creating literals with xsd:decimal datatype.
  /// Decimal literals in RDF represent numeric values that can have fractional parts.
  ///
  /// Parameters:
  /// - [value] The double value to encode as a decimal literal
  ///
  /// Returns:
  /// A new [LiteralTerm] with value converted to string and datatype set to xsd:decimal
  ///
  /// Note:
  /// Be aware that floating-point representation may lead to precision issues in
  /// some cases. For exact decimal representation, consider converting the value
  /// to a string with the desired precision before creating the literal.
  ///
  /// Example:
  /// ```dart
  /// // Create a decimal literal
  /// final decimalLiteral = LiteralTerm.decimal(3.14);
  ///
  /// // Equivalent to manually creating a typed literal
  /// final manualDecimal = LiteralTerm("3.14", datatype: Xsd.decimal);
  /// ```
  factory LiteralTerm.decimal(double value) {
    return LiteralTerm(value.toString(), datatype: Xsd.decimal);
  }

  /// Create a boolean literal
  ///
  /// This is a convenience factory for creating literals with xsd:boolean datatype.
  /// Boolean literals in RDF represent truth values (true or false).
  ///
  /// Parameters:
  /// - [value] The boolean value to encode as a literal
  ///
  /// Returns:
  /// A new [LiteralTerm] with value converted to string and datatype set to xsd:boolean
  ///
  /// Note:
  /// The value will be serialized as the string "true" or "false" as per XSD boolean
  /// representation rules.
  ///
  /// Example:
  /// ```dart
  /// // Create a boolean literal
  /// final trueLiteral = LiteralTerm.boolean(true);
  /// final falseLiteral = LiteralTerm.boolean(false);
  ///
  /// // Equivalent to manually creating a typed literal
  /// final manualBool = LiteralTerm("true", datatype: Xsd.boolean);
  /// ```
  factory LiteralTerm.boolean(bool value) {
    return LiteralTerm(value.toString(), datatype: Xsd.boolean);
  }

  /// Create a language-tagged literal
  ///
  /// This is a convenience factory for creating literals with language tags.
  /// These literals use the rdf:langString datatype as required by the RDF 1.1 specification.
  ///
  /// Parameters:
  /// - [value] The string value of the literal
  /// - [langTag] The language tag (e.g., "en", "de", "fr-CA") following BCP 47 format
  ///
  /// Returns:
  /// A new [LiteralTerm] with the specified value, rdf:langString datatype, and language tag
  ///
  /// Note:
  /// Language tags are case-insensitive according to the RDF specification, but it's
  /// recommended to use lowercase for language subtags (e.g., "en-us" rather than "en-US")
  /// for maximum compatibility.
  ///
  /// Example:
  /// ```dart
  /// // Create an English language literal
  /// final enLiteral = LiteralTerm.withLanguage("Hello", "en");
  ///
  /// // Create a German language literal
  /// final deLiteral = LiteralTerm.withLanguage("Hallo", "de");
  ///
  /// // Create a Canadian French literal with region subtag
  /// final frCALiteral = LiteralTerm.withLanguage("Bonjour", "fr-ca");
  /// ```
  factory LiteralTerm.withLanguage(String value, String langTag) {
    return LiteralTerm(value, datatype: Rdf.langString, language: langTag);
  }

  /// Compares this literal term with another object for equality.
  ///
  /// Two literal terms are equal if they have the same lexical value,
  /// the same datatype, and the same language tag (if present).
  ///
  /// This follows the RDF 1.1 specification's definition of literal equality,
  /// which is based on the lexical value rather than any derived value.
  /// For example, "01"^^xsd:integer and "1"^^xsd:integer are not equal
  /// even though they represent the same number.
  @override
  bool operator ==(Object other) {
    return other is LiteralTerm &&
        value == other.value &&
        datatype == other.datatype &&
        language == other.language;
  }

  /// Provides a consistent hash code for this literal term based on its components.
  ///
  /// The hash code is calculated from the combined hash of the value, datatype,
  /// and language (if present), ensuring that two equal literal terms will have
  /// the same hash code, which is required for proper behavior when used in hash-based
  /// collections like sets and maps.
  @override
  int get hashCode => Object.hash(value, datatype, language);

  /// Returns a string representation of this literal term in a Turtle-like syntax.
  ///
  /// The output format follows Turtle serialization rules:
  /// - Plain string literals (xsd:string): `"value"`
  /// - Language-tagged literals: `"value"@language`
  /// - Other typed literals: `"value"^^<datatype>`
  ///
  /// This representation is useful for debugging and logging purposes.
  /// Note that the actual format in serialized RDF will depend on the
  /// specific serialization format being used.
  ///
  /// Example:
  /// ```dart
  /// final plainLiteral = LiteralTerm.string("Hello");
  /// print(plainLiteral); // Prints: "Hello"
  ///
  /// final langLiteral = LiteralTerm.withLanguage("Bonjour", "fr");
  /// print(langLiteral); // Prints: "Bonjour"@fr
  ///
  /// final typedLiteral = LiteralTerm.integer(42);
  /// print(typedLiteral); // Prints: "42"^^<http://www.w3.org/2001/XMLSchema#integer>
  /// ```
  @override
  String toString() => language != null
      ? '"$value"@$language'
      : datatype == Xsd.string
          ? '"$value"'
          : '"$value"^^$datatype';
}
