/// N-Triples serializer - Implementation of the RdfSerializer interface for N-Triples format
///
/// This file provides the serializer implementation for the N-Triples format,
/// which is a line-based serialization of RDF.
library ntriples_serializer;

import 'package:rdf_core/src/dataset/rdf_dataset.dart';
import 'package:rdf_core/src/nquads/nquads_codec.dart';
import 'package:rdf_core/src/rdf_encoder.dart';

import '../graph/rdf_graph.dart';
import '../rdf_graph_encoder.dart';

/// Options for configuring the N-Triples encoder behavior.
///
/// N-Triples has a very simple serialization format with minimal configurable options
/// compared to other RDF serialization formats.
///
/// The N-Triples format specification doesn't support namespace prefixes, so the
/// [customPrefixes] property is implemented to return an empty map to satisfy the
/// interface requirement.
class NTriplesEncoderOptions extends RdfGraphEncoderOptions {
  /// Whether to produce canonical N-Triples output.
  ///
  /// When [canonical] is true, the encoder will:
  /// - Use specific character escaping rules as defined by RDF canonical N-Triples
  /// - Sort output lines lexicographically to ensure deterministic output
  /// - Apply consistent blank node labeling
  ///
  /// **Important**: This does NOT fulfill the complete RDF Dataset Canonicalization
  /// specification (RDF-CANON) because blank nodes are not canonicalized according
  /// to that spec, which requires much more complex algorithms. For full RDF
  /// canonicalization compliance, use the `rdf_canonicalization` package instead.
  ///
  /// This is useful for creating reproducible output that can be compared
  /// byte-for-byte across different runs with the same input.
  final bool canonical;

  /// Creates a new instance of NTriplesEncoderOptions with default settings.
  ///
  /// The [canonical] parameter controls whether to produce canonical N-Triples output.
  /// When false (default), standard N-Triples formatting is used. When true, the output
  /// follows RDF canonical N-Triples rules for deterministic serialization.
  ///
  /// Note: This does not implement full RDF Dataset Canonicalization (RDF-CANON).
  /// For that, use the `rdf_canonicalization` package.
  const NTriplesEncoderOptions({this.canonical = false});

  /// Custom namespace prefixes to use during encoding.
  ///
  /// This implementation returns an empty map because prefixes are not used in N-Triples format,
  /// but the interface requires it as most other formats do use prefixes.
  @override
  Map<String, String> get customPrefixes => const {};

  /// Creates an instance of NTriplesEncoderOptions from generic encoder options.
  ///
  /// This factory method ensures that when generic [RdfGraphEncoderOptions] are provided
  /// to a method expecting N-Triples-specific options, they are properly converted.
  ///
  /// The [options] parameter contains the generic encoder options to convert.
  /// Returns an instance of NTriplesEncoderOptions.
  static NTriplesEncoderOptions from(RdfGraphEncoderOptions options) =>
      switch (options) {
        NTriplesEncoderOptions _ => options,
        _ => NTriplesEncoderOptions(),
      };

  /// Creates a copy of this NTriplesEncoderOptions with the given fields replaced with new values.
  ///
  /// Any parameter that is not provided (or is null) will use the value from the current instance.
  /// The [canonical] parameter controls whether to produce canonical N-Triples output.
  @override
  NTriplesEncoderOptions copyWith(
          {Map<String, String>? customPrefixes,
          IriRelativizationOptions? iriRelativization,
          bool? canonical}) =>
      NTriplesEncoderOptions(canonical: canonical ?? this.canonical);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NTriplesEncoderOptions &&
          runtimeType == other.runtimeType &&
          canonical == other.canonical;

  @override
  int get hashCode => canonical.hashCode;
}

/// Encoder for the N-Triples format.
///
/// This class extends the RdfGraphEncoder abstract class to convert RDF graphs into
/// the N-Triples serialization format. N-Triples is a line-based format where
/// each line represents a single triple, making it very simple to parse and generate.
///
/// The encoder creates one line for each triple in the form:
/// `<subject> <predicate> <object> .`
///
/// N-Triples is fully compatible with the RDF 1.1 N-Triples specification
/// (https://www.w3.org/TR/n-triples/).
final class NTriplesEncoder extends RdfGraphEncoder {
  // Encoders are always expected to have options, even if they are not used at
  // the moment. But maybe the NTriplesEncoder will have options in the future.
  //
  // ignore: unused_field
  final RdfEncoder<RdfDataset> _encoder;
  final NTriplesEncoderOptions _options;

  /// Creates a new N-Triples serializer
  NTriplesEncoder({
    NTriplesEncoderOptions options = const NTriplesEncoderOptions(),
  })  : _options = options,
        _encoder = NQuadsEncoder(
          options: _toNQuadsOptions(options),
        );

  static NQuadsEncoderOptions _toNQuadsOptions(
          NTriplesEncoderOptions options) =>
      NQuadsEncoderOptions(canonical: options.canonical);

  @override
  RdfGraphEncoder withOptions(RdfGraphEncoderOptions options) {
    var opts = options is NTriplesEncoderOptions
        ? options
        : NTriplesEncoderOptions.from(options);
    return opts == this._options ? this : NTriplesEncoder(options: opts);
  }

  @override
  String convert(RdfGraph graph, {String? baseUri}) {
    return _encoder.convert(RdfDataset.fromDefaultGraph(graph),
        baseUri: baseUri);
  }
}
