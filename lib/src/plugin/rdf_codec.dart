/// RDF Codec Plugin System - Extensible support for RDF serialization formats
///
/// This file defines the plugin architecture that enables the RDF library to support
/// multiple serialization formats through a unified API, based on the dart:convert
/// framework classes. It implements the Strategy pattern
/// to allow different decoding and encoding strategies to be selected at runtime.
///
/// The plugin system allows:
/// - Registration of codec implementations (Turtle, JSON-LD, etc.)
/// - Codec auto-detection based on content
/// - Codec selection based on MIME type
/// - A unified API for decoding and encoding regardless of format
library;

import 'dart:convert';

import 'package:logging/logging.dart';

import '../graph/rdf_graph.dart';
import '../rdf_decoder.dart';
import '../rdf_encoder.dart';

/// Represents a content codec that can be handled by the RDF framework.
///
/// A codec plugin encapsulates all the logic needed to work with a specific
/// RDF serialization format (like Turtle, JSON-LD, RDF/XML, etc.). It provides
/// both decoding and encoding capabilities for the format.
///
/// To add support for a new RDF format, implement this interface and register
/// an instance with the RdfCodecRegistry.
///
/// Example of implementing a new format:
/// ```dart
/// class MyCustomGraphCodec implements RdfGraphCodec {
///   @override
///   String get primaryMimeType => 'application/x-custom-rdf';
///
///   @override
///   Set<String> get supportedMimeTypes => {primaryMimeType};
///
///   @override
///   RdfGraphDecoder get decoder => MyCustomGraphDecoder();
///
///   @override
///   RdfGraphEncoder get encoder => MyCustomGraphEncoder();
///
///   @override
///   bool canParse(String content) {
///     // Check if the content appears to be in this format
///     return content.contains('CUSTOM-RDF-FORMAT');
///   }
/// }
/// ```
abstract class RdfGraphCodec extends Codec<RdfGraph, String> {
  /// The primary MIME type for this codec
  ///
  /// This is the canonical MIME type used to identify the codec,
  /// typically the one registered with IANA.
  String get primaryMimeType;

  /// All MIME types supported by this codec
  ///
  /// Some codecs may have multiple MIME types associated with them,
  /// including older or deprecated ones. This set should include all
  /// MIME types that the codec implementation can handle.
  Set<String> get supportedMimeTypes;

  /// Creates a decoder instance for this codec
  ///
  /// Returns a new instance of a decoder that can convert text in this codec's format
  /// to an RdfGraph object.
  @override
  RdfGraphDecoder get decoder;

  /// Creates an encoder instance for this codec
  ///
  /// Returns a new instance of an encoder that can convert an RdfGraph
  /// to text in this codec's format.
  @override
  RdfGraphEncoder get encoder;

  const RdfGraphCodec();

  /// Encodes an RDF graph to a string representation in this codec
  ///
  /// This is a convenience method that delegates to the codec's encoder.
  /// It transforms an in-memory RDF graph into an encoded text representation that can be
  /// stored or transmitted.
  ///
  /// Parameters:
  /// - [input] The RDF graph to encode
  /// - [baseUri] Optional base URI for resolving/shortening IRIs in the output.
  ///   When provided, the encoder may use this to produce more compact output.
  /// - [customPrefixes] Optional map of prefix to namespace mappings to use in serialization.
  ///   Allows caller-specified namespace abbreviations for readable output in codecs
  ///   that support prefixes (like Turtle).
  ///
  /// Returns:
  /// - The serialized representation of the graph as a string
  ///
  /// Example:
  /// ```dart
  /// final turtle = TurtleCodec();
  /// final serialized = turtle.encode(graph, customPrefixes: {'ex': 'http://example.org/'});
  /// ```
  String encode(
    RdfGraph input, {
    String? baseUri,
    Map<String, String> customPrefixes = const {},
  }) {
    return encoder.convert(
      input,
      baseUri: baseUri,
      customPrefixes: customPrefixes,
    );
  }

  /// Decodes a string containing RDF data into an RDF graph
  ///
  /// This is a convenience method that delegates to the codec's decoder.
  /// It transforms a textual RDF document into a structured RdfGraph object
  /// containing triples parsed from the input.
  ///
  /// Parameters:
  /// - [input] The RDF content to decode as a string
  /// - [documentUrl] Optional base URI for resolving relative references in the document.
  ///   If not provided, relative IRIs will be kept as-is or handled according to
  ///   codec-specific rules.
  ///
  /// Returns:
  /// - An [RdfGraph] containing the parsed triples
  ///
  /// Example:
  /// ```dart
  /// final turtle = TurtleCodec();
  /// final graph = turtle.decode(turtleString);
  /// ```
  ///
  /// Throws:
  /// - Codec-specific exceptions for syntax errors or other parsing problems
  RdfGraph decode(String input, {String? documentUrl}) {
    return decoder.convert(input, documentUrl: documentUrl);
  }

  /// Tests if the provided content is likely in this codec's format
  ///
  /// This method is used for codec auto-detection when no explicit MIME type
  /// is available. It should perform quick heuristic checks to determine if
  /// the content appears to be in the format supported by this codec.
  ///
  /// The method should balance accuracy with performance - it should not
  /// perform a full parse, but should do enough checking to make a reasonable
  /// determination.
  ///
  /// Parameters:
  /// - [content] The string content to check
  ///
  /// Returns:
  /// - true if the content appears to be in this codec's format
  bool canParse(String content);
}

/// Manages registration and discovery of RDF codec plugins.
///
/// This registry acts as the central point for codec plugin management, providing
/// a mechanism for plugin registration, discovery, and codec auto-detection.
/// It implements a plugin system that allows the core RDF library to be extended
/// with additional serialization formats.
///
/// Example usage:
/// ```dart
/// // Create a registry
/// final registry = RdfCodecRegistry();
///
/// // Register format plugins
/// registry.registerCodec(const TurtleCodec());
/// registry.registerCodec(const JsonLdCodec());
///
/// // Get a codec for a specific MIME type
/// final turtleCodec = registry.codec('text/turtle');
///
/// // Or let the system detect the format
/// final autoCodec = registry.codec(); // Will auto-detect
/// ```
final class RdfCodecRegistry {
  final _logger = Logger('rdf.codec_registry');
  final Map<String, RdfGraphCodec> _graphCodecsByMimeType = {};
  final List<RdfGraphCodec> _graphCodecs = [];

  /// Creates a new codec registry
  ///
  /// The registry starts empty, with no codecs registered.
  /// Codec implementations must be registered using the registerCodec method.
  RdfCodecRegistry();

  /// Register a new codec with the registry
  ///
  /// This will make the codec available for decoding and encoding
  /// when requested by any of its supported MIME types. The codec will also
  /// be considered during auto-detection of unknown content.
  ///
  /// @param codec The codec implementation to register
  void registerGraphCodec(RdfGraphCodec codec) {
    _logger.fine('Registering graph codec: ${codec.primaryMimeType}');
    _graphCodecs.add(codec);

    for (final mimeType in codec.supportedMimeTypes) {
      final normalized = _normalizeMimeType(mimeType);
      _graphCodecsByMimeType[normalized] = codec;
    }
  }

  Set<String> get allGraphMimeTypes {
    final mimeTypes = <String>{};
    for (final codec in _graphCodecs) {
      mimeTypes.addAll(codec.supportedMimeTypes);
    }
    return Set.unmodifiable(mimeTypes);
  }

  /// Retrieves a codec instance by MIME type
  ///
  /// This method retrieves the appropriate codec for processing RDF data
  /// in the format specified by the given MIME type.
  ///
  /// @param mimeType The MIME type for which to retrieve a codec. Can be null.
  /// @return The appropriate [RdfGraphCodec] for the given MIME type. If you pass in null as mimeType then a special
  /// one that auto-detects the format for the decoder, but encodes to the first registered codec
  /// @throws UnsupportedCodecException If no codec is found for the given MIME type.
  RdfGraphCodec getGraphCodec(String? mimeType) {
    RdfGraphCodec? result;
    if (mimeType != null) {
      result = _graphCodecsByMimeType[_normalizeMimeType(mimeType)];
      if (result == null) {
        throw CodecNotSupportedException(
          'No codec registered for MIME type: $mimeType',
        );
      }
      return result;
    }

    // Use the first registered codec as default encoder
    if (_graphCodecs.isEmpty) {
      throw CodecNotSupportedException('No codecs registered');
    }

    // If no codec found, return a special detecting codec
    return AutoDetectingGraphCodec(
      defaultCodec: _graphCodecs.first,
      registry: this,
    );
  }

  /// Retrieves all registered codecs
  ///
  /// Returns an unmodifiable list of all codec implementations currently registered.
  /// This can be useful for iterating through available codecs or for diagnostics.
  ///
  /// @return An unmodifiable list of all registered codecs
  List<RdfGraphCodec> getAllGraphCodecs() => List.unmodifiable(_graphCodecs);

  /// Detect codec from content when no MIME type is available
  ///
  /// Attempts to identify the codec by examining the content structure.
  /// Each registered codec is asked if it can parse the content, and the
  /// first one that responds positively is returned.
  ///
  /// @param content The content string to analyze
  /// @return The first codec that claims it can parse the content, or null if none found
  RdfGraphCodec? detectGraphCodec(String content) {
    _logger.fine('Attempting to detect codec from content');

    for (final codec in _graphCodecs) {
      if (codec.canParse(content)) {
        _logger.fine('Detected codec: ${codec.primaryMimeType}');
        return codec;
      }
    }

    _logger.fine('No codec detected');
    return null;
  }

  /// Helper method to normalize MIME types for consistent lookup
  ///
  /// Ensures that MIME types are compared case-insensitively and without
  /// extraneous whitespace.
  ///
  /// @param mimeType The MIME type string to normalize
  /// @return The normalized MIME type string
  static String _normalizeMimeType(String mimeType) {
    return mimeType.trim().toLowerCase();
  }

  /// Clear all registered codecs (mainly for testing)
  ///
  /// Removes all registered codecs from the registry. This is primarily
  /// useful for unit testing to ensure a clean state.
  void clear() {
    _graphCodecs.clear();
    _graphCodecsByMimeType.clear();
  }
}

/// Exception thrown when an attempt is made to use an unsupported codec
///
/// This exception is thrown when:
/// - A encoder is requested for an unregistered MIME type
/// - No codecs are registered when a serializer is requested
/// - Auto-detection fails to identify a usable codec for parsing
class CodecNotSupportedException implements Exception {
  /// Error message describing the problem
  final String message;

  /// Creates a new format not supported exception
  ///
  /// @param message A description of why the format is not supported
  CodecNotSupportedException(this.message);

  @override
  String toString() => 'CodecNotSupportedException: $message';
}

final class AutoDetectingGraphCodec extends RdfGraphCodec {
  final RdfGraphCodec _defaultCodec;

  final RdfCodecRegistry _registry;

  AutoDetectingGraphCodec({
    required RdfGraphCodec defaultCodec,
    required RdfCodecRegistry registry,
  }) : _defaultCodec = defaultCodec,
       _registry = registry;

  @override
  String get primaryMimeType => _defaultCodec.primaryMimeType;

  @override
  Set<String> get supportedMimeTypes => _registry.allGraphMimeTypes;

  @override
  RdfGraphDecoder get decoder => AutoDetectingGraphDecoder(_registry);

  @override
  RdfGraphEncoder get encoder => _defaultCodec.encoder;

  @override
  bool canParse(String content) {
    final codec = _registry.detectGraphCodec(content);
    return codec != null;
  }
}

/// A decoder that detects the format from content and delegates to the appropriate actual decoder.
///
/// This specialized decoder implements the auto-detection mechanism used when
/// no specific format is specified. It attempts to determine the format from
/// the content and then delegates to the appropriate parser implementation.
///
/// This class is primarily used internally by the RdfCodecRegistry and is not
/// typically instantiated directly by library users.
final class AutoDetectingGraphDecoder extends RdfGraphDecoder {
  final _logger = Logger('rdf.format_detecting_parser');
  final RdfCodecRegistry _registry;

  /// Creates a new auto-detecting decoder
  ///
  /// @param registry The format registry to use for detection and parser creation
  AutoDetectingGraphDecoder(this._registry);

  @override
  RdfGraph convert(String input, {String? documentUrl}) {
    // First try to use format auto-detection
    final format = _registry.detectGraphCodec(input);

    if (format != null) {
      _logger.fine('Using detected format: ${format.primaryMimeType}');
      try {
        return format.decoder.convert(input, documentUrl: documentUrl);
      } catch (e) {
        _logger.fine(
          'Failed with detected format ${format.primaryMimeType}: $e',
        );
        // If the detected format fails, fall through to trying all formats
      }
    }

    // If we can't detect or the detected format fails, try all formats in sequence
    final codecs = _registry.getAllGraphCodecs();
    if (codecs.isEmpty) {
      throw CodecNotSupportedException('No RDF codecs registered');
    }

    // Try each format in sequence until one works
    Exception? lastException;
    for (final codec in codecs) {
      try {
        _logger.fine('Trying codec: ${codec.primaryMimeType}');
        return codec.decoder.convert(input, documentUrl: documentUrl);
      } catch (e) {
        _logger.fine('Failed with format ${codec.primaryMimeType}: $e');
        lastException = e is Exception ? e : Exception(e.toString());
      }
    }

    throw CodecNotSupportedException(
      'Could not parse content with any registered codec: ${lastException?.toString() ?? "unknown error"}',
    );
  }
}
