/// RDF Core Exceptions Library
///
/// Barrel file exporting all RDF exception types for easy import.
///
/// Example usage:
/// ```dart
/// import 'package:rdf_core/src/exceptions/exceptions.dart';
/// try {
///   // some RDF operation
/// } catch (e) {
///   if (e is RdfException) print(e);
/// }
/// ```
library exceptions.all;

export 'rdf_exception.dart';
export 'rdf_decoder_exception.dart';
export 'rdf_encoder_exception.dart';
export 'rdf_validation_exception.dart';
