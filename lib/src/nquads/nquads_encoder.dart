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
  /// Whether to produce canonical N-Quads output.
  ///
  /// When [canonical] is true, the encoder will:
  /// - Use specific character escaping rules as defined by RDF canonical N-Quads
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

  /// Creates a new instance of NQuadsEncoderOptions with default settings.
  ///
  /// The [canonical] parameter controls whether to produce canonical N-Quads output.
  /// When false (default), standard N-Quads formatting is used. When true, the output
  /// follows RDF canonical N-Quads rules for deterministic serialization.
  ///
  /// Note: This does not implement full RDF Dataset Canonicalization (RDF-CANON).
  /// For that, use the `rdf_canonicalization` package.
  const NQuadsEncoderOptions({this.canonical = false});

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
  /// Any parameter that is not provided (or is null) will use the value from the current instance.
  /// The [canonical] parameter controls whether to produce canonical N-Quads output.
  @override
  NQuadsEncoderOptions copyWith(
          {Map<String, String>? customPrefixes,
          IriRelativizationOptions? iriRelativization,
          bool? canonical}) =>
      NQuadsEncoderOptions(canonical: canonical ?? this.canonical);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NQuadsEncoderOptions &&
          runtimeType == other.runtimeType &&
          canonical == other.canonical;

  @override
  int get hashCode => canonical.hashCode;
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
        NQuadsEncoderOptions _ =>
          this._options == options ? this : NQuadsEncoder(options: options),
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
      bool generateNewBlankNodeLabels = true}) {
    _logger.fine('Serializing dataset to N-Quads');

    final canonical = _options.canonical;
    // N-Quads ignores baseUri and customPrefixes as it doesn't support
    // relative IRIs or prefixed names

    // Make sure to have a copy so that changes do not affect the caller's map
    final blankNodeIdentifiers = {...(blankNodeLabels ??= {})};
    final _BlankNodeLabelFactory counter = generateNewBlankNodeLabels
        ? _BlankNodeLabelFactoryImpl(blankNodeIdentifiers.values)
        : _NoOpBlankNodeCounter();

    final lines = <String>[
      ...dataset.defaultGraph.triples.map((triple) =>
          _writeTriple(triple, blankNodeIdentifiers, counter, canonical)),
      ...dataset.namedGraphs.expand((namedGraph) => namedGraph.graph.triples
          .map((triple) => _writeQuad(triple, namedGraph.name,
              blankNodeIdentifiers, counter, canonical))),
    ];
    if (canonical) {
      // In canonical mode, we need to ensure that blank node labels are consistent
      // across different runs. This is achieved by sorting the lines after generation.
      // The sorting is done in code point order as per RDF 1.1 N-Quads specification.
      lines.sort();
    }

    // Join lines with LF and ensure final LF
    return lines.join('\n') + (lines.isNotEmpty ? '\n' : '');
  }

  /// Writes a single triple in N-Triples format to the buffer
  String _writeTriple(Triple triple, Map<BlankNodeTerm, String> blankNodeLabels,
      _BlankNodeLabelFactory counter, bool canonical) {
    StringBuffer buffer = StringBuffer();
    _writeTerm(buffer, triple.subject, blankNodeLabels, counter, canonical);
    buffer.write(' ');
    _writeTerm(buffer, triple.predicate, blankNodeLabels, counter, canonical);
    buffer.write(' ');
    _writeTerm(buffer, triple.object, blankNodeLabels, counter, canonical);
    buffer.write(' .');
    return buffer.toString();
  }

  /// Writes a single quad in N-Quads format to the buffer
  String _writeQuad(
      Triple triple,
      RdfTerm graph,
      Map<BlankNodeTerm, String> blankNodeLabels,
      _BlankNodeLabelFactory counter,
      bool canonical) {
    StringBuffer buffer = StringBuffer();
    _writeTerm(buffer, triple.subject, blankNodeLabels, counter, canonical);
    buffer.write(' ');
    _writeTerm(buffer, triple.predicate, blankNodeLabels, counter, canonical);
    buffer.write(' ');
    _writeTerm(buffer, triple.object, blankNodeLabels, counter, canonical);
    buffer.write(' ');
    _writeTerm(buffer, graph, blankNodeLabels, counter, canonical);
    buffer.write(' .');
    return buffer.toString();
  }

  /// Writes a term in N-Quads format to the buffer
  void _writeTerm(
      StringBuffer buffer,
      RdfTerm term,
      Map<BlankNodeTerm, String> blankNodeLabels,
      _BlankNodeLabelFactory counter,
      bool canonical) {
    if (term is IriTerm) {
      buffer.write('<${_escapeIri(term.value)}>');
    } else if (term is BlankNodeTerm) {
      // Maintain a stable mapping of blank nodes to labels using sequential numbering
      final label = blankNodeLabels.putIfAbsent(term, () {
        return counter.next();
      });
      buffer.write('_:$label');
    } else if (term is LiteralTerm) {
      buffer.write('"${_escapeLiteral(term.value, canonical)}"');

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
  String _escapeLiteral(String literal, bool canonical) {
    if (canonical) {
      return _escapeCanonicalLiteral(literal);
    }

    return literal
        .replaceAll('\\', '\\\\')
        .replaceAll('"', '\\"')
        .replaceAll('\n', '\\n')
        .replaceAll('\r', '\\r')
        .replaceAll('\t', '\\t')
        .replaceAll('\b', '\\b')
        .replaceAll('\f', '\\f');
  }

  /// Escapes special characters in literals according to RDF canonical N-Quads rules
  String _escapeCanonicalLiteral(String literal) {
    final buffer = StringBuffer();

    for (int i = 0; i < literal.length; i++) {
      final codeUnit = literal.codeUnitAt(i);
      final char = literal[i];

      // Characters that MUST be encoded using ECHAR
      switch (codeUnit) {
        case 0x08: // BS (backspace)
          buffer.write('\\b');
          break;
        case 0x09: // HT (horizontal tab)
          buffer.write('\\t');
          break;
        case 0x0A: // LF (line feed)
          buffer.write('\\n');
          break;
        case 0x0C: // FF (form feed)
          buffer.write('\\f');
          break;
        case 0x0D: // CR (carriage return)
          buffer.write('\\r');
          break;
        case 0x22: // " (quotation mark)
          buffer.write('\\"');
          break;
        case 0x5C: // \ (backslash)
          buffer.write('\\\\');
          break;
        default:
          // Characters in ranges that MUST be represented by UCHAR using lowercase \u with 4 HEXes
          if ((codeUnit >= 0x00 && codeUnit <= 0x07) || // U+0000 to U+0007
              codeUnit == 0x0B || // VT (vertical tab)
              (codeUnit >= 0x0E && codeUnit <= 0x1F) || // U+000E to U+001F
              codeUnit == 0x7F) {
            // DEL
            buffer.write(
                '\\u${codeUnit.toRadixString(16).padLeft(4, '0').toUpperCase()}');
          } else {
            // All other characters represented by their native Unicode representation
            buffer.write(char);
          }
      }
    }

    return buffer.toString();
  }
}

abstract interface class _BlankNodeLabelFactory {
  String next();
}

/// Counter for generating sequential blank node labels
///
/// Generates labels in the format b0, b1, b2, etc. following best practices
/// for blank node labeling in N-Quads serialization.
class _BlankNodeLabelFactoryImpl implements _BlankNodeLabelFactory {
  final String _prefix = 'b';

  int _counter = 0;

  _BlankNodeLabelFactoryImpl(Iterable<String> existingLabels) {
    // Initialize counter to avoid collisions with existing labels
    for (var label in existingLabels) {
      if (label.startsWith(_prefix)) {
        var numberPart = label.substring(_prefix.length);
        var number = int.tryParse(numberPart);
        if (number != null && number >= _counter) {
          _counter = number + 1;
        }
      }
    }
  }

  /// Gets the next blank node label number
  String next() => '$_prefix${_counter++}';
}

class _NoOpBlankNodeCounter implements _BlankNodeLabelFactory {
  @override
  String next() => throw UnimplementedError(
      'Blank node label generation is disabled. Provide blankNodeLabels map.');
}
