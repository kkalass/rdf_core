/// N-Triples serializer - Implementation of the RdfSerializer interface for N-Triples format
///
/// This file provides the serializer implementation for the N-Triples format,
/// which is a line-based serialization of RDF.
library ntriples_serializer;

import 'package:logging/logging.dart';

import '../graph/rdf_graph.dart';
import '../graph/rdf_term.dart';
import '../graph/triple.dart';
import '../rdf_encoder.dart';
import '../vocab/xsd.dart';

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
  final _logger = Logger('rdf.ntriples.serializer');

  // Encoders are always expected to have options, even if they are not used at
  // the moment. But maybe the NTriplesEncoder will have options in the future.
  //
  // ignore: unused_field
  final NTriplesEncoderOptions _options;

  /// Creates a new N-Triples serializer
  NTriplesEncoder({
    NTriplesEncoderOptions options = const NTriplesEncoderOptions(),
  }) : _options = options;

  @override
  RdfGraphEncoder withOptions(RdfGraphEncoderOptions options) =>
      switch (options) {
        NTriplesEncoderOptions _ => this,
        _ => NTriplesEncoder(options: NTriplesEncoderOptions.from(options)),
      };

  @override
  String convert(RdfGraph graph, {String? baseUri}) {
    _logger.fine('Serializing graph to N-Triples');

    // N-Triples ignores baseUri and customPrefixes as it doesn't support
    // relative IRIs or prefixed names

    final buffer = StringBuffer();
    final Map<BlankNodeTerm, String> blankNodeLabels = {};
    final _BlankNodeCounter counter = _BlankNodeCounter();

    for (final triple in graph.triples) {
      _writeTriple(buffer, triple, blankNodeLabels, counter);
      buffer.writeln();
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

  /// Writes a term in N-Triples format to the buffer
  void _writeTerm(StringBuffer buffer, RdfTerm term,
      Map<BlankNodeTerm, String> blankNodeLabels, _BlankNodeCounter counter) {
    if (term is IriTerm) {
      buffer.write('<${_escapeIri(term.iri)}>');
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
      } else if (term.datatype.iri != Xsd.string.iri) {
        // Only output datatype if it's not xsd:string (implied default in N-Triples)
        buffer.write('^^<${_escapeIri(term.datatype.iri)}>');
      }
    } else {
      throw UnsupportedError('Unsupported term type: ${term.runtimeType}');
    }
  }

  /// Escapes special characters in IRIs according to N-Triples rules
  String _escapeIri(String iri) {
    return iri
        .replaceAll('\\', '\\\\')
        .replaceAll('>', '\\>')
        .replaceAll('<', '\\<');
  }

  /// Escapes special characters in literals according to N-Triples rules
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
/// for blank node labeling in N-Triples serialization.
class _BlankNodeCounter {
  int _counter = 0;

  /// Gets the next blank node label number
  int next() => _counter++;
}
