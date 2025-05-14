/// RDF Decoder Interface & Utilities
///
/// Defines the interface and utilities for decoding RDF data from various string formats.
///
/// See: [RDF 1.1 Concepts - Syntax](https://www.w3.org/TR/rdf11-concepts/#section-syntax)
library;

import 'dart:convert';

import 'graph/rdf_graph.dart';

class RdfGraphDecoderOptions {
  const RdfGraphDecoderOptions();
}

/// Base class for decoding RDF documents in various formats
///
/// This base class abstracts the decoding process for different RDF string serializations
/// (such as Turtle, JSON-LD, RDF/XML, etc.) to provide a common decoding API.
/// Each format implements this interface to handle its specific syntax rules.
///
/// Format-specific decoders should implement this base class to be used with the
/// RDF library's parsing framework.
abstract class RdfGraphDecoder extends Converter<String, RdfGraph> {
  const RdfGraphDecoder();

  /// Decodes an RDF document and return an RDF graph
  ///
  /// This method transforms a textual RDF document into a structured RdfGraph object
  /// containing triples parsed from the input.
  ///
  /// Parameters:
  /// - [input] is the RDF document to decode, as a string.
  /// - [documentUrl] is the absolute URL of the document, used for resolving relative IRIs.
  ///   If not provided, relative IRIs will be kept as-is or handled according to format-specific rules.
  ///
  /// Returns:
  /// - An [RdfGraph] containing the triples parsed from the input.
  ///
  /// The specific decoding behavior depends on the implementation of this interface,
  /// which will handle format-specific details like prefix resolution, blank node handling, etc.
  RdfGraph convert(String input, {String? documentUrl});

  RdfGraphDecoder withOptions(RdfGraphDecoderOptions options);
}
