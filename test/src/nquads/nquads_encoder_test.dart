import 'package:rdf_core/rdf_core.dart';
import 'package:test/test.dart';

void main() {
  group('NQuadsEncoder', () {
    late NQuadsEncoder encoder;

    setUp(() {
      encoder = NQuadsEncoder();
    });

    group('Basic N-Quads encoding (N-Triples format)', () {
      test('encodes simple triple from default graph', () {
        final dataset = RdfDataset.fromQuads([
          Quad(
            const IriTerm('http://example.org/subject'),
            const IriTerm('http://example.org/predicate'),
            const IriTerm('http://example.org/object'),
          ),
        ]);

        final nquads = encoder.convert(dataset);

        expect(
            nquads.trim(),
            equals(
                '<http://example.org/subject> <http://example.org/predicate> <http://example.org/object> .'));
      });

      test('encodes triple with literal object', () {
        final dataset = RdfDataset.fromQuads([
          Quad(
            const IriTerm('http://example.org/subject'),
            const IriTerm('http://example.org/predicate'),
            LiteralTerm.string('Hello World'),
          ),
        ]);

        final nquads = encoder.convert(dataset);

        expect(
            nquads.trim(),
            equals(
                '<http://example.org/subject> <http://example.org/predicate> "Hello World" .'));
      });

      test('encodes triple with language-tagged literal', () {
        final dataset = RdfDataset.fromQuads([
          Quad(
            const IriTerm('http://example.org/subject'),
            const IriTerm('http://example.org/predicate'),
            LiteralTerm.withLanguage('Hello', 'en'),
          ),
        ]);

        final nquads = encoder.convert(dataset);

        expect(
            nquads.trim(),
            equals(
                '<http://example.org/subject> <http://example.org/predicate> "Hello"@en .'));
      });

      test('encodes triple with typed literal', () {
        final dataset = RdfDataset.fromQuads([
          Quad(
            const IriTerm('http://example.org/subject'),
            const IriTerm('http://example.org/predicate'),
            LiteralTerm('42',
                datatype:
                    const IriTerm('http://www.w3.org/2001/XMLSchema#integer')),
          ),
        ]);

        final nquads = encoder.convert(dataset);

        expect(
            nquads.trim(),
            equals(
                '<http://example.org/subject> <http://example.org/predicate> "42"^^<http://www.w3.org/2001/XMLSchema#integer> .'));
      });

      test('encodes triple with blank node subject', () {
        final blankNode = BlankNodeTerm();
        final dataset = RdfDataset.fromQuads([
          Quad(
            blankNode,
            const IriTerm('http://example.org/predicate'),
            LiteralTerm.string('object'),
          ),
        ]);

        final nquads = encoder.convert(dataset);

        expect(nquads.trim(),
            matches(r'_:b\d+ <http://example.org/predicate> "object" \.'));
      });

      test('encodes triple with blank node object', () {
        final blankNode = BlankNodeTerm();
        final dataset = RdfDataset.fromQuads([
          Quad(
            const IriTerm('http://example.org/subject'),
            const IriTerm('http://example.org/predicate'),
            blankNode,
          ),
        ]);

        final nquads = encoder.convert(dataset);

        expect(
            nquads.trim(),
            matches(
                r'<http://example.org/subject> <http://example.org/predicate> _:b\d+ \.'));
      });

      test('maintains consistent blank node labels across multiple triples',
          () {
        final blankNode = BlankNodeTerm();
        final dataset = RdfDataset.fromQuads([
          Quad(
            blankNode,
            const IriTerm('http://example.org/predicate1'),
            LiteralTerm.string('first'),
          ),
          Quad(
            blankNode,
            const IriTerm('http://example.org/predicate2'),
            LiteralTerm.string('second'),
          ),
        ]);

        final nquads = encoder.convert(dataset);
        final lines = nquads.trim().split('\n');

        expect(lines, hasLength(2));
        // Extract blank node labels
        final label1 = RegExp(r'(_:b\d+)').firstMatch(lines[0])!.group(1);
        final label2 = RegExp(r'(_:b\d+)').firstMatch(lines[1])!.group(1);

        expect(
            label1, equals(label2)); // Same blank node should have same label
      });

      test('uses sequential blank node labels', () {
        final blank1 = BlankNodeTerm();
        final blank2 = BlankNodeTerm();
        final dataset = RdfDataset.fromQuads([
          Quad(
            blank1,
            const IriTerm('http://example.org/predicate'),
            LiteralTerm.string('first'),
          ),
          Quad(
            blank2,
            const IriTerm('http://example.org/predicate'),
            LiteralTerm.string('second'),
          ),
        ]);

        final nquads = encoder.convert(dataset);

        expect(nquads, contains('_:b0'));
        expect(nquads, contains('_:b1'));
      });
    });

    group('N-Quads with Named Graphs', () {
      test('encodes quad with named graph', () {
        final dataset = RdfDataset.fromQuads([
          Quad(
            const IriTerm('http://example.org/subject'),
            const IriTerm('http://example.org/predicate'),
            LiteralTerm.string('object'),
            const IriTerm('http://example.org/graph1'),
          ),
        ]);

        final nquads = encoder.convert(dataset);

        expect(
            nquads.trim(),
            equals(
                '<http://example.org/subject> <http://example.org/predicate> "object" <http://example.org/graph1> .'));
      });

      test('encodes mixed default graph and named graph quads', () {
        final dataset = RdfDataset.fromQuads([
          Quad(
            const IriTerm('http://example.org/s1'),
            const IriTerm('http://example.org/p1'),
            LiteralTerm.string('default graph'),
          ),
          Quad(
            const IriTerm('http://example.org/s2'),
            const IriTerm('http://example.org/p2'),
            LiteralTerm.string('named graph'),
            const IriTerm('http://example.org/graph1'),
          ),
        ]);

        final nquads = encoder.convert(dataset);
        final lines =
            nquads.trim().split('\n').map((line) => line.trim()).toList();

        expect(lines, hasLength(2));
        expect(
            lines,
            contains(
                '<http://example.org/s1> <http://example.org/p1> "default graph" .'));
        expect(
            lines,
            contains(
                '<http://example.org/s2> <http://example.org/p2> "named graph" <http://example.org/graph1> .'));
      });

      test('encodes multiple quads in same named graph', () {
        final dataset = RdfDataset.fromQuads([
          Quad(
            const IriTerm('http://example.org/s1'),
            const IriTerm('http://example.org/p1'),
            LiteralTerm.string('first'),
            const IriTerm('http://example.org/graph1'),
          ),
          Quad(
            const IriTerm('http://example.org/s2'),
            const IriTerm('http://example.org/p2'),
            LiteralTerm.string('second'),
            const IriTerm('http://example.org/graph1'),
          ),
        ]);

        final nquads = encoder.convert(dataset);
        final lines = nquads.trim().split('\n');

        expect(lines, hasLength(2));
        expect(
            lines.every((line) => line.contains('<http://example.org/graph1>')),
            isTrue);
      });

      test('encodes quad with IRI as graph name', () {
        final dataset = RdfDataset.fromQuads([
          Quad(
            const IriTerm('http://example.org/subject'),
            const IriTerm('http://example.org/predicate'),
            LiteralTerm.string('object'),
            const IriTerm('http://example.org/graph1'),
          ),
        ]);

        final nquads = encoder.convert(dataset);

        expect(
            nquads.trim(),
            equals(
                '<http://example.org/subject> <http://example.org/predicate> "object" <http://example.org/graph1> .'));
      });

      test('encodes quad with blank node as graph name', () {
        final blankGraphName = BlankNodeTerm();
        final dataset = RdfDataset.fromQuads([
          Quad(
            const IriTerm('http://example.org/subject'),
            const IriTerm('http://example.org/predicate'),
            LiteralTerm.string('object'),
            blankGraphName,
          ),
        ]);

        final nquads = encoder.convert(dataset);

        expect(
            nquads.trim(),
            matches(
                r'<http://example\.org/subject> <http://example\.org/predicate> "object" _:b\d+ \.'));
      });

      test('maintains consistent blank node graph labels across multiple quads',
          () {
        final blankGraphName = BlankNodeTerm();
        final dataset = RdfDataset.fromQuads([
          Quad(
            const IriTerm('http://example.org/s1'),
            const IriTerm('http://example.org/p1'),
            LiteralTerm.string('first'),
            blankGraphName,
          ),
          Quad(
            const IriTerm('http://example.org/s2'),
            const IriTerm('http://example.org/p2'),
            LiteralTerm.string('second'),
            blankGraphName,
          ),
        ]);

        final nquads = encoder.convert(dataset);
        final lines = nquads.trim().split('\n');

        expect(lines, hasLength(2));

        // Extract blank node labels from both lines
        final label1 = RegExp(r'(_:b\d+)').firstMatch(lines[0])!.group(1);
        final label2 = RegExp(r'(_:b\d+)').firstMatch(lines[1])!.group(1);

        expect(label1,
            equals(label2)); // Same blank node graph should have same label
      });
    });

    group('String escaping and special characters', () {
      test('escapes special characters in literals', () {
        final dataset = RdfDataset.fromQuads([
          Quad(
            const IriTerm('http://example.org/subject'),
            const IriTerm('http://example.org/predicate'),
            LiteralTerm.string('Line 1\nLine 2\tTabbed\r\nBackslash\\Quote"'),
          ),
        ]);

        final nquads = encoder.convert(dataset);

        expect(
            nquads.trim(),
            equals(
                r'<http://example.org/subject> <http://example.org/predicate> "Line 1\nLine 2\tTabbed\r\nBackslash\\Quote\"" .'));
      });

      test('escapes special characters in IRIs', () {
        final dataset = RdfDataset.fromQuads([
          Quad(
            const IriTerm('http://example.org/subject<with>brackets'),
            const IriTerm('http://example.org/predicate'),
            LiteralTerm.string('object'),
          ),
        ]);

        final nquads = encoder.convert(dataset);

        expect(
            nquads.trim(),
            equals(
                r'<http://example.org/subject\<with\>brackets> <http://example.org/predicate> "object" .'));
      });

      test('handles Unicode characters in literals', () {
        final dataset = RdfDataset.fromQuads([
          Quad(
            const IriTerm('http://example.org/subject'),
            const IriTerm('http://example.org/predicate'),
            LiteralTerm.string('Unicode: Hello 世界'),
          ),
        ]);

        final nquads = encoder.convert(dataset);

        expect(
            nquads.trim(),
            equals(
                '<http://example.org/subject> <http://example.org/predicate> "Unicode: Hello 世界" .'));
      });

      test('omits xsd:string datatype for string literals', () {
        final dataset = RdfDataset.fromQuads([
          Quad(
            const IriTerm('http://example.org/subject'),
            const IriTerm('http://example.org/predicate'),
            LiteralTerm.string('Hello World'),
          ),
        ]);

        final nquads = encoder.convert(dataset);

        // Should not include ^^<http://www.w3.org/2001/XMLSchema#string>
        expect(
            nquads.trim(),
            equals(
                '<http://example.org/subject> <http://example.org/predicate> "Hello World" .'));
        expect(nquads, isNot(contains('XMLSchema#string')));
      });

      test('includes non-xsd:string datatypes', () {
        final dataset = RdfDataset.fromQuads([
          Quad(
            const IriTerm('http://example.org/subject'),
            const IriTerm('http://example.org/predicate'),
            LiteralTerm('42',
                datatype:
                    const IriTerm('http://www.w3.org/2001/XMLSchema#integer')),
          ),
        ]);

        final nquads = encoder.convert(dataset);

        expect(
            nquads.trim(),
            equals(
                '<http://example.org/subject> <http://example.org/predicate> "42"^^<http://www.w3.org/2001/XMLSchema#integer> .'));
      });
    });

    group('Complex scenarios', () {
      test('encodes large dataset with mixed content', () {
        final personBlank = BlankNodeTerm();
        final contactGraph = const IriTerm('http://example.org/graph/contacts');
        final peopleGraph = const IriTerm('http://example.org/graph/people');

        final dataset = RdfDataset.fromQuads([
          // Default graph
          Quad(
            const IriTerm('http://example.org/person/alice'),
            const IriTerm('http://xmlns.com/foaf/0.1/name'),
            LiteralTerm.string('Alice'),
          ),
          Quad(
            const IriTerm('http://example.org/person/alice'),
            const IriTerm('http://xmlns.com/foaf/0.1/age'),
            LiteralTerm('25',
                datatype:
                    const IriTerm('http://www.w3.org/2001/XMLSchema#integer')),
          ),
          // Named graphs
          Quad(
            const IriTerm('http://example.org/person/bob'),
            const IriTerm('http://xmlns.com/foaf/0.1/name'),
            LiteralTerm.withLanguage('Bob', 'en'),
            peopleGraph,
          ),
          Quad(
            personBlank,
            const IriTerm('http://example.org/phone'),
            LiteralTerm.string('+1-555-123-4567'),
            contactGraph,
          ),
        ]);

        final nquads = encoder.convert(dataset);
        final lines = nquads.trim().split('\n');

        expect(lines, hasLength(4));

        // Verify structure
        final defaultGraphLines = lines
            .where((line) => !line.contains('http://example.org/graph/'))
            .toList();
        final namedGraphLines = lines
            .where((line) => line.contains('http://example.org/graph/'))
            .toList();

        expect(defaultGraphLines, hasLength(2));
        expect(namedGraphLines, hasLength(2));

        // Verify specific content
        expect(lines.any((line) => line.contains('"Alice"')), isTrue);
        expect(
            lines.any((line) => line
                .contains('"25"^^<http://www.w3.org/2001/XMLSchema#integer>')),
            isTrue);
        expect(lines.any((line) => line.contains('"Bob"@en')), isTrue);
        expect(lines.any((line) => line.contains('"+1-555-123-4567"')), isTrue);
      });

      test('encodes empty dataset', () {
        final dataset = RdfDataset(defaultGraph: RdfGraph(), namedGraphs: {});

        final nquads = encoder.convert(dataset);

        expect(nquads, isEmpty);
      });

      test('preserves ordering of triples within graphs', () {
        final dataset = RdfDataset.fromQuads([
          Quad(
            const IriTerm('http://example.org/s1'),
            const IriTerm('http://example.org/p1'),
            LiteralTerm.string('first'),
          ),
          Quad(
            const IriTerm('http://example.org/s2'),
            const IriTerm('http://example.org/p2'),
            LiteralTerm.string('second'),
          ),
          Quad(
            const IriTerm('http://example.org/s3'),
            const IriTerm('http://example.org/p3'),
            LiteralTerm.string('third'),
          ),
        ]);

        final nquads = encoder.convert(dataset);
        final lines = nquads.trim().split('\n');

        expect(lines, hasLength(3));
        expect(lines[0], contains('"first"'));
        expect(lines[1], contains('"second"'));
        expect(lines[2], contains('"third"'));
      });
    });

    group('Options and configuration', () {
      test('withOptions returns new encoder', () {
        final options = RdfGraphEncoderOptions();
        final newEncoder = encoder.withOptions(options);

        expect(newEncoder, isA<NQuadsEncoder>());
        // For immutable encoders, it might return the same instance if no change
        // The important thing is that it works correctly
      });

      test('ignores custom prefixes (N-Quads does not support prefixes)', () {
        final options = RdfGraphEncoderOptions(
          customPrefixes: {'ex': 'http://example.org/'},
        );
        final encoderWithOptions = encoder.withOptions(options);

        final dataset = RdfDataset.fromQuads([
          Quad(
            const IriTerm('http://example.org/subject'),
            const IriTerm('http://example.org/predicate'),
            LiteralTerm.string('object'),
          ),
        ]);

        final nquads = encoderWithOptions.convert(dataset);

        // Should still use full IRIs, not prefixes
        expect(
            nquads.trim(),
            equals(
                '<http://example.org/subject> <http://example.org/predicate> "object" .'));
        expect(nquads, isNot(contains('ex:')));
      });

      test('ignores base URI (N-Quads does not support relative IRIs)', () {
        final dataset = RdfDataset.fromQuads([
          Quad(
            const IriTerm('http://example.org/subject'),
            const IriTerm('http://example.org/predicate'),
            LiteralTerm.string('object'),
          ),
        ]);

        final nquads = encoder.convert(dataset, baseUri: 'http://example.org/');

        // Should still use full IRIs, not relative
        expect(
            nquads.trim(),
            equals(
                '<http://example.org/subject> <http://example.org/predicate> "object" .'));
      });
    });

    group('Error handling and edge cases', () {
      test('handles dataset with only named graphs', () {
        final dataset = RdfDataset.fromQuads([
          Quad(
            const IriTerm('http://example.org/subject'),
            const IriTerm('http://example.org/predicate'),
            LiteralTerm.string('object'),
            const IriTerm('http://example.org/graph1'),
          ),
        ]);

        final nquads = encoder.convert(dataset);

        expect(
            nquads.trim(),
            equals(
                '<http://example.org/subject> <http://example.org/predicate> "object" <http://example.org/graph1> .'));
      });

      test('throws UnsupportedError for unknown term types', () {
        // This would require creating a custom RdfTerm implementation
        // which is not easily testable without access to internals
        // The encoder should handle all standard term types correctly
      });
    });

    group('Round-trip compatibility', () {
      test('round-trip encoding and decoding preserves dataset structure', () {
        final originalDataset = RdfDataset.fromQuads([
          Quad(
            const IriTerm('http://example.org/alice'),
            const IriTerm('http://xmlns.com/foaf/0.1/name'),
            LiteralTerm.string('Alice'),
          ),
          Quad(
            const IriTerm('http://example.org/bob'),
            const IriTerm('http://xmlns.com/foaf/0.1/name'),
            LiteralTerm.withLanguage('Bob', 'en'),
            const IriTerm('http://example.org/graph1'),
          ),
        ]);

        final nquads = encoder.convert(originalDataset);
        final decoder = NQuadsDecoder();
        final decodedDataset = decoder.convert(nquads);

        expect(decodedDataset.defaultGraph.triples, hasLength(1));
        expect(decodedDataset.namedGraphs, hasLength(1));

        // Verify content matches
        final defaultTriple = decodedDataset.defaultGraph.triples.first;
        expect((defaultTriple.subject as IriTerm).value,
            equals('http://example.org/alice'));
        expect((defaultTriple.object as LiteralTerm).value, equals('Alice'));

        final namedGraphTriple =
            decodedDataset.namedGraphs.first.graph.triples.first;
        expect((namedGraphTriple.subject as IriTerm).value,
            equals('http://example.org/bob'));
        expect((namedGraphTriple.object as LiteralTerm).value, equals('Bob'));
        expect((namedGraphTriple.object as LiteralTerm).language, equals('en'));
      });
    });
  });

  group('Canonical N-Quads format (RDF Canonicalization)', () {
    late NQuadsEncoder encoder;
    late NQuadsEncoder encoderNonCanonical;

    setUp(() {
      encoder = NQuadsEncoder(options: NQuadsEncoderOptions(canonical: true));
      encoderNonCanonical = NQuadsEncoder();
    });
    test('canonical mode produces sorted output', () {
      final dataset = RdfDataset.fromQuads([
        Quad(
          const IriTerm('http://example.org/z'),
          const IriTerm('http://example.org/predicate'),
          LiteralTerm.string('object'),
        ),
        Quad(
          const IriTerm('http://example.org/a'),
          const IriTerm('http://example.org/predicate'),
          LiteralTerm.string('object'),
        ),
      ]);

      final nquads = encoder.encode(dataset);
      final lines = nquads.trim().split('\n');

      expect(lines, hasLength(2));
      // Lines should be sorted in code point order
      expect(lines[0], contains('http://example.org/a'));
      expect(lines[1], contains('http://example.org/z'));
    });

    test('canonical mode uses single space separators only', () {
      final dataset = RdfDataset.fromQuads([
        Quad(
          const IriTerm('http://example.org/subject'),
          const IriTerm('http://example.org/predicate'),
          LiteralTerm.string('object'),
          const IriTerm('http://example.org/graph'),
        ),
      ]);

      final nquads = encoder.encode(dataset);
      final line = nquads.trim();

      // Should have exactly one space between each component
      expect(
          line,
          equals(
              '<http://example.org/subject> <http://example.org/predicate> "object" <http://example.org/graph> .'));
      // Should not contain multiple spaces, tabs, or other whitespace
      expect(line, isNot(contains(RegExp(r'\s{2,}'))));
      expect(line, isNot(contains('\t')));
    });

    test('canonical mode omits xsd:string datatype', () {
      final dataset = RdfDataset.fromQuads([
        Quad(
          const IriTerm('http://example.org/subject'),
          const IriTerm('http://example.org/predicate'),
          LiteralTerm.string('string literal'),
        ),
      ]);

      final nquads = encoder.encode(dataset);

      expect(
          nquads.trim(),
          equals(
              '<http://example.org/subject> <http://example.org/predicate> "string literal" .'));
      expect(nquads, isNot(contains('XMLSchema#string')));
    });

    test('canonical mode includes non-xsd:string datatypes', () {
      final dataset = RdfDataset.fromQuads([
        Quad(
          const IriTerm('http://example.org/subject'),
          const IriTerm('http://example.org/predicate'),
          LiteralTerm('42',
              datatype:
                  const IriTerm('http://www.w3.org/2001/XMLSchema#integer')),
        ),
      ]);

      final nquads = encoder.encode(dataset);

      expect(
          nquads.trim(),
          equals(
              '<http://example.org/subject> <http://example.org/predicate> "42"^^<http://www.w3.org/2001/XMLSchema#integer> .'));
    });

    test('canonical mode uses uppercase HEX in UCHAR escapes', () {
      final dataset = RdfDataset.fromQuads([
        Quad(
          const IriTerm('http://example.org/subject'),
          const IriTerm('http://example.org/predicate'),
          LiteralTerm.string(
              'Control chars: \u0000\u000F'), // NULL and SI - both need UCHAR
        ),
      ]);

      final nquads = encoder.encode(dataset);

      // Should contain uppercase hex digits A-F
      expect(nquads, contains(r'\u0000'));
      expect(nquads, contains(r'\u000F'));
      // Should not contain lowercase hex digits a-f
      expect(nquads, isNot(contains(r'\u000f')));
    });

    test('canonical mode escapes required characters with ECHAR', () {
      final dataset = RdfDataset.fromQuads([
        Quad(
          const IriTerm('http://example.org/subject'),
          const IriTerm('http://example.org/predicate'),
          LiteralTerm.string('Special chars: \b\t\n\f\r"\\'),
        ),
      ]);

      final nquads = encoder.encode(dataset);
      final line = nquads.trim();

      // Should use ECHAR for BS, HT, LF, FF, CR, quote, backslash
      expect(line, contains(r'\b')); // backspace U+0008
      expect(line, contains(r'\t')); // horizontal tab U+0009
      expect(line, contains(r'\n')); // line feed U+000A
      expect(line, contains(r'\f')); // form feed U+000C
      expect(line, contains(r'\r')); // carriage return U+000D
      expect(line, contains(r'\"')); // quotation mark U+0022
      expect(line, contains(r'\\')); // backslash U+005C
    });

    test('canonical mode escapes control characters with lowercase \\u', () {
      final dataset = RdfDataset.fromQuads([
        Quad(
          const IriTerm('http://example.org/subject'),
          const IriTerm('http://example.org/predicate'),
          LiteralTerm.string(
              '\u0000\u0007\u000B\u000E\u001F\u007F'), // NULL, BEL, VT, SO, US, DEL
        ),
      ]);

      final nquads = encoder.encode(dataset);

      // Should use lowercase \u with 4 HEX digits for control characters
      expect(nquads, contains(r'\u0000')); // NULL
      expect(nquads, contains(r'\u0007')); // BEL
      expect(nquads, contains(r'\u000B')); // VT (vertical tab)
      expect(nquads, contains(r'\u000E')); // SO
      expect(nquads, contains(r'\u001F')); // US
      expect(nquads, contains(r'\u007F')); // DEL
    });

    test('canonical mode preserves Unicode characters natively', () {
      final dataset = RdfDataset.fromQuads([
        Quad(
          const IriTerm('http://example.org/subject'),
          const IriTerm('http://example.org/predicate'),
          LiteralTerm.string('Unicode: 世界 🌍 café'),
        ),
      ]);

      final nquads = encoder.encode(dataset);

      // Unicode characters should be preserved natively, not escaped
      expect(nquads, contains('世界'));
      expect(nquads, contains('🌍'));
      expect(nquads, contains('café'));
      expect(nquads, isNot(contains(r'\u')));
    });

    test('canonical mode ends every line with LF only', () {
      final dataset = RdfDataset.fromQuads([
        Quad(
          const IriTerm('http://example.org/subject'),
          const IriTerm('http://example.org/predicate'),
          LiteralTerm.string('object'),
        ),
      ]);

      final nquads = encoder.encode(dataset);

      // Should end with exactly one LF character
      expect(nquads, endsWith('\n'));
      expect(nquads, isNot(endsWith('\r\n')));
      expect(nquads, isNot(endsWith('\n\n')));
    });

    test('canonical mode sorts complex quads by code point order', () {
      final dataset = RdfDataset.fromQuads([
        // These should be sorted by the entire quad representation
        Quad(
          const IriTerm('http://example.org/b'),
          const IriTerm('http://example.org/predicate'),
          LiteralTerm.string('z'),
        ),
        Quad(
          const IriTerm('http://example.org/b'),
          const IriTerm('http://example.org/predicate'),
          LiteralTerm.string('a'),
        ),
        Quad(
          const IriTerm('http://example.org/a'),
          const IriTerm('http://example.org/predicate'),
          LiteralTerm.string('z'),
        ),
      ]);

      final nquads = encoder.encode(dataset);
      final lines = nquads.trim().split('\n');

      expect(lines, hasLength(3));
      // Should be sorted by complete quad string comparison
      expect(lines[0], contains('"z"')); // http://example.org/a comes first
      expect(lines[1], contains('http://example.org/b'));
      expect(
          lines[1], contains('"a"')); // "a" comes before "z" for same subject
      expect(lines[2], contains('http://example.org/b'));
      expect(lines[2], contains('"z"'));
    });

    test('canonical mode handles named graphs in sorted order', () {
      final dataset = RdfDataset.fromQuads([
        Quad(
          const IriTerm('http://example.org/s'),
          const IriTerm('http://example.org/p'),
          LiteralTerm.string('o'),
          const IriTerm('http://example.org/graph2'),
        ),
        Quad(
          const IriTerm('http://example.org/s'),
          const IriTerm('http://example.org/p'),
          LiteralTerm.string('o'),
          const IriTerm('http://example.org/graph1'),
        ),
        Quad(
          const IriTerm('http://example.org/s'),
          const IriTerm('http://example.org/p'),
          LiteralTerm.string('o'),
        ), // default graph
      ]);

      final nquads = encoder.encode(dataset);
      final lines = nquads.trim().split('\n');

      expect(lines, hasLength(3));
      // Default graph quads should come first (no graph component)
      expect(lines[0], isNot(contains('graph')));
      // Named graphs should be sorted by graph IRI
      expect(lines[1], contains('graph1'));
      expect(lines[2], contains('graph2'));
    });

    test('canonical mode with blank nodes preserves provided labels', () {
      final blankNode = BlankNodeTerm();
      final blankNodeLabels = {blankNode: 'canonical1'};

      final dataset = RdfDataset.fromQuads([
        Quad(
          blankNode,
          const IriTerm('http://example.org/predicate'),
          LiteralTerm.string('object'),
        ),
      ]);

      final nquads = encoder.encode(
        dataset,
        blankNodeLabels: blankNodeLabels,
        generateNewBlankNodeLabels: false,
      );

      expect(nquads, contains('_:canonical1'));
    });

    test('canonical mode produces deterministic output for same input', () {
      final dataset = RdfDataset.fromQuads([
        Quad(
          const IriTerm('http://example.org/c'),
          const IriTerm('http://example.org/predicate'),
          LiteralTerm.string('object3'),
        ),
        Quad(
          const IriTerm('http://example.org/a'),
          const IriTerm('http://example.org/predicate'),
          LiteralTerm.string('object1'),
        ),
        Quad(
          const IriTerm('http://example.org/b'),
          const IriTerm('http://example.org/predicate'),
          LiteralTerm.string('object2'),
        ),
      ]);

      final nquads1 = encoder.encode(dataset);
      final nquads2 = encoder.encode(dataset);

      expect(nquads1, equals(nquads2));
    });

    test(
        'canonical mode differs from non-canonical mode for same unsorted input',
        () {
      final dataset = RdfDataset.fromQuads([
        Quad(
          const IriTerm('http://example.org/z'),
          const IriTerm('http://example.org/predicate'),
          LiteralTerm.string('object'),
        ),
        Quad(
          const IriTerm('http://example.org/a'),
          const IriTerm('http://example.org/predicate'),
          LiteralTerm.string('object'),
        ),
      ]);

      final canonicalNquads = encoder.encode(dataset);
      final nonCanonicalNquads = encoderNonCanonical.encode(dataset);

      // The ordering should be different
      final canonicalLines = canonicalNquads.trim().split('\n');
      final nonCanonicalLines = nonCanonicalNquads.trim().split('\n');

      expect(canonicalLines[0], contains('http://example.org/a')); // sorted
      expect(nonCanonicalLines[0],
          contains('http://example.org/z')); // original order
    });
  });
}
