/// N-Triples parser - Implementation of the RdfParser interface for N-Triples format
///
/// This file provides the parser implementation for the N-Triples format,
/// which is a line-based serialization of RDF.
library ntriples_parser;

import 'package:logging/logging.dart';
import 'package:rdf_core/rdf_core.dart';

/// Options for configuring the N-Triples decoder behavior.
///
/// N-Triples has a straightforward format with minimal configuration options
/// compared to more complex RDF serialization formats. This class provides a
/// placeholder for future extension points if needed.
///
/// The current implementation uses default parsing behavior as defined by
/// the N-Triples specification, without additional configuration options.
class NTriplesDecoderOptions extends RdfGraphDecoderOptions {
  /// Creates a new instance of NTriplesDecoderOptions with default settings.
  ///
  /// Since N-Triples is a simple format, there are currently no configurable options.
  const NTriplesDecoderOptions();

  /// Creates an instance of NTriplesDecoderOptions from generic decoder options.
  ///
  /// This factory method ensures that when generic [RdfGraphDecoderOptions] are provided
  /// to a method expecting N-Triples-specific options, they are properly converted.
  ///
  /// The [options] parameter contains the generic decoder options to convert.
  /// Returns an instance of NTriplesDecoderOptions.
  static NTriplesDecoderOptions from(RdfGraphDecoderOptions options) =>
      switch (options) {
        NTriplesDecoderOptions _ => options,
        _ => NTriplesDecoderOptions(),
      };
}

/// Decoder for the N-Triples format.
///
/// N-Triples is a line-based, plain text serialization for RDF data.
/// Each line contains exactly one triple and ends with a period.
/// This decoder implements the N-Triples format as specified in the
/// [RDF 1.1 N-Triples specification](https://www.w3.org/TR/n-triples/).
///
/// The parser processes the input line by line, ignoring comment lines
/// (starting with '#') and empty lines, and parses each remaining line
/// as a separate triple.
final class NTriplesDecoder extends RdfGraphDecoder {
  final _logger = Logger('rdf.ntriples.parser');

  // Decoders are always expected to have options, even if they are not used at
  // the moment. But maybe the NTriplesDecoder will have options in the future.
  //
  // ignore: unused_field
  final RdfDecoder<RdfDataset> _decoder;

  /// Creates a new N-Triples parser
  NTriplesDecoder({
    NTriplesDecoderOptions options = const NTriplesDecoderOptions(),
    IriTermFactory iriTermFactory = IriTerm.validated,
  }) : _decoder = NQuadsDecoder(
          options: NQuadsDecoderOptions.from(_toNQuadsOptions(options)),
          iriTermFactory: iriTermFactory,
        );

  NTriplesDecoder._(RdfDecoder<RdfDataset> decoder) : _decoder = decoder;

  static NQuadsDecoderOptions _toNQuadsOptions(
          NTriplesDecoderOptions options) =>
      NQuadsDecoderOptions();

  @override
  RdfGraphDecoder withOptions(RdfGraphDecoderOptions options) =>
      NTriplesDecoder._(_decoder.withOptions(options is NTriplesDecoderOptions
          ? _toNQuadsOptions(options)
          : options));

  @override
  RdfGraph convert(String input, {String? documentUrl}) {
    final dataset = _decoder.convert(input, documentUrl: documentUrl);
    if (dataset.namedGraphs.isNotEmpty) {
      _logger.warning(
          'N-Triples document contains named graphs, which will be ignored. Only the default graph will be returned.');
    }
    return dataset.defaultGraph;
  }
}
