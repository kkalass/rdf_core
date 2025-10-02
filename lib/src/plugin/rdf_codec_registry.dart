import 'package:logging/logging.dart';
import 'package:rdf_core/src/plugin/exceptions.dart';
import 'package:rdf_core/src/plugin/rdf_base_codec.dart';
import 'package:rdf_core/src/rdf_decoder.dart';
import 'package:rdf_core/src/rdf_encoder.dart';

import '../graph/rdf_graph.dart';

class BaseRdfCodecRegistry<G> {
  final _logger = Logger('rdf.codec_registry');
  final Map<String, RdfCodec<G>> _codecsByMimeType = {};
  final List<RdfCodec<G>> _codecs = [];

  BaseRdfCodecRegistry();

  /// Register a new codec with the registry
  ///
  /// This will make the codec available for decoding and encoding
  /// when requested by any of its supported MIME types. The codec will also
  /// be considered during auto-detection of unknown content.
  ///
  /// The [codec] parameter is the codec implementation to register.
  void registerCodec(RdfCodec<G> codec) {
    _logger.fine('Registering rdf codec: ${codec.primaryMimeType} for ${this}');
    _codecs.add(codec);

    for (final mimeType in codec.supportedMimeTypes) {
      final normalized = _normalizeMimeType(mimeType);
      _codecsByMimeType[normalized] = codec;
    }
  }

  /// Returns all MIME types supported by all registered codecs
  ///
  /// This getter provides a consolidated set of all MIME types that can be
  /// handled by any of the registered graph codecs. The set is unmodifiable.
  ///
  /// Returns an unmodifiable set of all MIME types supported by registered graph codecs.
  Set<String> get allMimeTypes {
    final mimeTypes = <String>{};
    for (final codec in _codecs) {
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
  RdfCodec<G> getCodec(String? mimeType) {
    RdfCodec<G>? result;
    if (mimeType != null) {
      result = _codecsByMimeType[_normalizeMimeType(mimeType)];
      if (result == null) {
        throw CodecNotSupportedException(
          'No codec registered for MIME type: $mimeType',
        );
      }
      return result;
    }

    // Use the first registered codec as default encoder
    if (_codecs.isEmpty) {
      throw CodecNotSupportedException('No codecs registered');
    }

    // If no codec found, return a special detecting codec
    return AutoDetectingRdfCodec<G>(
      defaultCodec: _codecs.first,
      registry: this,
    );
  }

  /// Retrieves all registered codecs
  ///
  /// Returns an unmodifiable list of all codec implementations currently registered.
  /// This can be useful for iterating through available codecs or for diagnostics.
  ///
  /// Returns an unmodifiable list of all registered codecs.
  List<RdfCodec<G>> getAllCodecs() => List.unmodifiable(_codecs);

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
  RdfCodec<G>? detectCodec(String content) {
    _logger.fine('Attempting to detect codec from content');

    for (final codec in _codecs) {
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
    _codecs.clear();
    _codecsByMimeType.clear();
  }
}

/// A specialized codec that auto-detects the format during decoding
///
/// This codec implementation automatically detects the appropriate format for decoding
/// based on content inspection, while using a specified default codec for encoding.
/// It works in conjunction with the [BaseRdfCodecRegistry] to identify the correct format.
///
/// This class is primarily used internally by the RDF library when the format is
/// not explicitly specified, but can also be used directly when working with content
/// of unknown format.
class AutoDetectingRdfCodec<G> extends RdfCodec<G> {
  final RdfCodec<G> _defaultCodec;

  final BaseRdfCodecRegistry _registry;
  final RdfGraphEncoderOptions? _encoderOptions;
  final RdfGraphDecoderOptions? _decoderOptions;

  /// Creates a new auto-detecting codec
  ///
  /// The [defaultCodec] parameter is the codec to use for encoding operations.
  /// The [registry] parameter is the codec registry to use for format detection.
  /// The [encoderOptions] parameter contains optional configuration options for the encoder.
  /// The [decoderOptions] parameter contains optional configuration options for the decoder.
  AutoDetectingRdfCodec({
    required RdfCodec<G> defaultCodec,
    required BaseRdfCodecRegistry registry,
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
  /// Returns a new [AutoDetectingRdfCodec] instance with the specified options.
  @override
  RdfCodec<G> withOptions({
    RdfGraphEncoderOptions? encoder,
    RdfGraphDecoderOptions? decoder,
  }) =>
      AutoDetectingRdfCodec(
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
  Set<String> get supportedMimeTypes => _registry.allMimeTypes;

  /// Returns an auto-detecting decoder
  ///
  /// Creates a decoder that will automatically detect the format of the input data
  /// and use the appropriate registered codec to decode it.
  @override
  RdfDecoder<G> get decoder =>
      AutoDetectingRdfDecoder(_registry, options: _decoderOptions);

  /// Returns the default codec's encoder
  ///
  /// Since format detection is only relevant for decoding, this returns the
  /// encoder from the default codec, optionally configured with the stored options.
  @override
  RdfEncoder<G> get encoder {
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
    final codec = _registry.detectCodec(content);
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
class AutoDetectingRdfDecoder<G> extends RdfDecoder<G> {
  final _logger = Logger('rdf.format_detecting_parser');
  final BaseRdfCodecRegistry _registry;
  final RdfGraphDecoderOptions? _decoderOptions;

  /// Creates a new auto-detecting decoder
  ///
  /// The [_registry] parameter is the codec registry to use for format detection.
  /// The [options] parameter contains optional configuration options for the decoder.
  AutoDetectingRdfDecoder(this._registry, {RdfGraphDecoderOptions? options})
      : _decoderOptions = options;

  /// Creates a new instance with the specified options
  ///
  /// Returns a new decoder with the given options while maintaining
  /// the original registry association.
  ///
  /// The [options] parameter contains the decoder options to apply.
  ///
  /// Returns a new [AutoDetectingRdfDecoder] with the specified options.
  @override
  RdfDecoder<G> withOptions(RdfGraphDecoderOptions options) =>
      AutoDetectingRdfDecoder(_registry, options: options);

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
  G convert(String input, {String? documentUrl}) {
    // First try to use format auto-detection
    final format = _registry.detectCodec(input);

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
    final codecs = _registry.getAllCodecs();
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
