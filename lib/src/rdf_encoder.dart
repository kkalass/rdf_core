/// RDF Encoding Framework - Components for writing RDF data in various formats
///
/// This file defines interfaces and implementations for encoding RDF data
/// from in-memory graph structures to various text-based serialization formats.
/// It complements the decoder framework by providing the reverse operation.
library;

import 'dart:convert';

import 'graph/rdf_graph.dart';

/// Configuration options for IRI relativization behavior.
///
/// Controls how IRIs are relativized when a base IRI is provided during encoding.
/// Relativization can make RDF serializations more compact and readable by
/// expressing IRIs relative to a base, but different use cases may prefer
/// different levels of aggressiveness.
class IriRelativizationOptions {
  /// Maximum number of "../" path components allowed in relative paths.
  ///
  /// Higher values allow more aggressive relativization but may reduce readability.
  /// Setting to 0 disables cross-directory navigation entirely, allowing only
  /// same-directory and child directory relativization.
  ///
  /// Examples:
  /// - -1: Special value to disable all relativization (use absolute IRIs only)
  /// - 0: Only same-directory and child directory relativization
  /// - 1: Allow one level up (../file.txt)
  /// - 2: Allow two levels up (../../file.txt)
  /// - null: No limit
  final int? maxUpLevels;

  /// Maximum additional length allowed for relative paths compared to absolute paths.
  ///
  /// Sometimes relative paths can be longer than absolute paths, especially
  /// with deep "../../../" structures. This option limits how much longer
  /// a relative path can be before falling back to absolute.
  ///
  /// Set to null to disable length checking entirely.
  final int? maxAdditionalLength;

  /// Whether to allow relativization between sibling directories with no common parent.
  ///
  /// When true, allows patterns like "../sibling/file.txt"
  /// When false, only allows relativization when there's a shared directory structure.
  final bool allowSiblingDirectories;

  /// Creates new IRI relativization options with explicit configuration.
  ///
  /// All parameters are required to avoid ambiguity. For common use cases,
  /// prefer the semantic constructors: [none], [local], or [full].
  ///
  /// Parameters:
  /// - [maxUpLevels] Maximum "../" components allowed (null for unlimited)
  /// - [maxAdditionalLength] Maximum extra length vs absolute
  /// - [allowSiblingDirectories] Allow ../sibling patterns
  const IriRelativizationOptions({
    required this.maxUpLevels,
    required this.maxAdditionalLength,
    required this.allowSiblingDirectories,
  });

  /// No relativization - always use absolute IRIs.
  ///
  /// Produces only absolute IRIs for maximum clarity and unambiguity.
  /// Useful for debugging, documentation, or when absolute references are required.
  const IriRelativizationOptions.none()
      : maxUpLevels = -1, // Special flag to disable all relativization
        maxAdditionalLength = 0,
        allowSiblingDirectories = false;

  /// Local relativization - same directory and child directories only.
  ///
  /// Allows relative paths within the current directory and subdirectories.
  /// Produces paths like "file.txt" and "subdir/file.txt" but never "../file.txt".
  /// Provides safe, predictable relativization for security-sensitive contexts.
  const IriRelativizationOptions.local()
      : maxUpLevels = 0,
        maxAdditionalLength = 0,
        allowSiblingDirectories = false;

  /// Full relativization - allow any valid relative path structure.
  ///
  /// Enables maximum relativization including complex navigation patterns.
  /// Produces paths like "../sibling/file.txt" and "../../other/file.txt".
  /// Prioritizes compactness while still respecting length constraints. Will
  /// fall back to absolute IRIs if the length of the relative path exceeds the
  /// length of the absolute IRI.
  const IriRelativizationOptions.full()
      : maxUpLevels = null,
        maxAdditionalLength = 0,
        allowSiblingDirectories = true;

  /// Creates a copy of these options with specified overrides.
  ///
  /// Follows the standard copyWith pattern for immutable configuration objects.
  IriRelativizationOptions copyWith({
    int? maxUpLevels,
    int? maxAdditionalLength,
    bool? allowSiblingDirectories,
  }) =>
      IriRelativizationOptions(
        maxUpLevels: maxUpLevels ?? this.maxUpLevels,
        maxAdditionalLength: maxAdditionalLength ?? this.maxAdditionalLength,
        allowSiblingDirectories:
            allowSiblingDirectories ?? this.allowSiblingDirectories,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IriRelativizationOptions &&
          runtimeType == other.runtimeType &&
          maxUpLevels == other.maxUpLevels &&
          maxAdditionalLength == other.maxAdditionalLength &&
          allowSiblingDirectories == other.allowSiblingDirectories;

  @override
  int get hashCode =>
      maxUpLevels.hashCode ^
      maxAdditionalLength.hashCode ^
      allowSiblingDirectories.hashCode;

  @override
  String toString() => 'IriRelativizationOptions('
      'maxUpLevels: $maxUpLevels, '
      'maxAdditionalLength: $maxAdditionalLength, '
      'allowSiblingDirectories: $allowSiblingDirectories)';
}

/// Configuration options for RDF graph encoders.
///
/// This class provides configuration parameters that can be used to customize
/// the behavior of RDF graph encoders. It follows the Options pattern to encapsulate
/// encoder-specific settings.
class RdfGraphEncoderOptions {
  /// Custom namespace prefixes to use during encoding.
  ///
  /// A mapping of prefix strings (without colon) to namespace URIs.
  /// These prefixes will be used when possible to produce more readable
  /// and compact output. For example, {'foaf': 'http://xmlns.com/foaf/0.1/'}.
  ///
  /// But note that there is a set of well-known prefixes managed by
  /// [RdfNamespaceMappings] that will be used for well-known IRIs, so you
  /// will need this only rarely and not for well-known IRIs like foaf.
  final Map<String, String> customPrefixes;

  /// Options for controlling IRI relativization behavior.
  ///
  /// When a base IRI is provided during encoding, these options control
  /// how aggressively IRIs are relativized to produce more compact output.
  ///
  /// Available presets:
  /// - [IriRelativizationOptions.none]: No relativization, always use absolute IRIs
  /// - [IriRelativizationOptions.local]: Only same-directory and child directories
  /// - [IriRelativizationOptions.full]: Maximum relativization with length constraints
  ///
  /// For custom configurations, use the default constructor with explicit parameters
  /// or modify existing options with [IriRelativizationOptions.copyWith].
  final IriRelativizationOptions iriRelativization;

  /// Creates a new encoder options instance.
  ///
  /// Parameters:
  /// - [customPrefixes] Custom namespace prefixes to use during encoding.
  ///   Defaults to an empty map if not provided.
  /// - [iriRelativization] Options for IRI relativization behavior.
  ///   Defaults to full relativization with length constraints for optimal balance.
  const RdfGraphEncoderOptions({
    this.customPrefixes = const {},
    this.iriRelativization = const IriRelativizationOptions.full(),
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
  /// - A new [RdfGraphEncoderOptions] instance with the specified modifications.
  RdfGraphEncoderOptions copyWith({
    Map<String, String>? customPrefixes,
    IriRelativizationOptions? iriRelativization,
  }) =>
      RdfGraphEncoderOptions(
        customPrefixes: customPrefixes ?? this.customPrefixes,
        iriRelativization: iriRelativization ?? this.iriRelativization,
      );
}

/// Interface for encoding RDF graphs to different serialization formats.
///
/// This base class defines the contract for encoding RDF graphs into textual
/// representations using various formats like Turtle, JSON-LD, etc. It's part of
/// the Strategy pattern implementation that allows the library to support multiple
/// encoding formats.
///
/// Format-specific encoders should extend this base class to be registered
/// with the RDF library's codec framework.
///
/// Encoders are responsible for:
/// - Determining how to represent triples in their specific format
/// - Handling namespace prefixes and base URIs
/// - Applying format-specific optimizations for readability or size
abstract class RdfGraphEncoder extends Converter<RdfGraph, String> {
  const RdfGraphEncoder();

  /// Encodes an RDF graph to a string representation in a specific format.
  ///
  /// Transforms an in-memory RDF graph into an encoded text format that can be
  /// stored or transmitted. The exact output format depends on the implementing class.
  ///
  /// Parameters:
  /// - [graph] The RDF graph to encode.
  /// - [baseUri] Optional base URI for resolving/shortening IRIs in the output.
  ///   When provided, the encoder may use this to produce more compact output.
  ///
  /// Returns:
  /// - The serialized representation of the graph as a string.
  String convert(RdfGraph graph, {String? baseUri});

  /// Creates a new encoder instance with the specified options.
  ///
  /// This method follows the Builder pattern to create a new encoder configured with
  /// the given options. It allows for customizing the encoding behavior without
  /// modifying the original encoder instance.
  ///
  /// Parameters:
  /// - [options] The encoder options to apply, including [RdfGraphEncoderOptions.customPrefixes] for
  ///   namespace handling.
  ///
  /// Returns:
  /// - A new encoder instance with the specified options applied.
  RdfGraphEncoder withOptions(RdfGraphEncoderOptions options);
}
