import 'package:rdf_core/rdf_core.dart';
import 'package:test/test.dart';

void main() {
  group('NQuadsDecoder', () {
    late NQuadsDecoder decoder;

    setUp(() {
      decoder = NQuadsDecoder();
    });

    group('Basic N-Quads parsing (N-Triples format)', () {
      test('parses simple triple with IRI subject, predicate, and object', () {
        const nquads =
            '<http://example.org/subject> <http://example.org/predicate> <http://example.org/object> .';

        final dataset = decoder.convert(nquads);

        expect(dataset.defaultGraph.triples, hasLength(1));
        expect(dataset.namedGraphs, isEmpty);

        final triple = dataset.defaultGraph.triples.first;
        expect((triple.subject as IriTerm).value,
            equals('http://example.org/subject'));
        expect((triple.predicate as IriTerm).value,
            equals('http://example.org/predicate'));
        expect((triple.object as IriTerm).value,
            equals('http://example.org/object'));
      });

      test('parses triple with literal object', () {
        const nquads =
            '<http://example.org/subject> <http://example.org/predicate> "Hello World" .';

        final dataset = decoder.convert(nquads);

        expect(dataset.defaultGraph.triples, hasLength(1));
        final triple = dataset.defaultGraph.triples.first;
        expect((triple.object as LiteralTerm).value, equals('Hello World'));
      });

      test('parses triple with language-tagged literal', () {
        const nquads =
            '<http://example.org/subject> <http://example.org/predicate> "Hello"@en .';

        final dataset = decoder.convert(nquads);

        final triple = dataset.defaultGraph.triples.first;
        final literal = triple.object as LiteralTerm;
        expect(literal.value, equals('Hello'));
        expect(literal.language, equals('en'));
      });

      test('parses triple with typed literal', () {
        const nquads =
            '<http://example.org/subject> <http://example.org/predicate> "42"^^<http://www.w3.org/2001/XMLSchema#integer> .';

        final dataset = decoder.convert(nquads);

        final triple = dataset.defaultGraph.triples.first;
        final literal = triple.object as LiteralTerm;
        expect(literal.value, equals('42'));
        expect(literal.datatype.value,
            equals('http://www.w3.org/2001/XMLSchema#integer'));
      });

      test('parses triple with blank node subject', () {
        const nquads = '_:b1 <http://example.org/predicate> "object" .';

        final dataset = decoder.convert(nquads);

        final triple = dataset.defaultGraph.triples.first;
        expect(triple.subject, isA<BlankNodeTerm>());
      });

      test('parses triple with blank node object', () {
        const nquads =
            '<http://example.org/subject> <http://example.org/predicate> _:b2 .';

        final dataset = decoder.convert(nquads);

        final triple = dataset.defaultGraph.triples.first;
        expect(triple.object, isA<BlankNodeTerm>());
      });

      test('maintains blank node identity across references', () {
        const nquads = '''
          _:b1 <http://example.org/predicate> "first" .
          _:b1 <http://example.org/predicate> "second" .
        ''';

        final dataset = decoder.convert(nquads);

        expect(dataset.defaultGraph.triples, hasLength(2));
        final subject1 = dataset.defaultGraph.triples.first.subject;
        final subject2 = dataset.defaultGraph.triples.last.subject;
        expect(identical(subject1, subject2), isTrue);
      });
    });

    group('N-Quads with Named Graphs', () {
      test('parses quad with named graph', () {
        const nquads =
            '<http://example.org/subject> <http://example.org/predicate> "object" <http://example.org/graph1> .';

        final dataset = decoder.convert(nquads);

        expect(dataset.defaultGraph.triples, isEmpty);
        expect(dataset.namedGraphs, hasLength(1));

        final namedGraph = dataset.namedGraphs.first;
        expect(
            _graphName(namedGraph.name), equals('http://example.org/graph1'));
        expect(namedGraph.graph.triples, hasLength(1));

        final triple = namedGraph.graph.triples.first;
        expect((triple.subject as IriTerm).value,
            equals('http://example.org/subject'));
        expect((triple.predicate as IriTerm).value,
            equals('http://example.org/predicate'));
        expect((triple.object as LiteralTerm).value, equals('object'));
      });

      test('parses mixed default graph and named graph quads', () {
        const nquads = '''
          <http://example.org/s1> <http://example.org/p1> "default graph" .
          <http://example.org/s2> <http://example.org/p2> "named graph" <http://example.org/graph1> .
          <http://example.org/s3> <http://example.org/p3> "another named" <http://example.org/graph2> .
        ''';

        final dataset = decoder.convert(nquads);

        expect(dataset.defaultGraph.triples, hasLength(1));
        expect(dataset.namedGraphs, hasLength(2));

        // Check default graph
        final defaultTriple = dataset.defaultGraph.triples.first;
        expect((defaultTriple.object as LiteralTerm).value,
            equals('default graph'));

        // Check named graphs
        final graph1 = dataset.namedGraphs.firstWhere(
            (ng) => _graphName(ng.name) == 'http://example.org/graph1');
        expect(graph1.graph.triples, hasLength(1));
        expect((graph1.graph.triples.first.object as LiteralTerm).value,
            equals('named graph'));

        final graph2 = dataset.namedGraphs.firstWhere(
            (ng) => _graphName(ng.name) == 'http://example.org/graph2');
        expect(graph2.graph.triples, hasLength(1));
        expect((graph2.graph.triples.first.object as LiteralTerm).value,
            equals('another named'));
      });

      test('groups multiple quads in same named graph', () {
        const nquads = '''
          <http://example.org/s1> <http://example.org/p1> "first" <http://example.org/graph1> .
          <http://example.org/s2> <http://example.org/p2> "second" <http://example.org/graph1> .
        ''';

        final dataset = decoder.convert(nquads);

        expect(dataset.namedGraphs, hasLength(1));
        final namedGraph = dataset.namedGraphs.first;
        expect(namedGraph.graph.triples, hasLength(2));
      });

      test('parses quad with blank node as graph name', () {
        const nquads =
            '<http://example.org/subject> <http://example.org/predicate> "object" _:graph1 .';

        final dataset = decoder.convert(nquads);

        expect(dataset.defaultGraph.triples, isEmpty);
        expect(dataset.namedGraphs, hasLength(1));

        final namedGraph = dataset.namedGraphs.first;
        expect(namedGraph.name, isA<BlankNodeTerm>());
        expect(namedGraph.graph.triples, hasLength(1));

        final triple = namedGraph.graph.triples.first;
        expect((triple.subject as IriTerm).value,
            equals('http://example.org/subject'));
        expect((triple.predicate as IriTerm).value,
            equals('http://example.org/predicate'));
        expect((triple.object as LiteralTerm).value, equals('object'));
      });

      test('groups multiple quads with same blank node graph name', () {
        const nquads = '''
          <http://example.org/s1> <http://example.org/p1> "first" _:bGraph .
          <http://example.org/s2> <http://example.org/p2> "second" _:bGraph .
        ''';

        final dataset = decoder.convert(nquads);

        expect(dataset.namedGraphs, hasLength(1));
        final namedGraph = dataset.namedGraphs.first;
        expect(namedGraph.name, isA<BlankNodeTerm>());
        expect(namedGraph.graph.triples, hasLength(2));
      });

      test('maintains blank node graph name identity across references', () {
        const nquads = '''
          <http://example.org/s1> <http://example.org/p1> "first" _:graph1 .
          <http://example.org/s2> <http://example.org/p2> "second" _:graph1 .
        ''';

        final dataset = decoder.convert(nquads);

        expect(dataset.namedGraphs, hasLength(1));
        final namedGraph = dataset.namedGraphs.first;
        expect(namedGraph.name, isA<BlankNodeTerm>());

        // Verify both quads reference the same blank node instance
        final quads = dataset.namedGraphs.expand((ng) =>
            ng.graph.triples.map((t) => (triple: t, graph: ng.name))).toList();
        expect(quads, hasLength(2));
        expect(identical(quads[0].graph, quads[1].graph), isTrue);
      });
    });

    group('String escaping and special characters', () {
      test('parses escaped characters in literals', () {
        const nquads =
            r'<http://example.org/subject> <http://example.org/predicate> "Line 1\nLine 2\tTabbed" .';

        final dataset = decoder.convert(nquads);

        final literal =
            dataset.defaultGraph.triples.first.object as LiteralTerm;
        expect(literal.value, equals('Line 1\nLine 2\tTabbed'));
      });

      test('parses escaped quotes in literals', () {
        const nquads =
            r'<http://example.org/subject> <http://example.org/predicate> "He said \"Hello\"" .';

        final dataset = decoder.convert(nquads);

        final literal =
            dataset.defaultGraph.triples.first.object as LiteralTerm;
        expect(literal.value, equals('He said "Hello"'));
      });

      test('parses Unicode escapes in literals', () {
        const nquads =
            r'<http://example.org/subject> <http://example.org/predicate> "Unicode: \u0048\u0065\u006C\u006C\u006F" .';

        final dataset = decoder.convert(nquads);

        final literal =
            dataset.defaultGraph.triples.first.object as LiteralTerm;
        expect(literal.value, equals('Unicode: Hello'));
      });

      test('parses escaped characters in IRIs', () {
        const nquads =
            r'<http://example.org/subject\>special> <http://example.org/predicate> "object" .';

        final dataset = decoder.convert(nquads);

        final subject = dataset.defaultGraph.triples.first.subject as IriTerm;
        expect(subject.value, equals('http://example.org/subject>special'));
      });
    });

    group('Comments and whitespace', () {
      test('ignores comment lines', () {
        const nquads = '''
          # This is a comment
          <http://example.org/s1> <http://example.org/p1> "object1" .
          # Another comment
          <http://example.org/s2> <http://example.org/p2> "object2" .
        ''';

        final dataset = decoder.convert(nquads);

        expect(dataset.defaultGraph.triples, hasLength(2));
      });

      test('handles empty lines', () {
        const nquads = '''
          <http://example.org/s1> <http://example.org/p1> "object1" .

          <http://example.org/s2> <http://example.org/p2> "object2" .

        ''';

        final dataset = decoder.convert(nquads);

        expect(dataset.defaultGraph.triples, hasLength(2));
      });

      test('handles mixed whitespace', () {
        const nquads =
            '\t  <http://example.org/s1>   <http://example.org/p1>    "object1"   . \r\n';

        final dataset = decoder.convert(nquads);

        expect(dataset.defaultGraph.triples, hasLength(1));
      });
    });

    group('Error handling', () {
      test('throws RdfDecoderException for missing period', () {
        const nquads =
            '<http://example.org/subject> <http://example.org/predicate> "object"';

        expect(
          () => decoder.convert(nquads),
          throwsA(isA<RdfDecoderException>().having(
            (e) => e.message,
            'message',
            contains('Missing period at end'),
          )),
        );
      });

      test('throws RdfDecoderException for invalid subject', () {
        const nquads =
            'invalid-subject <http://example.org/predicate> "object" .';

        expect(
          () => decoder.convert(nquads),
          throwsA(isA<RdfDecoderException>().having(
            (e) => e.message,
            'message',
            contains('Invalid subject'),
          )),
        );
      });

      test('throws RdfDecoderException for invalid predicate', () {
        const nquads =
            '<http://example.org/subject> invalid-predicate "object" .';

        expect(
          () => decoder.convert(nquads),
          throwsA(isA<RdfDecoderException>().having(
            (e) => e.message,
            'message',
            contains('Invalid predicate'),
          )),
        );
      });

      test('throws RdfDecoderException for unclosed literal quote', () {
        const nquads =
            '<http://example.org/subject> <http://example.org/predicate> "unclosed .';

        expect(
          () => decoder.convert(nquads),
          throwsA(isA<RdfDecoderException>().having(
            (e) => e.message,
            'message',
            contains('Missing closing quote'),
          )),
        );
      });

      test('throws RdfDecoderException for invalid datatype IRI', () {
        const nquads =
            '<http://example.org/subject> <http://example.org/predicate> "42"^^invalid-datatype .';

        expect(
          () => decoder.convert(nquads),
          throwsA(isA<RdfDecoderException>().having(
            (e) => e.message,
            'message',
            contains('Invalid datatype IRI'),
          )),
        );
      });

      test('throws RdfDecoderException for too few parts', () {
        const nquads =
            '<http://example.org/subject> <http://example.org/predicate> .';

        expect(
          () => decoder.convert(nquads),
          throwsA(isA<RdfDecoderException>().having(
            (e) => e.message,
            'message',
            contains('expected 3 or 4 parts'),
          )),
        );
      });

      test('throws RdfDecoderException for too many parts (invalid N-Quads)',
          () {
        const nquads =
            '<http://example.org/s> <http://example.org/p> "o" <http://example.org/g> extra .';

        expect(
          () => decoder.convert(nquads),
          throwsA(isA<RdfDecoderException>()),
        );
      });
    });

    group('Complex scenarios', () {
      test('parses large dataset with mixed content', () {
        const nquads = '''
          # Dataset with various features
          <http://example.org/person/alice> <http://xmlns.com/foaf/0.1/name> "Alice" .
          <http://example.org/person/alice> <http://xmlns.com/foaf/0.1/age> "25"^^<http://www.w3.org/2001/XMLSchema#integer> .
          <http://example.org/person/bob> <http://xmlns.com/foaf/0.1/name> "Bob"@en <http://example.org/graph/people> .
          _:contact <http://example.org/phone> "+1-555-123-4567" <http://example.org/graph/contacts> .
          <http://example.org/person/alice> <http://xmlns.com/foaf/0.1/knows> _:contact .
        ''';

        final dataset = decoder.convert(nquads);

        expect(dataset.defaultGraph.triples,
            hasLength(3)); // Alice name, age, and knows _:contact
        expect(dataset.namedGraphs, hasLength(2));

        // Verify named graphs are correctly organized
        final peopleGraph = dataset.namedGraphs.firstWhere(
            (ng) => _graphName(ng.name) == 'http://example.org/graph/people');
        expect(peopleGraph.graph.triples, hasLength(1));

        final contactsGraph = dataset.namedGraphs.firstWhere(
            (ng) => _graphName(ng.name) == 'http://example.org/graph/contacts');
        expect(contactsGraph.graph.triples, hasLength(1));
      });

      test('handles empty input', () {
        const nquads = '';

        final dataset = decoder.convert(nquads);

        expect(dataset.defaultGraph.triples, isEmpty);
        expect(dataset.namedGraphs, isEmpty);
      });

      test('handles input with only comments and whitespace', () {
        const nquads = '''
          # Just comments

          # And whitespace
        ''';

        final dataset = decoder.convert(nquads);

        expect(dataset.defaultGraph.triples, isEmpty);
        expect(dataset.namedGraphs, isEmpty);
      });
    });

    test('withOptions returns new decoder with same behavior', () {
      final options = RdfGraphDecoderOptions();
      final newDecoder = decoder.withOptions(options);

      expect(newDecoder, isA<NQuadsDecoder>());
      expect(identical(newDecoder, decoder), isFalse);

      // Test that it still works the same way
      const nquads =
          '<http://example.org/subject> <http://example.org/predicate> "object" .';
      final dataset = newDecoder.convert(nquads);
      expect(dataset.defaultGraph.triples, hasLength(1));
    });
  });
}

String _graphName(RdfGraphName name) {
  return switch (name) {
    IriTerm iri => iri.value,
    BlankNodeTerm bnode => bnode.toString(),
  };
}
