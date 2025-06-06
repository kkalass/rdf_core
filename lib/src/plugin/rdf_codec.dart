/// RDF Codec Plugin System - Extensible support for RDF serialization formats
///
/// This file defines the plugin architecture that enables the RDF library to support
/// multiple serialization formats through a unified API, based on the dart:convert
/// framework classes. It implements the Strategy pattern to allow different
/// decoding and encoding strategies to be selected at runtime.
///
/// The plugin system allows:
/// - Registration of codec implementations (Turtle, JSON-LD, etc.)
/// - Codec auto-detection based on content
/// - Codec selection based on MIME type
/// - A unified API for decoding and encoding regardless of format
///
/// Key components:
/// - [RdfGraphCodec]: Abstract base class for RDF format implementations
/// - [RdfCodecRegistry]: Central registry for format plugins and auto-detection
/// - [AutoDetectingGraphCodec]: Special codec that auto-detects formats when parsing
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
///
///   @override
///   RdfGraphCodec withOptions({
///     RdfGraphEncoderOptions? encoder,
///     RdfGraphDecoderOptions? decoder,
///   })  => this;
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

  /// Creates a new codec instance with default settings
  const RdfGraphCodec();

  /// Creates a new codec instance with the specified options
  ///
  /// This method returns a new instance of the codec configured with the
  /// provided encoder and decoder options. The original codec instance remains unchanged.
  ///
  /// The [encoder] parameter contains optional encoder options to customize encoding behavior.
  /// The [decoder] parameter contains optional decoder options to customize decoding behavior.
  ///
  /// Returns a new [RdfGraphCodec] instance with the specified options applied.
  ///
  /// This follows the immutable configuration pattern, allowing for clean
  /// method chaining and configuration without side effects.
  RdfGraphCodec withOptions({
    RdfGraphEncoderOptions? encoder,
    RdfGraphDecoderOptions? decoder,
  });

  /// Encodes an RDF graph to a string representation in this codec
  ///
  /// This is a convenience method that delegates to the codec's encoder.
  /// It transforms an in-memory RDF graph into an encoded text representation that can be
  /// stored or transmitted.
  ///
  /// The [input] parameter is the RDF graph to encode.
  /// The [baseUri] parameter is an optional base URI for resolving/shortening IRIs in the output.
  /// When provided, the encoder may use this to produce more compact output.
  /// The [options] parameter contains optional encoder options to use for this encoding operation.
  /// Can include custom namespace prefixes and other encoder-specific settings.
  ///
  /// Returns the serialized representation of the graph as a string.
  ///
  /// Example:
  /// ```dart
  /// final turtle = TurtleCodec();
  /// final options = RdfGraphEncoderOptions(customPrefixes: {'ex': 'http://example.org/'});
  /// final serialized = turtle.encode(graph, options: options);
  /// ```
  String encode(
    RdfGraph input, {
    String? baseUri,
    RdfGraphEncoderOptions? options,
  }) {
    return (options == null ? encoder : encoder.withOptions(options)).convert(
      input,
      baseUri: baseUri,
    );
  }

  /// Decodes a string containing RDF data into an RDF graph
  ///
  /// This is a convenience method that delegates to the codec's decoder.
  /// It transforms a textual RDF document into a structured RdfGraph object
  /// containing triples parsed from the input.
  ///
  /// The [input] parameter is the RDF content to decode as a string.
  /// The [documentUrl] parameter is an optional base URI for resolving relative references in the document.
  /// If not provided, relative IRIs will be kept as-is or handled according to
  /// codec-specific rules.
  /// The [options] parameter contains optional decoder options for this operation.
  ///
  /// Returns an [RdfGraph] containing the parsed triples.
  ///
  /// Example:
  /// ```dart
  /// final turtle = TurtleCodec();
  /// final graph = turtle.decode(turtleString);
  /// ```
  ///
  /// Throws codec-specific exceptions for syntax errors or other parsing problems.
  RdfGraph decode(
    String input, {
    String? documentUrl,
    RdfGraphDecoderOptions? options,
  }) {
    return (options == null ? decoder : decoder.withOptions(options)).convert(
      input,
      documentUrl: documentUrl,
    );
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
  /// The [content] parameter is the string content to check.
  ///
  /// Returns true if the content appears to be in this codec's format.
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
/// registry.registerGraphCodec(const TurtleCodec());
/// registry.registerGraphCodec(const JsonLdGraphCodec());
///
/// // Get a codec for a specific MIME type
/// final turtleCodec = registry.getGraphCodec('text/turtle');
///
/// // Or let the system detect the format
/// final autoCodec = registry.getGraphCodec(); // Will auto-detect
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
  /// The [codec] parameter is the codec implementation to register.
  void registerGraphCodec(RdfGraphCodec codec) {
    _logger.fine('Registering graph codec: ${codec.primaryMimeType}');
    _graphCodecs.add(codec);

    for (final mimeType in codec.supportedMimeTypes) {
      final normalized = _normalizeMimeType(mimeType);
      _graphCodecsByMimeType[normalized] = codec;
    }
  }

  /// Returns all MIME types supported by all registered codecs
  ///
  /// This getter provides a consolidated set of all MIME types that can be
  /// handled by any of the registered graph codecs. The set is unmodifiable.
  ///
  /// Returns an unmodifiable set of all MIME types supported by registered graph codecs.
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
  /// The [mimeType] parameter is the MIME type for which to retrieve a codec. Can be null.
  ///
  /// Returns the appropriate [RdfGraphCodec] for the given MIME type. If mimeType is null,
  /// returns a special codec that auto-detects the format for decoding, but encodes
  /// to the format of the first registered codec.
  ///
  /// Throws [CodecNotSupportedException] if no codec is found for the given MIME type
  /// or if no codecs are registered.
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
  /// Returns an unmodifiable list of all registered codecs.
  List<RdfGraphCodec> getAllGraphCodecs() => List.unmodifiable(_graphCodecs);

  /// Detect codec from content when no MIME type is available
  ///
  /// Attempts to identify the codec by examining the content structure.
  /// Each registered codec is asked if it can parse the content in
  /// the order in which they were registered, and the
  /// first one that responds positively is returned.
  ///
  /// The [content] parameter is the content string to analyze.
  ///
  /// Returns the first codec that claims it can parse the content, or null if none found.
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
  /// The [mimeType] parameter is the MIME type string to normalize.
  ///
  /// Returns the normalized MIME type string.
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
  /// The [message] parameter contains a description of why the format is not supported.
  CodecNotSupportedException(this.message);

  @override
  String toString() => 'CodecNotSupportedException: $message';
}

/// A specialized codec that auto-detects the format during decoding
///
/// This codec implementation automatically detects the appropriate format for decoding
/// based on content inspection, while using a specified default codec for encoding.
/// It works in conjunction with the [RdfCodecRegistry] to identify the correct format.
///
/// This class is primarily used internally by the RDF library when the format is
/// not explicitly specified, but can also be used directly when working with content
/// of unknown format.
final class AutoDetectingGraphCodec extends RdfGraphCodec {
  final RdfGraphCodec _defaultCodec;

  final RdfCodecRegistry _registry;
  final RdfGraphEncoderOptions? _encoderOptions;
  final RdfGraphDecoderOptions? _decoderOptions;

  /// Creates a new auto-detecting codec
  ///
  /// The [defaultCodec] parameter is the codec to use for encoding operations.
  /// The [registry] parameter is the codec registry to use for format detection.
  /// The [encoderOptions] parameter contains optional configuration options for the encoder.
  /// The [decoderOptions] parameter contains optional configuration options for the decoder.
  AutoDetectingGraphCodec({
    required RdfGraphCodec defaultCodec,
    required RdfCodecRegistry registry,
    RdfGraphEncoderOptions? encoderOptions,
    RdfGraphDecoderOptions? decoderOptions,
  })  : _defaultCodec = defaultCodec,
        _registry = registry,
        _encoderOptions = encoderOptions,
        _decoderOptions = decoderOptions;

  /// Creates a new instance with the specified options
  ///
  /// Returns a new auto-detecting codec with the given configuration options,
  /// while maintaining the original registry and default codec associations.
  ///
  /// The [encoder] parameter contains optional encoder options to use.
  /// The [decoder] parameter contains optional decoder options to use.
  ///
  /// Returns a new [AutoDetectingGraphCodec] instance with the specified options.
  @override
  RdfGraphCodec withOptions({
    RdfGraphEncoderOptions? encoder,
    RdfGraphDecoderOptions? decoder,
  }) =>
      AutoDetectingGraphCodec(
        defaultCodec: _defaultCodec,
        registry: _registry,
        encoderOptions: encoder ?? _encoderOptions,
        decoderOptions: decoder ?? _decoderOptions,
      );

  /// Returns the primary MIME type of the default codec
  ///
  /// Since this is an auto-detecting codec, it returns the primary MIME type
  /// of the default codec used for encoding operations.
  @override
  String get primaryMimeType => _defaultCodec.primaryMimeType;

  /// Returns all MIME types supported by the registry
  ///
  /// This returns the union of all MIME types supported by all registered codecs,
  /// since the auto-detecting decoder can potentially work with any of them.
  @override
  Set<String> get supportedMimeTypes => _registry.allGraphMimeTypes;

  /// Returns an auto-detecting decoder
  ///
  /// Creates a decoder that will automatically detect the format of the input data
  /// and use the appropriate registered codec to decode it.
  @override
  RdfGraphDecoder get decoder =>
      AutoDetectingGraphDecoder(_registry, options: _decoderOptions);

  /// Returns the default codec's encoder
  ///
  /// Since format detection is only relevant for decoding, this returns the
  /// encoder from the default codec, optionally configured with the stored options.
  @override
  RdfGraphEncoder get encoder {
    if (_encoderOptions != null) {
      return _defaultCodec.encoder.withOptions(_encoderOptions);
    }
    return _defaultCodec.encoder;
  }

  /// Determines if the content can be parsed by any registered codec
  ///
  /// Delegates to the registry's detection mechanism to determine if the content
  /// matches any of the registered codecs' formats.
  ///
  /// The [content] parameter is the content to check.
  ///
  /// Returns true if at least one registered codec can parse the content.
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
  final RdfGraphDecoderOptions? _decoderOptions;

  /// Creates a new auto-detecting decoder
  ///
  /// The [_registry] parameter is the codec registry to use for format detection.
  /// The [options] parameter contains optional configuration options for the decoder.
  AutoDetectingGraphDecoder(this._registry, {RdfGraphDecoderOptions? options})
      : _decoderOptions = options;

  /// Creates a new instance with the specified options
  ///
  /// Returns a new decoder with the given options while maintaining
  /// the original registry association.
  ///
  /// The [options] parameter contains the decoder options to apply.
  ///
  /// Returns a new [AutoDetectingGraphDecoder] with the specified options.
  @override
  RdfGraphDecoder withOptions(RdfGraphDecoderOptions options) =>
      AutoDetectingGraphDecoder(_registry, options: options);

  /// Decodes RDF content by auto-detecting its format
  ///
  /// This method implements a multi-stage format detection strategy:
  /// 1. First tries to detect the format using heuristic analysis
  /// 2. If detected, attempts to parse with the detected format
  /// 3. If detection fails or parsing with the detected format fails,
  ///    tries each registered codec in sequence
  /// 4. If all codecs fail, throws an exception with details
  ///
  /// The [input] parameter contains the RDF content to decode.
  /// The [documentUrl] parameter is an optional base URL for resolving relative IRIs.
  ///
  /// Returns an [RdfGraph] containing the parsed triples.
  ///
  /// Throws [CodecNotSupportedException] if no codec can parse the content
  /// or if no codecs are registered.
  @override
  RdfGraph convert(String input, {String? documentUrl}) {
    // First try to use format auto-detection
    final format = _registry.detectGraphCodec(input);

    if (format != null) {
      _logger.fine('Using detected format: ${format.primaryMimeType}');
      try {
        return (_decoderOptions == null
                ? format.decoder
                : format.decoder.withOptions(_decoderOptions))
            .convert(input, documentUrl: documentUrl);
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
        return (_decoderOptions == null
                ? codec.decoder
                : codec.decoder.withOptions(_decoderOptions))
            .convert(input, documentUrl: documentUrl);
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
