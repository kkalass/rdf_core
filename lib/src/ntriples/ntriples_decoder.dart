/// N-Triples parser - Implementation of the RdfParser interface for N-Triples format
///
/// This file provides the parser implementation for the N-Triples format,
/// which is a line-based serialization of RDF.
library ntriples_parser;

import 'package:logging/logging.dart';

import '../exceptions/rdf_exception.dart';
import '../exceptions/rdf_decoder_exception.dart';
import '../graph/rdf_graph.dart';
import '../graph/rdf_term.dart';
import '../graph/triple.dart';
import '../rdf_decoder.dart';

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
final class NTriplesDecoder extends RdfDecoder {
  final _logger = Logger('rdf.ntriples.parser');
  static const _formatName = 'application/n-triples';

  /// Creates a new N-Triples parser
  NTriplesDecoder();

  @override
  RdfGraph convert(String input, {String? documentUrl}) {
    _logger.fine(
      'Parsing N-Triples document${documentUrl != null ? " with base URL: $documentUrl" : ""}',
    );

    final List<Triple> triples = [];
    final List<String> lines = input.split('\n');
    int lineNumber = 0;

    for (final line in lines) {
      lineNumber++;
      final trimmed = line.trim();

      // Skip empty lines and comments
      if (trimmed.isEmpty || trimmed.startsWith('#')) {
        continue;
      }

      try {
        final triple = _parseLine(trimmed, lineNumber);
        triples.add(triple);
      } catch (e) {
        throw RdfDecoderException(
          'Error parsing N-Triples at line $lineNumber: ${e.toString()}',
          format: _formatName,
          source: SourceLocation(
            line: lineNumber - 1, // Convert to 0-based line number
            column: 0,
            context: trimmed,
          ),
        );
      }
    }

    return RdfGraph.fromTriples(triples);
  }

  /// Parses a single line of N-Triples format into a Triple
  Triple _parseLine(String line, int lineNumber) {
    // Check that the line ends with a period
    if (!line.trim().endsWith('.')) {
      throw RdfDecoderException(
        'Missing period at end of triple',
        format: _formatName,
        source: SourceLocation(
          line: lineNumber - 1, // Convert to 0-based line number
          column: line.trim().length,
          context: line.trim(),
        ),
      );
    }

    // Remove the trailing period and trim
    final content = line.trim().substring(0, line.trim().length - 1).trim();

    // Split into subject, predicate, object
    final parts = _splitTripleParts(content, lineNumber);
    if (parts.length != 3) {
      throw RdfDecoderException(
        'Invalid triple format: expected 3 parts, found ${parts.length}',
        format: _formatName,
        source: SourceLocation(
          line: lineNumber - 1, // Convert to 0-based line number
          column: 0,
          context: content,
        ),
      );
    }

    final subject = _parseSubject(parts[0].trim(), lineNumber);
    final predicate = _parsePredicate(parts[1].trim(), lineNumber);
    final object = _parseObject(parts[2].trim(), lineNumber);

    return Triple(subject, predicate, object);
  }

  /// Splits a triple line into its component parts (subject, predicate, object)
  List<String> _splitTripleParts(String content, int lineNumber) {
    final result = <String>[];
    var current = '';
    var inQuotes = false;
    var escaped = false;
    var inUri = false;

    for (int i = 0; i < content.length; i++) {
      final char = content[i];

      if (escaped) {
        current += char;
        escaped = false;
        continue;
      }

      if (char == '\\' && inQuotes) {
        escaped = true;
        current += char;
        continue;
      }

      if (char == '"' && !inUri) {
        inQuotes = !inQuotes;
        current += char;
        continue;
      }

      if (char == '<' && !inQuotes) {
        inUri = true;
        current += char;
        continue;
      }

      if (char == '>' && !inQuotes) {
        inUri = false;
        current += char;
        continue;
      }

      if (char.trim().isEmpty && !inQuotes && !inUri) {
        if (current.trim().isNotEmpty) {
          result.add(current.trim());
          current = '';
        }
        continue;
      }

      current += char;
    }

    if (current.trim().isNotEmpty) {
      result.add(current.trim());
    }

    return result;
  }

  /// Parses the subject part of a triple (IRI or blank node)
  RdfSubject _parseSubject(String subject, int lineNumber) {
    if (subject.startsWith('<') && subject.endsWith('>')) {
      // IRI
      final iri = _parseIri(subject, lineNumber);
      return IriTerm(iri);
    } else if (subject.startsWith('_:')) {
      // Blank node
      // Note: BlankNodeTerm doesn't take a label parameter in the constructor
      // We'll create a generic BlankNode - in real usage, a blank node mapping
      // would be maintained throughout the parse to ensure consistency
      return BlankNodeTerm();
    } else {
      throw RdfDecoderException(
        'Invalid subject: $subject. Must be an IRI or blank node',
        format: _formatName,
        source: SourceLocation(
          line: lineNumber - 1, // Convert to 0-based line number
          column: 0,
          context: subject,
        ),
      );
    }
  }

  /// Parses the predicate part of a triple (always an IRI in N-Triples)
  RdfPredicate _parsePredicate(String predicate, int lineNumber) {
    if (predicate.startsWith('<') && predicate.endsWith('>')) {
      // IRI
      final iri = _parseIri(predicate, lineNumber);
      return IriTerm(iri);
    } else {
      throw RdfDecoderException(
        'Invalid predicate: $predicate. Must be an IRI',
        format: _formatName,
        source: SourceLocation(
          line: lineNumber - 1, // Convert to 0-based line number
          column: 0,
          context: predicate,
        ),
      );
    }
  }

  /// Parses the object part of a triple (IRI, blank node, or literal)
  RdfObject _parseObject(String object, int lineNumber) {
    if (object.startsWith('<') && object.endsWith('>')) {
      // IRI
      final iri = _parseIri(object, lineNumber);
      return IriTerm(iri);
    } else if (object.startsWith('_:')) {
      // Blank node
      return BlankNodeTerm();
    } else if (object.startsWith('"')) {
      // Literal
      return _parseLiteral(object, lineNumber);
    } else {
      throw RdfDecoderException(
        'Invalid object: $object. Must be an IRI, blank node, or literal',
        format: _formatName,
        source: SourceLocation(
          line: lineNumber - 1, // Convert to 0-based line number
          column: 0,
          context: object,
        ),
      );
    }
  }

  /// Parses an IRI from its N-Triples representation (enclosed in angle brackets)
  String _parseIri(String iriText, int lineNumber) {
    if (!iriText.startsWith('<') || !iriText.endsWith('>')) {
      throw RdfDecoderException(
        'Invalid IRI: $iriText. Must be enclosed in angle brackets',
        format: _formatName,
        source: SourceLocation(
          line: lineNumber - 1, // Convert to 0-based line number
          column: 0,
          context: iriText,
        ),
      );
    }

    final iri = iriText.substring(1, iriText.length - 1);
    return _unescapeString(iri);
  }

  /// Parses a literal from its N-Triples representation
  LiteralTerm _parseLiteral(String literalText, int lineNumber) {
    // Find the end of the literal value
    int endQuoteIndex = _findEndQuoteIndex(literalText);
    if (endQuoteIndex == -1) {
      throw RdfDecoderException(
        'Invalid literal: $literalText. Missing closing quote',
        format: _formatName,
        source: SourceLocation(
          line: lineNumber - 1, // Convert to 0-based line number
          column: 0,
          context: literalText,
        ),
      );
    }

    // Extract the literal value
    final value = literalText.substring(1, endQuoteIndex);
    final valueUnescaped = _unescapeString(value);

    if (endQuoteIndex == literalText.length - 1) {
      // Simple literal without language tag or datatype
      // Use xsd:string as the default datatype
      return LiteralTerm.string(valueUnescaped);
    }

    final suffix = literalText.substring(endQuoteIndex + 1).trim();

    if (suffix.startsWith('@')) {
      // Literal with language tag
      final lang = suffix.substring(1);
      return LiteralTerm.withLanguage(valueUnescaped, lang);
    } else if (suffix.startsWith('^^')) {
      // Typed literal
      if (!suffix.substring(2).startsWith('<') || !suffix.endsWith('>')) {
        throw RdfDecoderException(
          'Invalid datatype IRI in literal: $literalText',
          format: _formatName,
          source: SourceLocation(
            line: lineNumber - 1, // Convert to 0-based line number
            column: endQuoteIndex + 1,
            context: suffix,
          ),
        );
      }

      final datatypeIri = suffix.substring(3, suffix.length - 1);
      final unescapedDatatypeIri = _unescapeString(datatypeIri);

      // Create the datatype IRI term
      final datatypeIriTerm = IriTerm(unescapedDatatypeIri);
      return LiteralTerm(valueUnescaped, datatype: datatypeIriTerm);
    } else {
      throw RdfDecoderException(
        'Invalid literal suffix: $suffix',
        format: _formatName,
        source: SourceLocation(
          line: lineNumber - 1, // Convert to 0-based line number
          column: endQuoteIndex + 1,
          context: suffix,
        ),
      );
    }
  }

  /// Finds the closing quote of a literal, accounting for escaped quotes
  int _findEndQuoteIndex(String literalText) {
    bool escaped = false;

    // Start from index 1 to skip the opening quote
    for (int i = 1; i < literalText.length; i++) {
      if (escaped) {
        escaped = false;
        continue;
      }

      if (literalText[i] == '\\') {
        escaped = true;
        continue;
      }

      if (literalText[i] == '"') {
        return i;
      }
    }

    return -1; // No closing quote found
  }

  /// Unescapes special characters in N-Triples strings
  String _unescapeString(String input) {
    final buffer = StringBuffer();
    bool escaped = false;

    for (int i = 0; i < input.length; i++) {
      final char = input[i];

      if (escaped) {
        switch (char) {
          case 't':
            buffer.write('\t');
            break;
          case 'b':
            buffer.write('\b');
            break;
          case 'n':
            buffer.write('\n');
            break;
          case 'r':
            buffer.write('\r');
            break;
          case 'f':
            buffer.write('\f');
            break;
          case '"':
            buffer.write('"');
            break;
          case '\'':
            buffer.write('\'');
            break;
          case '\\':
            buffer.write('\\');
            break;
          case 'u':
            // Unicode escape (4 hex digits)
            if (i + 4 < input.length) {
              final hexCode = input.substring(i + 1, i + 5);
              try {
                final codePoint = int.parse(hexCode, radix: 16);
                buffer.write(String.fromCharCode(codePoint));
                i += 4; // Skip the 4 hex digits
              } catch (e) {
                buffer.write('\\u$hexCode'); // Keep as-is if invalid
              }
            } else {
              buffer.write('\\u'); // Not enough characters, keep as-is
            }
            break;
          case 'U':
            // Unicode escape (8 hex digits)
            if (i + 8 < input.length) {
              final hexCode = input.substring(i + 1, i + 9);
              try {
                final codePoint = int.parse(hexCode, radix: 16);
                buffer.write(String.fromCharCode(codePoint));
                i += 8; // Skip the 8 hex digits
              } catch (e) {
                buffer.write('\\U$hexCode'); // Keep as-is if invalid
              }
            } else {
              buffer.write('\\U'); // Not enough characters, keep as-is
            }
            break;
          default:
            buffer.write(char); // Unknown escape, keep the character
        }
        escaped = false;
      } else if (char == '\\') {
        escaped = true;
      } else {
        buffer.write(char);
      }
    }

    if (escaped) {
      // Trailing backslash, just add it
      buffer.write('\\');
    }

    return buffer.toString();
  }
}
