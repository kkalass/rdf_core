/// N-Quads serializer - Implementation of the RdfSerializer interface for N-Quads format
///
/// This file provides the serializer implementation for the N-Quads format,
/// which is a line-based serialization of RDF.
library nquads_serializer;

import 'package:logging/logging.dart';
import 'package:rdf_core/src/dataset/rdf_dataset.dart';
import 'package:rdf_core/src/rdf_dataset_encoder.dart';
import 'package:rdf_core/src/rdf_encoder.dart';

import '../graph/rdf_term.dart';
import '../graph/triple.dart';
import '../vocab/xsd.dart';

/// Options for configuring the N-Quads encoder behavior.
///
/// N-Quads has a very simple serialization format with minimal configurable options
/// compared to other RDF serialization formats.
///
/// The N-Quads format specification doesn't support namespace prefixes, so the
/// [customPrefixes] property is implemented to return an empty map to satisfy the
/// interface requirement.
class NQuadsEncoderOptions extends RdfDatasetEncoderOptions {
  /// Creates a new instance of NQuadsEncoderOptions with default settings.
  ///
  /// Since N-Quads is a simple format, there are currently no configurable options.
  const NQuadsEncoderOptions();

  /// Custom namespace prefixes to use during encoding.
  ///
  /// This implementation returns an empty map because prefixes are not used in N-Quads format,
  /// but the interface requires it as most other formats do use prefixes.
  @override
  Map<String, String> get customPrefixes => const {};

  /// Creates an instance of NquadsEncoderOptions from generic encoder options.
  ///
  /// This factory method ensures that when generic [RdfGraphEncoderOptions] are provided
  /// to a method expecting N-Quads-specific options, they are properly converted.
  ///
  /// The [options] parameter contains the generic encoder options to convert.
  /// Returns an instance of NquadsEncoderOptions.
  static NQuadsEncoderOptions from(RdfGraphEncoderOptions options) =>
      switch (options) {
        NQuadsEncoderOptions _ => options,
        _ => NQuadsEncoderOptions(),
      };

  /// Creates a copy of this NquadsEncoderOptions with the given fields replaced with new values.
  ///
  /// Since N-Quads format doesn't support configurable options currently,
  /// this method returns a new instance with the same configuration.
  /// This method is provided for consistency with the copyWith pattern
  /// and future extensibility.
  @override
  NQuadsEncoderOptions copyWith(
          {Map<String, String>? customPrefixes,
          IriRelativizationOptions? iriRelativization}) =>
      const NQuadsEncoderOptions();
}

/// Encoder for the N-Quads format.
///
/// This class extends the RdfGraphEncoder abstract class to convert RDF graphs into
/// the N-Quads serialization format. N-Quads is a line-based format where
/// each line represents a single triple, making it very simple to parse and generate.
///
/// The encoder creates one line for each triple in the form:
/// `<subject> <predicate> <object> .`
///
/// N-Quads is fully compatible with the RDF 1.1 N-Quads specification
/// (https://www.w3.org/TR/n-quads/).
final class NQuadsEncoder extends RdfDatasetEncoder {
  final _logger = Logger('rdf.nquads.serializer');

  // Encoders are always expected to have options, even if they are not used at
  // the moment. But maybe the NquadsEncoder will have options in the future.
  //
  // ignore: unused_field
  final NQuadsEncoderOptions _options;

  /// Creates a new N-Quads serializer
  NQuadsEncoder({
    NQuadsEncoderOptions options = const NQuadsEncoderOptions(),
  }) : _options = options;

  @override
  RdfDatasetEncoder withOptions(RdfGraphEncoderOptions options) =>
      switch (options) {
        NQuadsEncoderOptions _ => this,
        _ => NQuadsEncoder(options: NQuadsEncoderOptions.from(options)),
      };

  @override
  String convert(RdfDataset dataset, {String? baseUri}) {
    return encode(dataset, baseUri: baseUri);
  }

  /// If the [generateNewBlankNodeLabels] flag is false and [blankNodeLabels] is not provided, or does not contain all blank nodes in the dataset,
  /// an exception is thrown to indicate inconsistent blank node labeling.
  String encode(RdfDataset dataset,
      {String? baseUri,
      Map<BlankNodeTerm, String>? blankNodeLabels,
      bool generateNewBlankNodeLabels = true,
      bool canonical = true}) {
    _logger.fine('Serializing dataset to N-Quads');

    // N-Quads ignores baseUri and customPrefixes as it doesn't support
    // relative IRIs or prefixed names

    final buffer = StringBuffer();
    // Make sure to have a copy so that changes do not affect the caller's map
    blankNodeLabels = {...(blankNodeLabels ??= {})};
    final _BlankNodeCounter counter = generateNewBlankNodeLabels
        ? _BlankNodeCounter()
        : _NoOpBlankNodeCounter();

    // Write default graph triples (as triples without graph context)
    for (final triple in dataset.defaultGraph.triples) {
      _writeTriple(buffer, triple, blankNodeLabels, counter);
      buffer.writeln();
    }

    // Write named graph quads (as quads with graph context)
    for (final namedGraph in dataset.namedGraphs) {
      for (final triple in namedGraph.graph.triples) {
        _writeQuad(buffer, triple, namedGraph.name, blankNodeLabels, counter);
        buffer.writeln();
      }
    }

    return buffer.toString();
  }

  /// Writes a single triple in N-Triples format to the buffer
  void _writeTriple(StringBuffer buffer, Triple triple,
      Map<BlankNodeTerm, String> blankNodeLabels, _BlankNodeCounter counter) {
    _writeTerm(buffer, triple.subject, blankNodeLabels, counter);
    buffer.write(' ');
    _writeTerm(buffer, triple.predicate, blankNodeLabels, counter);
    buffer.write(' ');
    _writeTerm(buffer, triple.object, blankNodeLabels, counter);
    buffer.write(' .');
  }

  /// Writes a single quad in N-Quads format to the buffer
  void _writeQuad(StringBuffer buffer, Triple triple, RdfTerm graph,
      Map<BlankNodeTerm, String> blankNodeLabels, _BlankNodeCounter counter) {
    _writeTerm(buffer, triple.subject, blankNodeLabels, counter);
    buffer.write(' ');
    _writeTerm(buffer, triple.predicate, blankNodeLabels, counter);
    buffer.write(' ');
    _writeTerm(buffer, triple.object, blankNodeLabels, counter);
    buffer.write(' ');
    _writeTerm(buffer, graph, blankNodeLabels, counter);
    buffer.write(' .');
  }

  /// Writes a term in N-Quads format to the buffer
  void _writeTerm(StringBuffer buffer, RdfTerm term,
      Map<BlankNodeTerm, String> blankNodeLabels, _BlankNodeCounter counter) {
    if (term is IriTerm) {
      buffer.write('<${_escapeIri(term.value)}>');
    } else if (term is BlankNodeTerm) {
      // Maintain a stable mapping of blank nodes to labels using sequential numbering
      final label = blankNodeLabels.putIfAbsent(term, () {
        return 'b${counter.next()}';
      });
      buffer.write('_:$label');
    } else if (term is LiteralTerm) {
      buffer.write('"${_escapeLiteral(term.value)}"');

      if (term.language != null && term.language!.isNotEmpty) {
        buffer.write('@${term.language}');
      } else if (term.datatype.value != Xsd.string.value) {
        // Only output datatype if it's not xsd:string (implied default in N-Quads)
        buffer.write('^^<${_escapeIri(term.datatype.value)}>');
      }
    } else {
      throw UnsupportedError('Unsupported term type: ${term.runtimeType}');
    }
  }

  /// Escapes special characters in IRIs according to N-Quads rules
  String _escapeIri(String iri) {
    return iri
        .replaceAll('\\', '\\\\')
        .replaceAll('>', '\\>')
        .replaceAll('<', '\\<');
  }

  /// Escapes special characters in literals according to N-Quads rules
  String _escapeLiteral(String literal) {
    return literal
        .replaceAll('\\', '\\\\')
        .replaceAll('"', '\\"')
        .replaceAll('\n', '\\n')
        .replaceAll('\r', '\\r')
        .replaceAll('\t', '\\t')
        .replaceAll('\b', '\\b')
        .replaceAll('\f', '\\f');
  }
}

/// Counter for generating sequential blank node labels
///
/// Generates labels in the format b0, b1, b2, etc. following best practices
/// for blank node labeling in N-Quads serialization.
class _BlankNodeCounter {
  int _counter = 0;

  /// Gets the next blank node label number
  int next() => _counter++;
}

class _NoOpBlankNodeCounter implements _BlankNodeCounter {
  int get _counter => 0;
  set _counter(int value) {
    throw UnimplementedError(
        'Blank node label generation is disabled. Provide blankNodeLabels map.');
  }

  @override
  int next() => throw UnimplementedError(
      'Blank node label generation is disabled. Provide blankNodeLabels map.');
}
