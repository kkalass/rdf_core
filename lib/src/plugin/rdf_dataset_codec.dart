/// RDF Dataset Codec Plugin System - Extensible support for RDF dataset serialization formats
///
/// This file defines the plugin architecture that enables the RDF library to support
/// multiple dataset serialization formats through a unified API, based on the dart:convert
/// framework classes. It implements the Strategy pattern to allow different
/// decoding and encoding strategies to be selected at runtime.
///
/// The plugin system allows:
/// - Registration of dataset codec implementations (N-Quads, TriG, etc.)
/// - Codec auto-detection based on content
/// - Codec selection based on MIME type
/// - A unified API for decoding and encoding datasets regardless of format
///
/// Key components:
/// - [RdfDatasetCodec]: Abstract base class for RDF dataset format implementations
/// - [RdfDatasetCodecRegistry]: Central registry for dataset format plugins and auto-detection
/// - [AutoDetectingDatasetCodec]: Special codec that auto-detects dataset formats when parsing
library;

import 'package:rdf_core/src/dataset/rdf_dataset.dart';
import 'package:rdf_core/src/plugin/rdf_base_codec.dart';
import 'package:rdf_core/src/plugin/rdf_codec_registry.dart';
import 'package:rdf_core/src/rdf_dataset_decoder.dart';
import 'package:rdf_core/src/rdf_dataset_encoder.dart';
import 'package:rdf_core/src/rdf_decoder.dart';
import 'package:rdf_core/src/rdf_encoder.dart';

/// Represents a dataset codec that can be handled by the RDF framework.
///
/// A dataset codec plugin encapsulates all the logic needed to work with a specific
/// RDF dataset serialization format (like N-Quads, TriG, JSON-LD datasets, etc.).
/// It provides both decoding and encoding capabilities for the format.
///
/// To add support for a new RDF dataset format, implement this interface and register
/// an instance with the RdfDatasetCodecRegistry.
///
/// Example of implementing a new dataset format:
/// ```dart
/// class MyCustomDatasetCodec implements RdfDatasetCodec {
///   @override
///   String get primaryMimeType => 'application/x-custom-dataset';
///
///   @override
///   Set<String> get supportedMimeTypes => {primaryMimeType};
///
///   @override
///   RdfDatasetDecoder get decoder => MyCustomDatasetDecoder();
///
///   @override
///   RdfDatasetEncoder get encoder => MyCustomDatasetEncoder();
///
///   @override
///   bool canParse(String content) {
///     // Check if the content appears to be in this dataset format
///     return content.contains('CUSTOM-DATASET-FORMAT');
///   }
///
///   @override
///   RdfDatasetCodec withOptions({
///     RdfDatasetEncoderOptions? encoder,
///     RdfDatasetDecoderOptions? decoder,
///   })  => this;
/// }
/// ```
abstract class RdfDatasetCodec extends RdfCodec<RdfDataset> {
  /// Creates a decoder instance for this codec
  ///
  /// Returns a new instance of a decoder that can convert text in this codec's format
  /// to an RdfDataset object.
  @override
  RdfDatasetDecoder get decoder;

  /// Creates an encoder instance for this codec
  ///
  /// Returns a new instance of an encoder that can convert an RdfDataset
  /// to text in this codec's format.
  @override
  RdfDatasetEncoder get encoder;

  /// Creates a new codec instance with default settings
  const RdfDatasetCodec();

  /// Creates a new codec instance with the specified options
  ///
  /// This method returns a new instance of the codec configured with the
  /// provided encoder and decoder options. The original codec instance remains unchanged.
  ///
  /// The [encoder] parameter contains optional encoder options to customize encoding behavior.
  /// The [decoder] parameter contains optional decoder options to customize decoding behavior.
  ///
  /// Returns a new [RdfDatasetCodec] instance with the specified options applied.
  ///
  /// This follows the immutable configuration pattern, allowing for clean
  /// method chaining and configuration without side effects.
  RdfDatasetCodec withOptions({
    RdfGraphEncoderOptions? encoder,
    RdfGraphDecoderOptions? decoder,
  });
}

/// Manages registration and discovery of RDF dataset codec plugins.
///
/// This registry acts as the central point for dataset codec plugin management, providing
/// a mechanism for plugin registration, discovery, and codec auto-detection.
/// It implements a plugin system that allows the core RDF library to be extended
/// with additional dataset serialization formats.
///
/// Example usage:
/// ```dart
/// // Create a registry
/// final registry = RdfDatasetCodecRegistry();
///
/// // Register dataset format plugins
/// registry.registerDatasetCodec(const NQuadsCodec());
/// registry.registerDatasetCodec(const TrigCodec());
///
/// // Get a codec for a specific MIME type
/// final nquadsCodec = registry.getDatasetCodec('application/n-quads');
///
/// // Or let the system detect the format
/// final autoCodec = registry.getDatasetCodec(); // Will auto-detect
/// ```
final class RdfDatasetCodecRegistry extends BaseRdfCodecRegistry<RdfDataset> {
  /// Creates a new codec registry
  ///
  /// The registry starts empty, with no codecs registered.
  /// Codec implementations must be registered using the registerCodec method.
  RdfDatasetCodecRegistry([List<RdfDatasetCodec> initialCodecs = const []])
      : super() {
    for (final codec in initialCodecs) {
      registerCodec(codec);
    }
  }
}
