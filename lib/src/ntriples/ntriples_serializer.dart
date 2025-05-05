/// N-Triples serializer - Implementation of the RdfSerializer interface for N-Triples format
///
/// This file provides the serializer implementation for the N-Triples format,
/// which is a line-based serialization of RDF.
library ntriples_serializer;

import 'package:logging/logging.dart';

import '../graph/rdf_graph.dart';
import '../graph/rdf_term.dart';
import '../graph/triple.dart';
import '../rdf_serializer.dart';
import '../vocab/xsd.dart';

/// Serializer for the N-Triples format.
///
/// This class implements the RdfSerializer interface to convert RDF graphs into
/// the N-Triples serialization format. N-Triples is a line-based format where
/// each line represents a single triple, making it very simple to parse and generate.
///
/// The serializer creates one line for each triple in the form:
/// `<subject> <predicate> <object> .`
///
/// N-Triples is fully compatible with the RDF 1.1 N-Triples specification
/// (https://www.w3.org/TR/n-triples/).
final class NTriplesSerializer implements RdfSerializer {
  final _logger = Logger('rdf.ntriples.serializer');

  /// Creates a new N-Triples serializer
  NTriplesSerializer();

  @override
  String write(
    RdfGraph graph, {
    String? baseUri,
    Map<String, String> customPrefixes = const {},
  }) {
    _logger.fine('Serializing graph to N-Triples');

    // N-Triples ignores baseUri and customPrefixes as it doesn't support
    // relative IRIs or prefixed names

    final buffer = StringBuffer();

    for (final triple in graph.triples) {
      _writeTriple(buffer, triple);
      buffer.writeln();
    }

    return buffer.toString();
  }

  /// Writes a single triple in N-Triples format to the buffer
  void _writeTriple(StringBuffer buffer, Triple triple) {
    _writeTerm(buffer, triple.subject);
    buffer.write(' ');
    _writeTerm(buffer, triple.predicate);
    buffer.write(' ');
    _writeTerm(buffer, triple.object);
    buffer.write(' .');
  }

  /// Writes a term in N-Triples format to the buffer
  void _writeTerm(StringBuffer buffer, RdfTerm term) {
    if (term is IriTerm) {
      buffer.write('<${_escapeIri(term.iri)}>');
    } else if (term is BlankNodeTerm) {
      // Use the identityHashCode as a stable identifier for this blank node
      // In a real implementation, you would maintain a mapping of blank nodes to labels
      buffer.write('_:b${identityHashCode(term)}');
    } else if (term is LiteralTerm) {
      buffer.write('"${_escapeLiteral(term.value)}"');

      if (term.language != null && term.language!.isNotEmpty) {
        buffer.write('@${term.language}');
      } else if (term.datatype.iri != XsdTypes.string.iri) {
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
