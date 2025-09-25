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
  /// Creates a new instance of NTriplesEncoderOptions with default settings.
  ///
  /// Since N-Triples is a simple format, there are currently no configurable options.
  const NTriplesEncoderOptions();

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
  /// Since N-Triples format doesn't support configurable options currently,
  /// this method returns a new instance with the same configuration.
  /// This method is provided for consistency with the copyWith pattern
  /// and future extensibility.
  @override
  NTriplesEncoderOptions copyWith(
          {Map<String, String>? customPrefixes,
          IriRelativizationOptions? iriRelativization}) =>
      const NTriplesEncoderOptions();
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

  /// Creates a new N-Triples serializer
  NTriplesEncoder({
    NTriplesEncoderOptions options = const NTriplesEncoderOptions(),
  }) : _encoder = NQuadsEncoder(
          options: _toNQuadsOptions(options),
        );

  NTriplesEncoder._(RdfEncoder<RdfDataset> encoder) : _encoder = encoder;

  static NQuadsEncoderOptions _toNQuadsOptions(
          NTriplesEncoderOptions options) =>
      NQuadsEncoderOptions();

  @override
  RdfGraphEncoder withOptions(RdfGraphEncoderOptions options) =>
      switch (options) {
        NTriplesEncoderOptions _ => this,
        _ => NTriplesEncoder._(NQuadsEncoder(
            options: options is NTriplesEncoderOptions
                ? _toNQuadsOptions(options)
                : NQuadsEncoderOptions.from(options))),
      };

  @override
  String convert(RdfGraph graph, {String? baseUri}) {
    return _encoder.convert(RdfDataset.fromDefaultGraph(graph),
        baseUri: baseUri);
  }
}
