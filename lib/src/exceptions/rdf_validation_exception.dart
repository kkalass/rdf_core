/// RDF Validation Exception Hierarchy
///
/// Defines exceptions for RDF data validation, allowing applications to handle cases where RDF data
/// does not conform to expected constraints or data models. Focuses on semantic errors and structure issues.
///
/// Example usage:
/// ```dart
/// import 'package:rdf_core/src/exceptions/rdf_validation_exception.dart';
/// try {
///   // validate RDF graph
/// } catch (e) {
///   if (e is RdfValidationException) print(e);
/// }
/// ```
///
/// See also: [SHACL - Shapes Constraint Language](https://www.w3.org/TR/shacl/)
library exceptions.validation;

import 'rdf_exception.dart';

/// Base exception class for all RDF validation-related errors
///
/// This class serves as the parent for all validation-specific exceptions,
/// covering issues where RDF data is syntactically valid but semantically
/// problematic according to some validation rules or constraints.
///
/// Validation may include checking against RDFS/OWL schemas, SHACL shapes,
/// application-specific constraints, or other semantic rules for RDF data.
class RdfValidationException extends RdfException {
  /// Creates a new RDF validation exception
  ///
  /// Parameters:
  /// - [message]: Required description of the validation error
  /// - [cause]: Optional underlying cause of this exception
  /// - [source]: Optional location information where the error was detected
  const RdfValidationException(super.message, {super.cause, super.source});

  @override
  String toString() {
    return 'RdfValidationException: $message${source != null ? ' at $source' : ''}${cause != null ? '\nCaused by: $cause' : ''}';
  }
}

/// Exception thrown when an RDF model constraint is violated
///
/// This exception indicates that the RDF data violates a specific constraint
/// defined in a data model, schema, or application logic. These are semantic errors
/// where the data is syntactically valid but doesn't comply with higher-level rules.
///
/// Examples include:
/// - Cardinality violations (e.g., missing a required property)
/// - Value range violations (e.g., numeric value out of allowed range)
/// - Pattern constraints (e.g., string not matching a required pattern)
/// - Graph structure constraints (e.g., missing a required relationship)
class RdfConstraintViolationException extends RdfValidationException {
  /// The name of the violated constraint
  ///
  /// An identifier for the specific constraint that was violated.
  /// This can be a formal constraint name from a schema or a descriptive identifier.
  final String constraint;

  /// Creates a new constraint violation exception
  ///
  /// Parameters:
  /// - [message]: Required description of how the constraint was violated
  /// - [constraint]: Required identifier of the violated constraint
  /// - [cause]: Optional underlying cause of this exception
  /// - [source]: Optional location information where the error was detected
  const RdfConstraintViolationException(
    super.message, {
    required this.constraint,
    super.cause,
    super.source,
  });

  @override
  String toString() {
    return 'RdfConstraintViolationException: $constraint - $message${source != null ? ' at $source' : ''}${cause != null ? '\nCaused by: $cause' : ''}';
  }
}

/// Exception thrown when there's a type error in RDF data
///
/// This exception indicates that a value in the RDF data doesn't match
/// the expected type according to a schema, ontology, or application logic.
/// Type errors are a common subset of constraint violations that deal specifically
/// with datatype mismatches.
///
/// Examples include:
/// - A literal with the wrong XSD datatype
/// - A resource that doesn't conform to its expected class
/// - A value that can't be properly interpreted as the required type
class RdfTypeException extends RdfValidationException {
  /// Expected type
  ///
  /// The type that was expected according to the validation rules.
  /// This is typically an XSD datatype URI or an ontology class URI.
  final String expectedType;

  /// Actual type found
  ///
  /// The type that was actually found in the data, if it could be determined.
  /// This may be null if the type couldn't be determined or is entirely absent.
  final String? actualType;

  /// Creates a new RDF type exception
  ///
  /// Parameters:
  /// - [message]: Required description of the type error
  /// - [expectedType]: Required identifier of the expected type
  /// - [actualType]: Optional identifier of the actual type found
  /// - [cause]: Optional underlying cause of this exception
  /// - [source]: Optional location information where the error was detected
  const RdfTypeException(
    super.message, {
    required this.expectedType,
    this.actualType,
    super.cause,
    super.source,
  });

  @override
  String toString() {
    final typeInfo = actualType != null
        ? 'Expected: $expectedType, Found: $actualType'
        : 'Expected: $expectedType';
    return 'RdfTypeException: $typeInfo - $message${source != null ? ' at $source' : ''}${cause != null ? '\nCaused by: $cause' : ''}';
  }
}

/// Exception thrown when an RDF graph doesn't conform to a specified shape
///
/// This exception is specifically for cases where validation against formal
/// shape definitions (like SHACL or ShEx) fails. It provides information about
/// which shapes were violated and why.
class RdfShapeValidationException extends RdfValidationException {
  /// The identifier of the shape that was violated
  ///
  /// Typically an IRI identifying the shape definition.
  final String shapeId;

  /// The target node that failed validation
  ///
  /// The IRI or blank node identifier of the resource that did not conform to the shape.
  final String targetNode;

  /// Creates a new shape validation exception
  ///
  /// Parameters:
  /// - [message]: Required description of the validation failure
  /// - [shapeId]: Required identifier of the violated shape
  /// - [targetNode]: Required identifier of the non-conforming node
  /// - [cause]: Optional underlying cause of this exception
  /// - [source]: Optional location information where the error was detected
  const RdfShapeValidationException(
    super.message, {
    required this.shapeId,
    required this.targetNode,
    super.cause,
    super.source,
  });

  @override
  String toString() {
    return 'RdfShapeValidationException: Node $targetNode failed to conform to shape $shapeId - $message${source != null ? ' at $source' : ''}${cause != null ? '\nCaused by: $cause' : ''}';
  }
}
