/// RDF Dataset Encoding Framework - Components for writing RDF dataset data in various formats
///
/// This file defines interfaces and implementations for encoding RDF dataset data
/// from in-memory dataset structures to various text-based serialization formats.
/// It complements the dataset decoder framework by providing the reverse operation.
library;

import 'package:rdf_core/src/dataset/rdf_dataset.dart';
import 'package:rdf_core/src/rdf_encoder.dart';

/// Configuration options for RDF dataset encoders.
///
/// This class provides configuration parameters that can be used to customize
/// the behavior of RDF dataset encoders. It follows the Options pattern to encapsulate
/// encoder-specific settings.
class RdfDatasetEncoderOptions extends RdfGraphEncoderOptions {
  /// Creates a new encoder options instance.
  ///
  /// Parameters:
  /// - [customPrefixes] Custom namespace prefixes to use during encoding.
  ///   Defaults to an empty map if not provided.
  /// - [iriRelativization] Options for IRI relativization behavior.
  ///   Defaults to full relativization with length constraints for optimal balance.
  const RdfDatasetEncoderOptions({
    super.customPrefixes = const {},
    super.iriRelativization = const IriRelativizationOptions.full(),
  });

  /// Creates a copy of this options instance with the specified overrides.
  ///
  /// This method follows the copyWith pattern commonly used in Dart for creating
  /// modified copies of immutable objects while preserving the original instance.
  ///
  /// Parameters:
  /// - [customPrefixes] New custom prefixes to use. If null, the current value is retained.
  /// - [iriRelativization] New relativization options. If null, the current value is retained.
  ///
  /// Returns:
  /// - A new [RdfDatasetEncoderOptions] instance with the specified modifications.
  RdfDatasetEncoderOptions copyWith({
    Map<String, String>? customPrefixes,
    IriRelativizationOptions? iriRelativization,
  }) =>
      RdfDatasetEncoderOptions(
        customPrefixes: customPrefixes ?? this.customPrefixes,
        iriRelativization: iriRelativization ?? this.iriRelativization,
      );
}

/// Interface for encoding RDF datasets to different serialization formats.
///
/// This base class defines the contract for encoding RDF datasets into textual
/// representations using various formats like N-Quads, TriG, etc. It's part of
/// the Strategy pattern implementation that allows the library to support multiple
/// dataset encoding formats.
///
/// Dataset format-specific encoders should extend this base class to be registered
/// with the RDF library's codec framework.
///
/// Dataset encoders are responsible for:
/// - Determining how to represent quads and graph context in their specific format
/// - Handling namespace prefixes and base URIs
/// - Applying format-specific optimizations for readability or size
/// - Managing default graph and named graph serialization
abstract class RdfDatasetEncoder extends RdfEncoder<RdfDataset> {
  const RdfDatasetEncoder();

  /// Encodes an RDF dataset to a string representation in a specific format.
  ///
  /// Transforms an in-memory RDF dataset into an encoded text format that can be
  /// stored or transmitted. The exact output format depends on the implementing class.
  ///
  /// Parameters:
  /// - [dataset] The RDF dataset to encode.
  /// - [baseUri] Optional base URI for resolving/shortening IRIs in the output.
  ///   When provided, the encoder may use this to produce more compact output.
  ///
  /// Returns:
  /// - The serialized representation of the dataset as a string.
  String convert(RdfDataset dataset, {String? baseUri});

  /// Creates a new encoder instance with the specified options.
  ///
  /// This method follows the Builder pattern to create a new encoder configured with
  /// the given options. It allows for customizing the encoding behavior without
  /// modifying the original encoder instance.
  ///
  /// Parameters:
  /// - [options] The encoder options to apply, including [RdfDatasetEncoderOptions.customPrefixes] for
  ///   namespace handling.
  ///
  /// Returns:
  /// - A new encoder instance with the specified options applied.
  RdfDatasetEncoder withOptions(RdfGraphEncoderOptions options);
}
