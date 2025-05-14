/// RDF Encoding Framework - Components for writing RDF data in various formats
///
/// This file defines interfaces and implementations for encoding RDF data
/// from in-memory graph structures to various text-based serialization formats.
/// It complements the decoder framework by providing the reverse operation.
library;

import 'dart:convert';

import 'graph/rdf_graph.dart';

class RdfGraphEncoderOptions {
  final Map<String, String> customPrefixes;

  const RdfGraphEncoderOptions({this.customPrefixes = const {}});
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
  /// - [customPrefixes] Optional map of prefix to namespace mappings to use in serialization.
  ///   Allows caller-specified namespace abbreviations for readable output.
  ///
  /// Returns:
  /// - The serialized representation of the graph as a string.
  String convert(RdfGraph graph, {String? baseUri});

  RdfGraphEncoder withOptions(RdfGraphEncoderOptions options);
}
