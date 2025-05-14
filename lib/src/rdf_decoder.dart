/// RDF Decoder Interface & Utilities
///
/// Defines the interface and utilities for decoding RDF data from various string formats.
///
/// See: [RDF 1.1 Concepts - Syntax](https://www.w3.org/TR/rdf11-concepts/#section-syntax)
library;

import 'dart:convert';

import 'graph/rdf_graph.dart';

/// Configuration options for RDF graph decoders
///
/// This class provides configuration options that can be passed to RDF decoders
/// to modify their parsing behavior. Concrete implementations may extend this
/// class to provide format-specific options.
///
/// The base implementation provides no options, but serves as an extension point
/// for format-specific configuration.
class RdfGraphDecoderOptions {
  /// Creates default decoder options with no special configurations
  const RdfGraphDecoderOptions();
}

/// Base class for decoding RDF documents in various serialization formats
///
/// This abstract class extends the standard `Converter` interface to provide
/// a common API for decoding different RDF string serializations (such as Turtle,
/// JSON-LD, RDF/XML, N-Triples, etc.). Each format implements this interface to
/// handle its specific syntax rules and parsing behavior.
///
/// Format-specific decoders should implement this base class to be compatible with
/// the RDF library's parsing framework and to ensure consistent behavior across
/// different formats.
///
/// Example:
/// ```dart
/// final turtleDecoder = TurtleDecoder();
/// final graph = turtleDecoder.convert('@prefix ex: <http://example.org/> . ex:subject ex:predicate "object" .');
/// ```
abstract class RdfGraphDecoder extends Converter<String, RdfGraph> {
  const RdfGraphDecoder();

  /// Decodes an RDF document and returns an RDF graph
  ///
  /// This method transforms a textual RDF document into a structured `RdfGraph` object
  /// containing triples parsed from the input. It implements the `convert` method
  /// from the `Converter` interface.
  ///
  /// Parameters:
  /// - [input] The RDF document to decode, as a string.
  /// - [documentUrl] The absolute URL of the document, used for resolving relative IRIs.
  ///   If not provided, relative IRIs will be kept as-is or handled according to format-specific rules.
  ///
  /// Returns:
  /// - An [RdfGraph] containing the triples parsed from the input.
  ///
  /// The specific decoding behavior depends on the implementation of this interface,
  /// which will handle format-specific details like prefix resolution, blank node handling, etc.
  ///
  /// May throw format-specific parsing exceptions if the input is malformed.
  @override
  RdfGraph convert(String input, {String? documentUrl});

  /// Creates a new decoder with the specified options
  ///
  /// This method returns a new instance of the decoder configured with the
  /// provided options. The original decoder instance remains unchanged.
  ///
  /// Parameters:
  /// - [options] Configuration options to customize the decoder's behavior.
  ///
  /// Returns:
  /// - A new [RdfGraphDecoder] instance with the specified options applied.
  ///
  /// This pattern allows for immutable configuration of decoders and enables
  /// method chaining for readable configuration code.
  RdfGraphDecoder withOptions(RdfGraphDecoderOptions options);
}
