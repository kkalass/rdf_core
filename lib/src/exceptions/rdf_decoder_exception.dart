/// RDF Decoder Exception Hierarchy
///
/// Defines a hierarchy of exceptions specific to RDF parsing operations, allowing applications
/// to handle different types of parsing errors with fine-grained control.
///
/// Example usage:
/// ```dart
/// import 'package:rdf_core/src/exceptions/rdf_decoder_exception.dart';
/// try {
///   // decode RDF data
/// } catch (e) {
///   if (e is RdfDecoderException) print(e);
/// }
/// ```
///
/// See also: [RDF 1.1 Concepts - Syntax](https://www.w3.org/TR/rdf11-concepts/#section-syntax)
library exceptions.decoder;

import 'rdf_exception.dart';

/// Base exception class for all RDF decoder-related errors
///
/// This class serves as the parent for all decoder-specific exceptions,
/// adding information about which RDF format was being decoded when the
/// error occurred.
///
/// Decoder implementations should throw subclasses of this exception for
/// specific error conditions, or this exception directly for general
/// parsing errors.
class RdfDecoderException extends RdfException {
  /// Format being decoded when the exception occurred
  ///
  /// This typically contains the MIME type (e.g., "text/turtle") or format name
  /// (e.g., "Turtle") of the RDF serialization being decoded.
  final String format;

  /// Creates a new RDF decoder exception
  ///
  /// Parameters:
  /// - [message]: Required description of the error
  /// - [format]: Required format being decoded
  /// - [cause]: Optional underlying cause of this exception
  /// - [source]: Optional location information where the error occurred
  const RdfDecoderException(
    super.message, {
    required this.format,
    super.cause,
    super.source,
  });

  @override
  String toString() {
    return 'RdfDecoderException($format): $message${source != null ? ' at $source' : ''}${cause != null ? '\nCaused by: $cause' : ''}';
  }
}

/// Exception thrown when the decoder encounters syntax errors in the input
///
/// This exception indicates that the input document contains syntax that violates
/// the rules of the RDF serialization format being decoded. These are typically
/// errors in the document itself, not in the decoder.
///
/// Examples include:
/// - Missing closing tags or delimiters
/// - Invalid escape sequences in strings
/// - Malformed IRIs
/// - Unexpected tokens
class RdfSyntaxException extends RdfDecoderException {
  /// Creates a new RDF syntax exception
  ///
  /// Parameters:
  /// - [message]: Required description of the syntax error
  /// - [format]: Required format being decoded
  /// - [cause]: Optional underlying cause of this exception
  /// - [source]: Optional location information where the error occurred
  const RdfSyntaxException(
    super.message, {
    required super.format,
    super.cause,
    super.source,
  });

  @override
  String toString() {
    return 'RdfSyntaxException($format): $message${source != null ? ' at $source' : ''}${cause != null ? '\nCaused by: $cause' : ''}';
  }
}

/// Exception thrown when the decoder encounters an unsupported feature
///
/// This exception indicates that the input document uses a feature of the
/// RDF serialization format that is valid according to the specification
/// but not implemented by this decoder.
///
/// This differs from a syntax exception in that the document is valid
/// according to the format specification, but contains features beyond
/// what the current implementation supports.
///
/// Examples include:
/// - Advanced language features in Turtle like collections
/// - Complex JSON-LD constructs like context processing
/// - Format extensions or newer specification features
class RdfUnsupportedFeatureException extends RdfDecoderException {
  /// Feature that is not supported
  ///
  /// A short identifier or name of the feature that is not supported.
  final String feature;

  /// Creates a new unsupported feature exception
  ///
  /// Parameters:
  /// - [message]: Required description of why the feature isn't supported
  /// - [feature]: Required identifier of the unsupported feature
  /// - [format]: Required format being decoded
  /// - [cause]: Optional underlying cause of this exception
  /// - [source]: Optional location information where the error occurred
  const RdfUnsupportedFeatureException(
    super.message, {
    required this.feature,
    required super.format,
    super.cause,
    super.source,
  });

  @override
  String toString() {
    return 'RdfUnsupportedFeatureException($format): $feature - $message${source != null ? ' at $source' : ''}${cause != null ? '\nCaused by: $cause' : ''}';
  }
}

/// Exception thrown when the decoder encounters an invalid IRI
///
/// This exception indicates that the input document contains an IRI
/// that doesn't conform to the IRI syntax rules specified in RFC 3987.
///
/// IRIs are fundamental to RDF as they identify resources, so invalid
/// IRIs are treated as a specific error case rather than a general syntax error.
class RdfInvalidIriException extends RdfDecoderException {
  /// The invalid IRI
  ///
  /// The string representation of the IRI that failed validation.
  final String iri;

  /// Creates a new invalid IRI exception
  ///
  /// Parameters:
  /// - [message]: Required description of why the IRI is invalid
  /// - [iri]: Required string representation of the invalid IRI
  /// - [format]: Required format being decoded
  /// - [cause]: Optional underlying cause of this exception
  /// - [source]: Optional location information where the error occurred
  const RdfInvalidIriException(
    super.message, {
    required this.iri,
    required super.format,
    super.cause,
    super.source,
  });

  @override
  String toString() {
    return 'RdfInvalidIriException($format): Invalid IRI "$iri" - $message${source != null ? ' at $source' : ''}${cause != null ? '\nCaused by: $cause' : ''}';
  }
}
