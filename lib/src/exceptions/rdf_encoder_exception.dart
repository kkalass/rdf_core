/// RDF Encoder Exception Hierarchy
///
/// Defines exceptions specific to RDF encoding operations, allowing applications to handle
/// errors that occur when converting RDF graphs to specific encoding formats.
///
/// Example usage:
/// ```dart
/// import 'package:rdf_core/src/exceptions/rdf_encoder_exception.dart';
/// try {
///   // encode RDF graph
/// } catch (e) {
///   if (e is RdfEncoderException) print(e);
/// }
/// ```
///
/// See also: [RDF 1.1 Concepts - Encoding](https://www.w3.org/TR/rdf11-concepts/#section-encoding)
library exceptions.encoder;

import 'rdf_exception.dart';

/// Base exception class for all RDF encoding-related errors
///
/// This class serves as the parent for all encoder-specific exceptions,
/// adding information about which RDF format was the target of encoding
/// when the error occurred.
///
/// Encoder implementations should throw subclasses of this exception for
/// specific error conditions, or this exception directly for general
/// encoding errors.
class RdfEncoderException extends RdfException {
  /// Format being encoded to when the exception occurred
  ///
  /// This typically contains the MIME type (e.g., "text/turtle") or format name
  /// (e.g., "Turtle") of the target RDF encoding.
  final String format;

  /// Creates a new RDF encoder exception
  ///
  /// Parameters:
  /// - [message]: Required description of the error
  /// - [format]: Required target encoding format
  /// - [cause]: Optional underlying cause of this exception
  /// - [source]: Optional location information where the error occurred
  const RdfEncoderException(
    super.message, {
    required this.format,
    super.cause,
    super.source,
  });

  @override
  String toString() {
    return 'RdfEncoderException($format): $message${source != null ? ' at $source' : ''}${cause != null ? '\nCaused by: $cause' : ''}';
  }
}

/// Exception thrown when the encoder cannot represent a feature in the target format
///
/// This exception indicates that the RDF graph contains structures or values that
/// cannot be fully represented in the target encoder format due to limitations
/// of that format or the implementation.
///
/// Unlike parser exceptions, these issues arise not from invalid input but from
/// the limitations of the target format or the encoder implementation.
///
/// Examples include:
/// - RDF constructs that don't have a direct representation in the target format
/// - Complex graph patterns that the encoder doesn't support optimizing
/// - Format-specific limitations (e.g., character set restrictions)
class RdfUnsupportedEncoderFeatureException extends RdfEncoderException {
  /// Feature that is not supported
  ///
  /// A short identifier or description of the unsupported feature or construct.
  final String feature;

  /// Creates a new unsupported encoding feature exception
  ///
  /// Parameters:
  /// - [message]: Required explanation of why the feature can't be encoded
  /// - [feature]: Required identifier of the unsupported feature
  /// - [format]: Required target encoding format
  /// - [cause]: Optional underlying cause of this exception
  /// - [source]: Optional location information in the RDF graph
  const RdfUnsupportedEncoderFeatureException(
    super.message, {
    required this.feature,
    required super.format,
    super.cause,
    super.source,
  });

  @override
  String toString() {
    return 'RdfUnsupportedEncoderFeatureException($format): $feature - $message${source != null ? ' at $source' : ''}${cause != null ? '\nCaused by: $cause' : ''}';
  }
}

/// Exception thrown when the graph contains cycles that prevent encoding
///
/// Some RDF formats have limitations with cyclic structures, particularly
/// when using abbreviated syntax. This exception indicates that the graph
/// contains cyclical relationships that prevent effective encoding
/// in the target format.
class RdfCyclicGraphException extends RdfEncoderException {
  /// Creates a new cyclic graph exception
  ///
  /// Parameters:
  /// - [message]: Required explanation of the cycle issue
  /// - [format]: Required target encoding format
  /// - [cause]: Optional underlying cause of this exception
  /// - [source]: Optional location information in the RDF graph
  const RdfCyclicGraphException(
    super.message, {
    required super.format,
    super.cause,
    super.source,
  });

  @override
  String toString() {
    return 'RdfCyclicGraphException($format): $message${source != null ? ' at $source' : ''}${cause != null ? '\nCaused by: $cause' : ''}';
  }
}
