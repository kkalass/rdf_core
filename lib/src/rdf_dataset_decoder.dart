/// RDF Dataset Decoder Interface & Utilities
///
/// Defines the interface and utilities for decoding RDF dataset data from various string formats.
///
/// See: [RDF 1.1 Concepts - Syntax](https://www.w3.org/TR/rdf11-concepts/#section-syntax)
library;

import 'package:rdf_core/src/dataset/rdf_dataset.dart';
import 'package:rdf_core/src/rdf_decoder.dart';

/// Configuration options for RDF dataset decoders
///
/// This class provides configuration options that can be passed to RDF dataset decoders
/// to modify their parsing behavior. Concrete implementations may extend this
/// class to provide format-specific options.
///
/// The base implementation provides no options, but serves as an extension point
/// for format-specific configuration.
class RdfDatasetDecoderOptions extends RdfGraphDecoderOptions {
  /// Creates default decoder options with no special configurations
  const RdfDatasetDecoderOptions();
}

/// Base class for decoding RDF dataset documents in various serialization formats
///
/// This abstract class extends the standard `Converter` interface to provide
/// a common API for decoding different RDF dataset string serializations (such as N-Quads,
/// TriG, JSON-LD datasets, etc.). Each format implements this interface to
/// handle its specific syntax rules and parsing behavior.
///
/// Dataset format-specific decoders should implement this base class to be compatible with
/// the RDF library's parsing framework and to ensure consistent behavior across
/// different dataset formats.
///
/// Example:
/// ```dart
/// final nquadsDecoder = NQuadsDecoder();
/// final dataset = nquadsDecoder.convert('<http://example.org/s> <http://example.org/p> "object" <http://example.org/g> .');
/// ```
abstract class RdfDatasetDecoder extends RdfDecoder<RdfDataset> {
  const RdfDatasetDecoder();

  /// Decodes an RDF dataset document and returns an RDF dataset
  ///
  /// This method transforms a textual RDF dataset document into a structured `RdfDataset` object
  /// containing quads parsed from the input and organized into default and named graphs.
  /// It implements the `convert` method from the `Converter` interface.
  ///
  /// Parameters:
  /// - [input] The RDF dataset document to decode, as a string.
  /// - [documentUrl] The absolute URL of the document, used for resolving relative IRIs.
  ///   If not provided, relative IRIs will be kept as-is or handled according to format-specific rules.
  ///
  /// Returns:
  /// - An [RdfDataset] containing the quads parsed from the input, organized into graphs.
  ///
  /// The specific decoding behavior depends on the implementation of this interface,
  /// which will handle format-specific details like prefix resolution, blank node handling,
  /// and graph context management, etc.
  ///
  /// May throw format-specific parsing exceptions if the input is malformed.
  @override
  RdfDataset convert(String input, {String? documentUrl});

  /// Creates a new decoder with the specified options
  ///
  /// This method returns a new instance of the decoder configured with the
  /// provided options. The original decoder instance remains unchanged.
  ///
  /// Parameters:
  /// - [options] Configuration options to customize the decoder's behavior.
  ///
  /// Returns:
  /// - A new [RdfDatasetDecoder] instance with the specified options applied.
  ///
  /// This pattern allows for immutable configuration of decoders and enables
  /// method chaining for readable configuration code.
  RdfDatasetDecoder withOptions(RdfGraphDecoderOptions options);
}
