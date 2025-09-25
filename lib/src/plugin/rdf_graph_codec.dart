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
/// - [BaseRdfCodecRegistry]: Central registry for format plugins and auto-detection
library;

import 'package:rdf_core/src/plugin/rdf_base_codec.dart';
import 'package:rdf_core/src/plugin/rdf_codec_registry.dart';
import 'package:rdf_core/src/rdf_decoder.dart';
import 'package:rdf_core/src/rdf_encoder.dart';

import '../graph/rdf_graph.dart';
import '../rdf_graph_decoder.dart';
import '../rdf_graph_encoder.dart';

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
abstract class RdfGraphCodec extends RdfCodec<RdfGraph> {
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
  final BaseRdfCodecRegistry<RdfGraph> _registry;

  /// Creates a new codec registry
  ///
  /// The registry starts empty, with no codecs registered.
  /// Codec implementations must be registered using the registerCodec method.
  RdfCodecRegistry([List<RdfGraphCodec> initialCodecs = const []])
      : _registry = BaseRdfCodecRegistry() {
    for (final codec in initialCodecs) {
      registerGraphCodec(codec);
    }
  }

  /// Register a new codec with the registry
  ///
  /// This will make the codec available for decoding and encoding
  /// when requested by any of its supported MIME types. The codec will also
  /// be considered during auto-detection of unknown content.
  ///
  /// The [codec] parameter is the codec implementation to register.
  void registerGraphCodec(RdfGraphCodec codec) {
    _registry.registerCodec(codec);
  }

  Set<String> get allGraphMimeTypes => _registry.allMimeTypes;

  RdfGraphCodec _asRdfGraphCodec(RdfCodec<RdfGraph> codec) {
    if (codec is RdfGraphCodec) {
      return codec;
    }
    return _RdfGraphCodecWrapper(codec);
  }

  List<RdfGraphCodec> getAllGraphCodecs() =>
      _registry.getAllCodecs().map(_asRdfGraphCodec).toList();

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
    return _asRdfGraphCodec(_registry.getCodec(mimeType));
  }

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
    final result = _registry.detectCodec(content);
    if (result == null) return null;
    return _asRdfGraphCodec(result);
  }

  /// Clear all registered codecs (mainly for testing)
  ///
  /// Removes all registered codecs from the registry. This is primarily
  /// useful for unit testing to ensure a clean state.
  void clear() {
    _registry.clear();
  }
}

class _RdfGraphCodecWrapper extends RdfGraphCodec {
  final RdfCodec<RdfGraph> _inner;

  _RdfGraphCodecWrapper(this._inner);

  @override
  RdfGraphCodec withOptions({
    RdfGraphEncoderOptions? encoder,
    RdfGraphDecoderOptions? decoder,
  }) {
    return _RdfGraphCodecWrapper(
        _inner.withOptions(encoder: encoder, decoder: decoder));
  }

  @override
  String get primaryMimeType => _inner.primaryMimeType;

  @override
  Set<String> get supportedMimeTypes => _inner.supportedMimeTypes;

  @override
  RdfGraphDecoder get decoder => _inner.decoder is RdfGraphDecoder
      ? _inner.decoder as RdfGraphDecoder
      : _RdfGraphDecoderWrapper(_inner.decoder);

  @override
  RdfGraphEncoder get encoder => _inner.encoder is RdfGraphEncoder
      ? _inner.encoder as RdfGraphEncoder
      : _RdfGraphEncoderWrapper(_inner.encoder);

  @override
  bool canParse(String content) => _inner.canParse(content);
}

class _RdfGraphDecoderWrapper extends RdfGraphDecoder {
  final RdfDecoder<RdfGraph> _inner;

  _RdfGraphDecoderWrapper(this._inner);

  @override
  RdfGraphDecoder withOptions(RdfGraphDecoderOptions options) {
    return _RdfGraphDecoderWrapper(_inner.withOptions(options));
  }

  @override
  RdfGraph convert(String input, {String? documentUrl}) {
    return _inner.convert(input, documentUrl: documentUrl);
  }
}

class _RdfGraphEncoderWrapper extends RdfGraphEncoder {
  final RdfEncoder<RdfGraph> _inner;

  _RdfGraphEncoderWrapper(this._inner);

  @override
  RdfGraphEncoder withOptions(RdfGraphEncoderOptions options) {
    return _RdfGraphEncoderWrapper(_inner.withOptions(options));
  }

  @override
  String convert(RdfGraph input, {String? baseUri}) {
    return _inner.convert(input, baseUri: baseUri);
  }
}
