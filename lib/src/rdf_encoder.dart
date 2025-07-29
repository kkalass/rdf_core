/// RDF Encoding Framework - Components for writing RDF data in various formats
///
/// This file defines interfaces and implementations for encoding RDF data
/// from in-memory graph structures to various text-based serialization formats.
/// It complements the decoder framework by providing the reverse operation.
library;

import 'dart:convert';

import 'graph/rdf_graph.dart';

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

  /// Creates a new encoder options instance.
  ///
  /// Parameters:
  /// - [customPrefixes] Custom namespace prefixes to use during encoding.
  ///   Defaults to an empty map if not provided.
  const RdfGraphEncoderOptions({
    this.customPrefixes = const {},
  });

  /// Creates a copy of this options instance with the specified overrides.
  ///
  /// This method follows the copyWith pattern commonly used in Dart for creating
  /// modified copies of immutable objects while preserving the original instance.
  ///
  /// Parameters:
  /// - [customPrefixes] New custom prefixes to use. If null, the current value is retained.
  ///
  /// Returns:
  /// - A new [RdfGraphEncoderOptions] instance with the specified modifications.
  RdfGraphEncoderOptions copyWith({
    Map<String, String>? customPrefixes,
  }) =>
      RdfGraphEncoderOptions(
        customPrefixes: customPrefixes ?? this.customPrefixes,
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
