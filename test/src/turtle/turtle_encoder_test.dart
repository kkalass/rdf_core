// NOTE: Always use canonical RDF vocabularies (e.g., http://xmlns.com/foaf/0.1/) with http://, not https://
import 'package:rdf_core/src/graph/rdf_graph.dart';
import 'package:rdf_core/src/graph/rdf_term.dart';
import 'package:rdf_core/src/graph/triple.dart';
import 'package:rdf_core/src/turtle/turtle_encoder.dart';
import 'package:rdf_core/src/vocab/xsd.dart';
import 'package:test/test.dart';

void main() {
  late TurtleEncoder encoder;

  setUp(() {
    encoder = TurtleEncoder();
  });

  group('TurtleEncoder', () {
    test('should serialize empty graph', () {
      // Arrange
      final graph = RdfGraph();

      // Act
      final result = encoder.convert(graph);

      // Assert
      expect(result, isEmpty);
    });

    test('should serialize graph with prefixes', () {
      // Arrange
      final graph = RdfGraph(
        triples: [
          Triple(
            IriTerm("http://example.org/test"),
            IriTerm("http://my-ontology.org/test#deleted"),
            LiteralTerm("true", datatype: Xsd.boolean),
          ),
        ],
      );
      final prefixes = {'ex': 'http://example.org/'};

      // Act
      final result = encoder
          .withOptions(TurtleEncoderOptions(customPrefixes: prefixes))
          .convert(graph);

      // Assert
      expect(
        result,
        contains('@prefix xsd: <http://www.w3.org/2001/XMLSchema#> .'),
      );
      expect(result, contains('@prefix ex: <http://example.org/> .'));
    });

    test('should serialize a simple triple', () {
      // Arrange
      final graph = RdfGraph(
        triples: [
          Triple(
            IriTerm('http://example.org/alice'),
            IriTerm('http://example.org/knows'),
            IriTerm('http://example.org/bob'),
          ),
        ],
      );

      // Act
      final result = encoder.convert(graph);

      // Assert
      expect(result, contains('@prefix ex: <http://example.org/> .'));
      expect(result, contains('ex:alice ex:knows ex:bob .'));
    });

    test('should serialize a simple triple, optionally without prefix', () {
      // Arrange
      final graph = RdfGraph(
        triples: [
          Triple(
            IriTerm('http://example.org/alice'),
            IriTerm('http://example.org/knows'),
            IriTerm('http://example.org/bob'),
          ),
        ],
      );

      // Act
      final result = encoder
          .withOptions(TurtleEncoderOptions(generateMissingPrefixes: false))
          .convert(graph);

      // Assert
      expect(result, isNot(contains('@prefix ex: <http://example.org/> .')));
      expect(
        result,
        contains(
          '<http://example.org/alice> <http://example.org/knows> <http://example.org/bob> .',
        ),
      );
    });

    test('should use rdf:type abbreviation', () {
      // Arrange
      final graph = RdfGraph(
        triples: [
          Triple(
            IriTerm('http://example.org/alice'),
            IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#type'),
            IriTerm('http://example.org/Person'),
          ),
        ],
      );

      // Act
      final result = encoder.convert(graph);

      // Assert
      expect(result, contains('ex:alice a ex:Person .'));
      expect(
        result,
        isNot(contains('<http://www.w3.org/1999/02/22-rdf-syntax-ns#type>')),
      );
    });

    test('should group triples by subject', () {
      // Arrange
      final graph = RdfGraph(
        triples: [
          Triple(
            IriTerm('http://example.org/alice'),
            IriTerm('http://example.org/name'),
            LiteralTerm.string('Alice'),
          ),
          Triple(
            IriTerm('http://example.org/alice'),
            IriTerm('http://example.org/age'),
            LiteralTerm(
              "30",
              datatype: IriTerm('http://www.w3.org/2001/XMLSchema#integer'),
            ),
          ),
          Triple(
            IriTerm('http://example.org/bob'),
            IriTerm('http://example.org/name'),
            LiteralTerm.string('Bob'),
          ),
        ],
      );

      // Act
      final result = encoder.convert(graph);

      // Assert
      expect(result, contains('ex:alice ex:age 30;'));
      expect(result, contains('ex:alice ex:age 30;\n    ex:name "Alice" .'));
      expect(result, contains('ex:bob ex:name "Bob" .'));

      // Überprüfe die strukturellen Eigenschaften der Ausgabe statt fester Zeilenanzahlen
      final lines = result.split('\n');
      expect(lines.any((line) => line.contains('@prefix xsd:')), isTrue);
      expect(lines.any((line) => line.isEmpty), isTrue);
      expect(lines.any((line) => line.contains('ex:alice')), isTrue);
      expect(lines.any((line) => line.contains('ex:bob')), isTrue);
      expect(lines.any((line) => line.contains('ex:age')), isTrue);
    });

    test('should group multiple objects for the same predicate', () {
      // Arrange
      final graph = RdfGraph(
        triples: [
          Triple(
            IriTerm('http://example.org/alice'),
            IriTerm('http://example.org/likes'),
            IriTerm('http://example.org/chocolate'),
          ),
          Triple(
            IriTerm('http://example.org/alice'),
            IriTerm('http://example.org/likes'),
            IriTerm('http://example.org/pizza'),
          ),
        ],
      );

      // Act
      final result = encoder.convert(graph);

      // Assert
      expect(result, contains('ex:alice ex:likes ex:chocolate, ex:pizza .'));
    });

    test('should handle blank nodes', () {
      // Arrange
      final blankNode = BlankNodeTerm();
      final graph = RdfGraph(
        triples: [
          Triple(
            IriTerm('http://example.org/statement'),
            IriTerm('http://example.org/source'),
            blankNode,
          ),
        ],
      );

      // Act
      final result = encoder.convert(graph);

      // Assert
      // We should have a blank node reference, but we can't check the exact label
      expect(result, matches('ex:statement ex:source _:b[0-9]+ .'));
    });

    test('should handle literals with language tags', () {
      // Arrange
      final graph = RdfGraph(
        triples: [
          Triple(
            IriTerm('http://example.org/book'),
            IriTerm('http://example.org/title'),
            LiteralTerm.withLanguage('Le Petit Prince', 'fr'),
          ),
        ],
      );

      // Act
      final result = encoder.convert(graph);

      // Assert
      expect(result, contains('ex:book ex:title "Le Petit Prince"@fr .'));
    });

    test('should handle literals with quotes and backslashes', () {
      // Arrange
      final graph = RdfGraph(
        triples: [
          Triple(
            IriTerm('http://example.org/book'),
            IriTerm('http://example.org/title'),
            LiteralTerm.string(
              'Le "Petit" \\ Prince\n hopes for a better world\r',
            ),
          ),
        ],
      );

      // Act
      final result = encoder.convert(graph);

      // Assert
      expect(
        result,
        contains(
          'ex:book ex:title "Le \\"Petit\\" \\\\ Prince\\n hopes for a better world\\r" .',
        ),
      );
    });

    test(
      'should handle complex graphs with multiple subjects and predicates and make use of prefixes',
      () {
        // Arrange
        final graph = RdfGraph(
          triples: [
            // Person 1
            Triple(
              IriTerm('http://example.org/alice'),
              IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#type'),
              IriTerm('http://xmlns.com/foaf/0.1/Person'),
            ),
            Triple(
              IriTerm('http://example.org/alice'),
              IriTerm('http://xmlns.com/foaf/0.1/name'),
              LiteralTerm.string('Alice'),
            ),
            Triple(
              IriTerm('http://example.org/alice'),
              IriTerm('http://xmlns.com/foaf/0.1/knows'),
              IriTerm('http://example.org/bob'),
            ),
            // Person 2
            Triple(
              IriTerm('http://example.org/bob'),
              IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#type'),
              IriTerm('http://xmlns.com/foaf/0.1/Person'),
            ),
            Triple(
              IriTerm('http://example.org/bob'),
              IriTerm('http://xmlns.com/foaf/0.1/name'),
              LiteralTerm.string('Bob'),
            ),
          ],
        );

        final prefixes = {'ex': 'http://example.org/'};

        // Act
        final result = encoder
            .withOptions(TurtleEncoderOptions(customPrefixes: prefixes))
            .convert(graph);

        // Assert
        expect(result, contains('@prefix ex: <http://example.org/> .'));
        expect(
          result,
          contains('@prefix foaf: <http://xmlns.com/foaf/0.1/> .'),
        );
        expect(result, contains('ex:alice a foaf:Person'));
        expect(result, contains('foaf:name "Alice"'));
        expect(result, contains('    foaf:knows ex:bob'));
        expect(result, contains('ex:bob a foaf:Person'));
        expect(result, contains('    foaf:name "Bob"'));
      },
    );

    test('should handle Unicode characters in literals', () {
      // Arrange
      final graph = RdfGraph(
        triples: [
          Triple(
            IriTerm('http://example.org/entity'),
            IriTerm('http://example.org/label'),
            LiteralTerm.string('Unicode: € ♥ © ≈ ♠ ⚓ 😀'),
          ),
        ],
      );

      // Act
      final result = encoder.convert(graph);

      // Assert
      // Check for standard Unicode characters (below U+FFFF)
      expect(
        result,
        contains('Unicode: \\u20AC \\u2665 \\u00A9 \\u2248 \\u2660 \\u2693'),
      );

      // The emoji can be represented either as surrogate pair or as a single U+codepoint
      // In Dart, code units above U+FFFF are represented as UTF-16 surrogate pairs
      // Check for either representation (surrogate pairs or 8-digit escape)
      final containsEmoji =
          result.contains('\\uD83D\\uDE00') || result.contains('\\U0001F600');
      expect(
        containsEmoji,
        isTrue,
        reason:
            'Output should contain emoji 😀 in either surrogate pair or 8-digit format',
      );
    });

    test('should handle non-printable ASCII characters', () {
      // Arrange
      final graph = RdfGraph(
        triples: [
          Triple(
            IriTerm('http://example.org/entity'),
            IriTerm('http://example.org/value'),
            LiteralTerm.string('Control chars: \u0001 \u0007 \u001F'),
          ),
        ],
      );

      // Act
      final result = encoder.convert(graph);

      // Assert
      // Use case-insensitive regex to match the escape sequences
      expect(
        result,
        matches(
          RegExp(
            r'Control chars: \\u0001 \\u0007 \\u001[fF]',
            caseSensitive: false,
          ),
        ),
      );
    });

    test('should handle empty prefixes properly', () {
      // Arrange
      final graph = RdfGraph(
        triples: [
          Triple(
            IriTerm('http://example.org/default#resource'),
            IriTerm('http://example.org/default#property'),
            LiteralTerm.string('value'),
          ),
        ],
      );

      final prefixes = {'': 'http://example.org/default#'};

      // Act
      final result = encoder
          .withOptions(TurtleEncoderOptions(customPrefixes: prefixes))
          .convert(graph);

      // Assert
      expect(result, contains('@prefix : <http://example.org/default#> .'));
      expect(result, contains(':resource :property "value" .'));
    });

    test('should format multiple predicates and objects correctly', () {
      // Arrange
      final graph = RdfGraph(
        triples: [
          Triple(
            IriTerm('http://example.org/subject'),
            IriTerm('http://example.org/predicate1'),
            LiteralTerm.string('value1'),
          ),
          Triple(
            IriTerm('http://example.org/subject'),
            IriTerm('http://example.org/predicate1'),
            LiteralTerm.string('value2'),
          ),
          Triple(
            IriTerm('http://example.org/subject'),
            IriTerm('http://example.org/predicate2'),
            LiteralTerm.string('value3'),
          ),
          Triple(
            IriTerm('http://example.org/subject'),
            IriTerm('http://example.org/predicate2'),
            LiteralTerm.string('value4'),
          ),
        ],
      );

      // Act
      final result = encoder.convert(graph);

      // Assert
      // Check for correct indentation and separators
      expect(
        result,
        contains(
          'ex:subject ex:predicate1 "value1", "value2";\n    ex:predicate2 "value3", "value4" .',
        ),
      );
    });

    test('should handle both xsd:string and language-tagged literals', () {
      // Arrange
      final graph = RdfGraph(
        triples: [
          Triple(
            IriTerm('http://example.org/book'),
            IriTerm('http://example.org/title'),
            LiteralTerm.string('The Little Prince'),
          ),
          Triple(
            IriTerm('http://example.org/book'),
            IriTerm('http://example.org/title'),
            LiteralTerm.withLanguage('Le Petit Prince', 'fr'),
          ),
          Triple(
            IriTerm('http://example.org/book'),
            IriTerm('http://example.org/title'),
            LiteralTerm.withLanguage('Der kleine Prinz', 'de'),
          ),
        ],
      );

      // Act
      final result = encoder.convert(graph);

      // Assert
      expect(
        result,
        contains(
          'ex:book ex:title "The Little Prince", "Le Petit Prince"@fr, "Der kleine Prinz"@de .',
        ),
      );
    });

    test('should correctly use custom prefixes when available', () {
      // Arrange
      final graph = RdfGraph(
        triples: [
          Triple(
            IriTerm('http://example.org/book/littleprince'),
            IriTerm('http://purl.org/dc/terms/title'),
            LiteralTerm.string('The Little Prince'),
          ),
        ],
      );

      final customPrefixes = {
        'book': 'http://example.org/book/',
        'dc': 'http://purl.org/dc/terms/',
      };

      // Act
      final result = encoder
          .withOptions(TurtleEncoderOptions(customPrefixes: customPrefixes))
          .convert(graph);

      // Assert
      expect(result, contains('@prefix book: <http://example.org/book/> .'));
      expect(result, contains('@prefix dc: <http://purl.org/dc/terms/> .'));
      expect(
        result,
        contains('book:littleprince dc:title "The Little Prince" .'),
      );
    });

    test(
      'should automatically add and use foaf prefix when relevant IRIs are present',
      () {
        final graph = RdfGraph(
          triples: [
            Triple(
              IriTerm('http://example.org/alice'),
              IriTerm('http://xmlns.com/foaf/0.1/name'),
              LiteralTerm.string('Alice'),
            ),
            Triple(
              IriTerm('http://example.org/alice'),
              IriTerm('http://xmlns.com/foaf/0.1/knows'),
              IriTerm('http://example.org/bob'),
            ),
          ],
        );

        final serializer = TurtleEncoder();
        final result = serializer.convert(graph);

        expect(
          result,
          contains('@prefix foaf: <http://xmlns.com/foaf/0.1/> .'),
        );
        expect(result, contains('foaf:name "Alice"'));
        expect(result, isNot(contains('@prefix xsd: ')));
        expect(result, contains('foaf:name "Alice"'));
        expect(result, contains('foaf:knows ex:bob'));
      },
    );

    test('should handle custom prefixes correctly', () {
      // Arrange
      final graph = RdfGraph(
        triples: [
          Triple(
            IriTerm('http://example.org/book/littleprince'),
            IriTerm('http://purl.org/dc/terms/title'),
            LiteralTerm.string('The Little Prince'),
          ),
        ],
      );

      final customPrefixes = {
        'book': 'http://example.org/book/',
        'dc': 'http://purl.org/dc/terms/',
      };

      // Act
      final result = encoder
          .withOptions(TurtleEncoderOptions(customPrefixes: customPrefixes))
          .convert(graph);

      // Assert
      expect(result, contains('@prefix book: <http://example.org/book/> .'));
      expect(result, contains('@prefix dc: <http://purl.org/dc/terms/> .'));
      expect(
        result,
        contains('book:littleprince dc:title "The Little Prince" .'),
      );
    });

    test('should handle overlapping prefixes correctly', () {
      // Arrange
      final graph = RdfGraph.fromTriples([
        Triple(
          IriTerm('http://example.org/subject'),
          IriTerm('http://example.org/vocabulary/predicate'),
          LiteralTerm.string('object'),
        ),
      ]);

      final customPrefixes = {
        'ex': 'http://example.org/',
        'vocab': 'http://example.org/vocabulary/',
      };

      // Act
      final result = encoder
          .withOptions(TurtleEncoderOptions(customPrefixes: customPrefixes))
          .convert(graph);

      // Assert
      expect(result, contains('@prefix ex: <http://example.org/> .'));
      expect(
        result,
        contains('@prefix vocab: <http://example.org/vocabulary/> .'),
      );

      // Should use the more specific prefix for the predicate
      expect(result, contains('ex:subject vocab:predicate "object" .'));
      // Should NOT use the less specific prefix with the remaining part as local name
      expect(
        result,
        isNot(contains('ex:subject ex:vocabulary/predicate "object" .')),
      );
    });

    test('should maintain BlankNode identity in serialization', () {
      // Create a single blank node used multiple times
      final blankNode = BlankNodeTerm();

      final graph = RdfGraph.fromTriples([
        Triple(
          IriTerm('http://example.org/resource1'),
          IriTerm('http://example.org/property'),
          blankNode,
        ),
        Triple(
          IriTerm('http://example.org/resource2'),
          IriTerm('http://example.org/property'),
          blankNode,
        ),
        Triple(
          blankNode,
          IriTerm('http://example.org/type'),
          LiteralTerm.string('Shared blank node'),
        ),
      ]);

      final result = encoder.convert(graph);

      // The blank node should have the same label in all usages
      final matches = RegExp(r'_:b(\d+)').allMatches(result).toList();
      expect(
        matches.length,
        equals(3),
        reason: 'Should have 3 occurrences of the same blank node',
      );

      // Extract the label to verify it's the same in all occurrences
      final label = matches.first.group(1);
      for (final match in matches) {
        expect(
          match.group(1),
          equals(label),
          reason: 'All blank node occurrences should have the same label',
        );
      }
    });

    test('should correctly serialize native literal types', () {
      // Arrange
      final graph = RdfGraph(
        triples: [
          // Integer literal
          Triple(
            IriTerm('http://example.org/resource1'),
            IriTerm('http://example.org/hasInteger'),
            LiteralTerm.integer(42),
          ),
          // Decimal literal
          Triple(
            IriTerm('http://example.org/resource1'),
            IriTerm('http://example.org/hasDecimal'),
            LiteralTerm.decimal(3.14),
          ),
          // Boolean literal
          Triple(
            IriTerm('http://example.org/resource1'),
            IriTerm('http://example.org/isEnabled'),
            LiteralTerm.boolean(true),
          ),
          // Multiple native literals with the same predicate
          Triple(
            IriTerm('http://example.org/resource2'),
            IriTerm('http://example.org/hasValue'),
            LiteralTerm.integer(123),
          ),
          Triple(
            IriTerm('http://example.org/resource2'),
            IriTerm('http://example.org/hasValue'),
            LiteralTerm.decimal(45.67),
          ),
          Triple(
            IriTerm('http://example.org/resource2'),
            IriTerm('http://example.org/hasValue'),
            LiteralTerm.boolean(false),
          ),
        ],
      );

      // Act
      final result = encoder.convert(graph);

      // Assert
      // Check for integer serialization (without quotes or datatype)
      expect(result, contains('ex:hasInteger 42'));

      // Check for decimal serialization (without quotes or datatype)
      expect(result, contains('ex:hasDecimal 3.14'));

      // Check for boolean serialization (without quotes or datatype)
      expect(result, contains('ex:isEnabled true'));

      // Check for multiple literals with the same predicate
      expect(result, contains('ex:hasValue 123, 45.67, false'));

      // These should NOT be serialized with quotes and datatype syntax
      expect(
        result,
        isNot(contains('"42"^^<http://www.w3.org/2001/XMLSchema#integer>')),
      );
      expect(
        result,
        isNot(contains('"3.14"^^<http://www.w3.org/2001/XMLSchema#decimal>')),
      );
      expect(
        result,
        isNot(contains('"true"^^<http://www.w3.org/2001/XMLSchema#boolean>')),
      );

      // Check the structure of the output
      expect(
        result,
        contains('@prefix xsd: <http://www.w3.org/2001/XMLSchema#>'),
      );

      // Check for proper grouping of triples by subject
      expect(result, contains('ex:resource1 ex:hasDecimal 3.14'));
    });

    test('should correctly serialize RDF collections', () {
      // Create an RDF collection structure (a linked list using rdf:first, rdf:rest, rdf:nil)
      final head = BlankNodeTerm();
      final node1 = BlankNodeTerm();
      final node2 = BlankNodeTerm();

      final graph = RdfGraph.fromTriples([
        // Use the collection as an object in a triple
        Triple(
          IriTerm('http://example.org/subject'),
          IriTerm('http://example.org/predicate'),
          head,
        ),

        // Define the collection structure
        Triple(
          head,
          IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#first'),
          LiteralTerm.string('item1'),
        ),
        Triple(
          head,
          IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#rest'),
          node1,
        ),

        Triple(
          node1,
          IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#first'),
          LiteralTerm.string('item2'),
        ),
        Triple(
          node1,
          IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#rest'),
          node2,
        ),

        Triple(
          node2,
          IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#first'),
          LiteralTerm.string('item3'),
        ),
        Triple(
          node2,
          IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#rest'),
          IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#nil'),
        ),
      ]);

      // Act
      final result = encoder.convert(graph);

      // Assert
      expect(
        result,
        contains('ex:subject ex:predicate ("item1" "item2" "item3") .'),
        reason:
            'Collection should be serialized using compact Turtle notation ("item1" "item2" "item3")',
      );

      // Ensure the collection triples themselves are not redundantly serialized
      expect(
        result,
        isNot(contains('<http://www.w3.org/1999/02/22-rdf-syntax-ns#first>')),
        reason:
            'Collection structure triples should not be redundantly serialized',
      );
      expect(
        result,
        isNot(contains('<http://www.w3.org/1999/02/22-rdf-syntax-ns#rest>')),
        reason:
            'Collection structure triples should not be redundantly serialized',
      );
    });

    test('should correctly serialize nested RDF collections', () {
      // Create a nested RDF collection (a collection containing another collection)
      final outerHead = BlankNodeTerm();
      final outerNode1 = BlankNodeTerm();
      final outerNode2 = BlankNodeTerm();

      // Inner collection
      final innerHead = BlankNodeTerm();
      final innerNode1 = BlankNodeTerm();

      final graph = RdfGraph.fromTriples([
        // Main triple using the outer collection
        Triple(
          IriTerm('http://example.org/subject'),
          IriTerm('http://example.org/predicate'),
          outerHead,
        ),

        // Outer collection structure
        Triple(
          outerHead,
          IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#first'),
          LiteralTerm.string('item1'),
        ),
        Triple(
          outerHead,
          IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#rest'),
          outerNode1,
        ),

        Triple(
          outerNode1,
          IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#first'),
          innerHead,
        ), // This item is itself a collection
        Triple(
          outerNode1,
          IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#rest'),
          outerNode2,
        ),

        Triple(
          outerNode2,
          IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#first'),
          LiteralTerm.string('item3'),
        ),
        Triple(
          outerNode2,
          IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#rest'),
          IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#nil'),
        ),

        // Inner collection structure
        Triple(
          innerHead,
          IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#first'),
          LiteralTerm.string('nested1'),
        ),
        Triple(
          innerHead,
          IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#rest'),
          innerNode1,
        ),

        Triple(
          innerNode1,
          IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#first'),
          LiteralTerm.string('nested2'),
        ),
        Triple(
          innerNode1,
          IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#rest'),
          IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#nil'),
        ),
      ]);

      // Act
      final result = encoder.convert(graph);

      // Assert
      expect(
        result,
        contains(
          'ex:subject ex:predicate ("item1" ("nested1" "nested2") "item3") .',
        ),
        reason:
            'Nested collection should be serialized as ("item1" ("nested1" "nested2") "item3")',
      );
    });

    test('should correctly serialize empty RDF collections', () {
      final graph = RdfGraph.fromTriples([
        // Use rdf:nil directly as object to represent an empty collection
        Triple(
          IriTerm('http://example.org/subject'),
          IriTerm('http://example.org/predicate'),
          IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#nil'),
        ),
      ]);

      // Act
      final result = encoder.convert(graph);

      // Assert
      expect(
        result,
        contains('ex:subject ex:predicate () .'),
        reason: 'Empty collection should be serialized as ()',
      );
    });

    test(
      'should correctly serialize RDF collections with different value types',
      () {
        final head = BlankNodeTerm();
        final node1 = BlankNodeTerm();
        final node2 = BlankNodeTerm();
        final node3 = BlankNodeTerm();

        final graph = RdfGraph.fromTriples([
          // Main triple using the collection
          Triple(
            IriTerm('http://example.org/subject'),
            IriTerm('http://example.org/predicate'),
            head,
          ),

          // Collection with various types of values
          Triple(
            head,
            IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#first'),
            LiteralTerm.string('string'),
          ),
          Triple(
            head,
            IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#rest'),
            node1,
          ),

          Triple(
            node1,
            IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#first'),
            LiteralTerm.integer(42),
          ),
          Triple(
            node1,
            IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#rest'),
            node2,
          ),

          Triple(
            node2,
            IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#first'),
            LiteralTerm.boolean(true),
          ),
          Triple(
            node2,
            IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#rest'),
            node3,
          ),

          Triple(
            node3,
            IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#first'),
            IriTerm('http://example.org/resource'),
          ),
          Triple(
            node3,
            IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#rest'),
            IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#nil'),
          ),
        ]);

        // Act
        final result = encoder.convert(graph);

        // Assert
        expect(
          result,
          contains('ex:subject ex:predicate ("string" 42 true ex:resource) .'),
          reason:
              'Collection with mixed value types should serialize each value correctly',
        );
      },
    );

    test('should correctly handle multiple RDF collections in a graph', () {
      // Create two separate collections
      final collection1Head = BlankNodeTerm();
      final collection1Node1 = BlankNodeTerm();

      final collection2Head = BlankNodeTerm();
      final collection2Node1 = BlankNodeTerm();

      final graph = RdfGraph.fromTriples([
        // First triple with first collection
        Triple(
          IriTerm('http://example.org/subject1'),
          IriTerm('http://example.org/predicate1'),
          collection1Head,
        ),

        // First collection structure
        Triple(
          collection1Head,
          IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#first'),
          LiteralTerm.string('collection1-item1'),
        ),
        Triple(
          collection1Head,
          IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#rest'),
          collection1Node1,
        ),

        Triple(
          collection1Node1,
          IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#first'),
          LiteralTerm.string('collection1-item2'),
        ),
        Triple(
          collection1Node1,
          IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#rest'),
          IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#nil'),
        ),

        // Second triple with second collection
        Triple(
          IriTerm('http://example.org/subject2'),
          IriTerm('http://example.org/predicate2'),
          collection2Head,
        ),

        // Second collection structure
        Triple(
          collection2Head,
          IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#first'),
          LiteralTerm.string('collection2-item1'),
        ),
        Triple(
          collection2Head,
          IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#rest'),
          collection2Node1,
        ),

        Triple(
          collection2Node1,
          IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#first'),
          LiteralTerm.string('collection2-item2'),
        ),
        Triple(
          collection2Node1,
          IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#rest'),
          IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#nil'),
        ),
      ]);

      // Act
      final result = encoder.convert(graph);

      // Assert
      expect(
        result,
        contains(
          'ex:subject1 ex:predicate1 ("collection1-item1" "collection1-item2") .',
        ),
        reason: 'First collection should be serialized correctly',
      );

      expect(
        result,
        contains(
          'ex:subject2 ex:predicate2 ("collection2-item1" "collection2-item2") .',
        ),
        reason: 'Second collection should be serialized correctly',
      );
    });

    test(
      'should correctly handle RDF collection with a blank node as list item which is referenced in another triple',
      () {
        final collectionHead = BlankNodeTerm();
        final collectionNode1 = BlankNodeTerm();

        // A blank node that will be a list item but also has its own properties
        final blankNodeItem = BlankNodeTerm();

        final graph = RdfGraph.fromTriples([
          // Main triple using the collection
          Triple(
            IriTerm('http://example.org/subject'),
            IriTerm('http://example.org/predicate'),
            collectionHead,
          ),

          // Collection structure
          Triple(
            collectionHead,
            IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#first'),
            LiteralTerm.string('item1'),
          ),
          Triple(
            collectionHead,
            IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#rest'),
            collectionNode1,
          ),

          Triple(
            collectionNode1,
            IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#first'),
            blankNodeItem,
          ),
          Triple(
            collectionNode1,
            IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#rest'),
            IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#nil'),
          ),

          // The blank node item has its own properties
          Triple(
            blankNodeItem,
            IriTerm('http://example.org/type'),
            LiteralTerm.string('BlankNodeInCollection'),
          ),
          Triple(
            IriTerm('http://example.org/somethingElse'),
            IriTerm('http://example.org/relatedTo'),
            blankNodeItem,
          ),
        ]);

        // Act
        final result = encoder.convert(graph);

        // Assert - collection should use the blank node label
        final blankNodeLabelPattern = RegExp(r'\("item1" _:b\d+\)');
        expect(
          blankNodeLabelPattern.hasMatch(result),
          isTrue,
          reason:
              'Collection with blank node item should be serialized correctly',
        );

        // The blank node's properties should also be serialized
        final blankNodePropertiesPattern = RegExp(
          r'_:b\d+ ex:type "BlankNodeInCollection" \.',
        );
        expect(
          blankNodePropertiesPattern.hasMatch(result),
          isTrue,
          reason: 'Blank node item properties should be serialized correctly',
        );
      },
    );

    test(
      'should correctly serialize RDF collections with the same items in different orders',
      () {
        // Create two collections with the same items but in different orders
        final collection1Head = BlankNodeTerm();
        final collection1Node1 = BlankNodeTerm();

        final collection2Head = BlankNodeTerm();
        final collection2Node1 = BlankNodeTerm();

        final graph = RdfGraph.fromTriples([
          // First triple with first collection: (A, B)
          Triple(
            IriTerm('http://example.org/subject1'),
            IriTerm('http://example.org/predicate'),
            collection1Head,
          ),

          // First collection structure: A, B
          Triple(
            collection1Head,
            IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#first'),
            LiteralTerm.string('A'),
          ),
          Triple(
            collection1Head,
            IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#rest'),
            collection1Node1,
          ),

          Triple(
            collection1Node1,
            IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#first'),
            LiteralTerm.string('B'),
          ),
          Triple(
            collection1Node1,
            IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#rest'),
            IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#nil'),
          ),

          // Second triple with second collection: (B, A)
          Triple(
            IriTerm('http://example.org/subject2'),
            IriTerm('http://example.org/predicate'),
            collection2Head,
          ),

          // Second collection structure: B, A
          Triple(
            collection2Head,
            IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#first'),
            LiteralTerm.string('B'),
          ),
          Triple(
            collection2Head,
            IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#rest'),
            collection2Node1,
          ),

          Triple(
            collection2Node1,
            IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#first'),
            LiteralTerm.string('A'),
          ),
          Triple(
            collection2Node1,
            IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#rest'),
            IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#nil'),
          ),
        ]);

        // Act
        final result = encoder.convert(graph);

        // Assert
        expect(
          result,
          contains('ex:subject1 ex:predicate ("A" "B") .'),
          reason: 'First collection should be serialized correctly',
        );

        expect(
          result,
          contains('ex:subject2 ex:predicate ("B" "A") .'),
          reason: 'Second collection should be serialized correctly',
        );
      },
    );

    test('should produce exactly the expected turtle output', () {
      // Create a graph with various RDF features to test exact serialization
      final graph = RdfGraph.fromTriples([
        // Subject with multiple predicates
        Triple(
          IriTerm('http://example.org/subject1'),
          IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#type'),
          IriTerm('http://example.org/Type'),
        ),
        Triple(
          IriTerm('http://example.org/subject1'),
          IriTerm('http://example.org/name'),
          LiteralTerm.string('Example Subject'),
        ),
        Triple(
          IriTerm('http://example.org/subject1'),
          IriTerm('http://example.org/value'),
          LiteralTerm.integer(42),
        ),

        // Second subject with a different set of predicates
        Triple(
          IriTerm('http://example.org/subject2'),
          IriTerm('http://example.org/related'),
          IriTerm('http://example.org/subject1'),
        ),
        Triple(
          IriTerm('http://example.org/subject2'),
          IriTerm('http://example.org/created'),
          LiteralTerm(
            '2025-05-07',
            datatype: IriTerm('http://www.w3.org/2001/XMLSchema#date'),
          ),
        ),
      ]);

      // Define the custom prefixes for this serialization
      final customPrefixes = {'ex': 'http://example.org/'};

      // Act - serialize the graph with the custom prefixes
      final result = encoder
          .withOptions(TurtleEncoderOptions(customPrefixes: customPrefixes))
          .convert(graph);

      // Define the expected Turtle output
      final expected = '''@prefix ex: <http://example.org/> .
@prefix xsd: <http://www.w3.org/2001/XMLSchema#> .

ex:subject1 a ex:Type;
    ex:name "Example Subject";
    ex:value 42 .

ex:subject2 ex:created "2025-05-07"^^xsd:date;
    ex:related ex:subject1 .''';

      // Assert - compare the entire output exactly
      expect(
        result,
        equals(expected),
        reason:
            'Serialized output should exactly match the expected Turtle format',
      );
    });

    test(
      'should correctly handle complex graph with both collections and sets',
      () {
        // Create a more complex graph with both collections and sets
        final collectionHead = BlankNodeTerm();
        final collectionNode1 = BlankNodeTerm();

        final graph = RdfGraph.fromTriples([
          // Subject with a collection
          Triple(
            IriTerm('http://example.org/subject'),
            IriTerm('http://example.org/hasCollection'),
            collectionHead,
          ),

          // Collection structure
          Triple(
            collectionHead,
            IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#first'),
            LiteralTerm.string('item1'),
          ),
          Triple(
            collectionHead,
            IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#rest'),
            collectionNode1,
          ),

          Triple(
            collectionNode1,
            IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#first'),
            LiteralTerm.string('item2'),
          ),
          Triple(
            collectionNode1,
            IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#rest'),
            IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#nil'),
          ),

          // Same subject with a set (multiple objects with same predicate)
          Triple(
            IriTerm('http://example.org/subject'),
            IriTerm('http://example.org/hasItem'),
            LiteralTerm.string('setItem1'),
          ),
          Triple(
            IriTerm('http://example.org/subject'),
            IriTerm('http://example.org/hasItem'),
            LiteralTerm.string('setItem2'),
          ),
          Triple(
            IriTerm('http://example.org/subject'),
            IriTerm('http://example.org/hasItem'),
            LiteralTerm.string('setItem3'),
          ),

          // Another predicate with a single value
          Triple(
            IriTerm('http://example.org/subject'),
            IriTerm('http://example.org/name'),
            LiteralTerm.string('TestSubject'),
          ),
        ]);

        // Act
        final result = encoder.convert(graph);

        // Assert
        // Check the collection is formatted correctly
        expect(
          result,
          contains('ex:hasCollection ("item1" "item2")'),
          reason: 'Collection should be serialized correctly',
        );

        // Check the set is formatted correctly
        expect(
          result,
          contains('ex:hasItem "setItem1", "setItem2", "setItem3"'),
          reason: 'Set should be serialized correctly',
        );

        // Check the single value predicate is formatted correctly
        expect(
          result,
          contains('ex:name "TestSubject"'),
          reason: 'Single value property should be serialized correctly',
        );

        // All predicates should be grouped under the same subject
        final subjectLineCount = RegExp('ex:subject').allMatches(result).length;
        expect(
          subjectLineCount,
          equals(1),
          reason:
              'All predicates should be grouped under a single subject occurrence',
        );
      },
    );

    test(
      'should inline blank nodes that are referenced only once as objects',
      () {
        // Create a graph with a blank node that should be inlined
        final blankNode = BlankNodeTerm();

        final graph = RdfGraph.fromTriples([
          Triple(
            IriTerm('http://example.org/person'),
            IriTerm('http://xmlns.com/foaf/0.1/knows'),
            blankNode,
          ),
          Triple(
            blankNode,
            IriTerm('http://xmlns.com/foaf/0.1/name'),
            LiteralTerm.string('John Smith'),
          ),
          Triple(
            blankNode,
            IriTerm('http://xmlns.com/foaf/0.1/age'),
            LiteralTerm.integer(42),
          ),
        ]);

        // Define custom prefixes for more readable output
        final customPrefixes = {
          'foaf': 'http://xmlns.com/foaf/0.1/',
          'ex': 'http://example.org/',
        };

        // Act
        final result = encoder
            .withOptions(TurtleEncoderOptions(customPrefixes: customPrefixes))
            .convert(graph);

        // Assert
        expect(
          result,
          contains(
            'ex:person foaf:knows [ foaf:name "John Smith" ; foaf:age 42 ] .',
          ),
        );
        expect(
          result,
          isNot(contains('_:b')),
          reason: 'No blank node labels should appear in the output',
        );
      },
    );

    test('should properly format nested inline blank nodes', () {
      // Create a graph with nested blank nodes
      final outerBlankNode = BlankNodeTerm();
      final innerBlankNode = BlankNodeTerm();

      final graph = RdfGraph.fromTriples([
        Triple(
          IriTerm('http://example.org/person'),
          IriTerm('http://xmlns.com/foaf/0.1/knows'),
          outerBlankNode,
        ),
        Triple(
          outerBlankNode,
          IriTerm('http://xmlns.com/foaf/0.1/name'),
          LiteralTerm.string('Alice'),
        ),
        Triple(
          outerBlankNode,
          IriTerm('http://xmlns.com/foaf/0.1/knows'),
          innerBlankNode,
        ),
        Triple(
          innerBlankNode,
          IriTerm('http://xmlns.com/foaf/0.1/name'),
          LiteralTerm.string('Bob'),
        ),
      ]);

      // Define custom prefixes
      final customPrefixes = {
        'foaf': 'http://xmlns.com/foaf/0.1/',
        'ex': 'http://example.org/',
      };

      // Act
      final result = encoder
          .withOptions(TurtleEncoderOptions(customPrefixes: customPrefixes))
          .convert(graph);

      // Assert - should have nested inline blank nodes
      expect(
        result,
        contains(
          'ex:person foaf:knows [ foaf:name "Alice" ; foaf:knows [ foaf:name "Bob" ] ] .',
        ),
        reason: 'Should properly nest inline blank nodes',
      );
      expect(
        result,
        isNot(contains('_:b')),
        reason: 'No blank node labels should appear in the output',
      );
    });

    test(
      'should not inline blank nodes that are referenced multiple times',
      () {
        // Create a graph with a blank node referenced multiple times
        final blankNode = BlankNodeTerm();

        final graph = RdfGraph.fromTriples([
          Triple(
            IriTerm('http://example.org/person1'),
            IriTerm('http://xmlns.com/foaf/0.1/knows'),
            blankNode,
          ),
          Triple(
            IriTerm('http://example.org/person2'),
            IriTerm('http://xmlns.com/foaf/0.1/knows'),
            blankNode,
          ),
          Triple(
            blankNode,
            IriTerm('http://xmlns.com/foaf/0.1/name'),
            LiteralTerm.string('John Smith'),
          ),
        ]);

        // Define custom prefixes
        final customPrefixes = {
          'foaf': 'http://xmlns.com/foaf/0.1/',
          'ex': 'http://example.org/',
        };

        // Act
        final result = encoder
            .withOptions(TurtleEncoderOptions(customPrefixes: customPrefixes))
            .convert(graph);

        // Assert - should use labeled blank nodes, not inline syntax
        expect(
          result,
          contains('_:b0'),
          reason: 'Should use labeled blank nodes for multiple references',
        );
        expect(
          result,
          isNot(contains('[')),
          reason: 'Should not use inline blank node syntax',
        );
      },
    );

    test('should combine inlined blank nodes with collections', () {
      // Create a collection
      final collectionHead = BlankNodeTerm();
      final collectionNode1 = BlankNodeTerm();

      // Create a blank node that should be inlined
      final inlineNode = BlankNodeTerm();

      final graph = RdfGraph.fromTriples([
        // Main triple with a collection
        Triple(
          IriTerm('http://example.org/subject'),
          IriTerm('http://example.org/hasCollection'),
          collectionHead,
        ),

        // Collection structure
        Triple(
          collectionHead,
          IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#first'),
          LiteralTerm.string('item1'),
        ),
        Triple(
          collectionHead,
          IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#rest'),
          collectionNode1,
        ),
        Triple(
          collectionNode1,
          IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#first'),
          inlineNode,
        ),
        Triple(
          collectionNode1,
          IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#rest'),
          IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#nil'),
        ),

        // Blank node with properties
        Triple(
          inlineNode,
          IriTerm('http://xmlns.com/foaf/0.1/name'),
          LiteralTerm.string('John Smith'),
        ),
      ]);

      // Define custom prefixes
      final customPrefixes = {
        'ex': 'http://example.org/',
        'foaf': 'http://xmlns.com/foaf/0.1/',
      };

      // Act
      final result = encoder
          .withOptions(TurtleEncoderOptions(customPrefixes: customPrefixes))
          .convert(graph);

      // Assert - should have a collection with an inline blank node
      expect(
        result,
        contains(
          'ex:subject ex:hasCollection ("item1" [ foaf:name "John Smith" ])',
        ),
        reason: 'Should inline a blank node within a collection',
      );
    });

    test('should not generate invalid namespace prefixes', () {
      // Arrange
      final graph = RdfGraph(
        triples: [
          Triple(
            IriTerm('http://example.org/organization'),
            IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#type'),
            IriTerm('https://schema.org/Organization'),
          ),
          Triple(
            IriTerm('http://example.org/organization'),
            IriTerm('https://schema.org/name'),
            LiteralTerm.string('Test Organization'),
          ),
          Triple(
            IriTerm('http://example.org/organization'),
            IriTerm('https://schema.org/address'),
            BlankNodeTerm(),
          ),
        ],
      );

      // Act
      final result = encoder.convert(graph);

      // Assert
      // Should contain schema.org prefix properly
      expect(result, contains('@prefix schema: <https://schema.org/> .'));

      // Should NOT contain invalid prefixes
      expect(result, isNot(contains('@prefix ns1: <https://> .')));

      // The serialized output should use the proper prefix
      expect(result, contains('a schema:Organization'));
      expect(result, contains('schema:name "Test Organization"'));
      expect(result, contains('schema:address _:'));
    });

    test('should handle complex namespace IRIs correctly', () {
      // Arrange
      final graph = RdfGraph(
        triples: [
          // Standard HTTP IRI
          Triple(
            IriTerm('http://example.org/resource'),
            IriTerm('http://example.org/property'),
            LiteralTerm.string('value1'),
          ),
          // HTTPS IRI with subdomain
          Triple(
            IriTerm('https://api.example.com/resource'),
            IriTerm('https://api.example.com/property'),
            LiteralTerm.string('value2'),
          ),
          // IRI with no path (would have created invalid ns:https:// before the fix)
          Triple(
            IriTerm('https://example.net'),
            IriTerm('https://example.org/refers-to'),
            LiteralTerm.string('value3'),
          ),
          // IRI with just a protocol (would have created invalid ns:http:// before the fix)
          Triple(
            IriTerm('http://'),
            IriTerm('http://example.org/isProtocol'),
            LiteralTerm.boolean(true),
          ),
        ],
      );

      // Act
      final result = encoder.convert(graph);

      // Assert
      // Verify each namespace has a proper prefix (exact prefix name may vary)
      expect(result, contains('@prefix '));

      // Verify the prefixes for the namespaces (but don't assert the specific prefix names)
      expect(result, contains('@prefix ex: <http://example.org/>'));
      expect(result, contains('@prefix api: <https://api.example.com/>'));
      // This IRI doesn't have a trailing slash or hash, so should be serialized as a full IRI, not with a prefix
      expect(result, isNot(contains('@prefix ex1: <https://example.net>')));

      // Check for handling of protocol-only URI correctly
      // The literal URI 'http://' should not be assigned a prefix but used directly as a full IRI
      expect(result, isNot(contains('@prefix ns1: <http://> .')));
      expect(
        result,
        contains('<http://> ex:isProtocol true .'),
      ); // Should be used as a full IRI

      // Check that triples are correctly serialized (content independent of prefix names)
      expect(result, contains('ex:resource ex:property "value1"'));
      expect(result, contains('ex1:refers-to "value3"'));
      expect(result, contains('ex:isProtocol true'));
      expect(result, contains('api:resource api:property "value2"'));
    });

    group('Numeric local names handling', () {
      test(
        'should not use prefixed notation for IRIs with numeric local names by default',
        () {
          // Arrange
          final graph = RdfGraph(
            triples: [
              Triple(
                IriTerm("http://example.org/subject"),
                IriTerm("http://example.org/predicate"),
                IriTerm("http://example.org/123numeric"),
              ),
            ],
          );
          final prefixes = {'ex': 'http://example.org/'};

          // Act
          final result = encoder
              .withOptions(TurtleEncoderOptions(customPrefixes: prefixes))
              .convert(graph);

          // Assert
          expect(result, contains('@prefix ex: <http://example.org/> .'));
          expect(
            result,
            contains('ex:subject ex:predicate <http://example.org/123numeric>'),
          );
          // Nicht als ex:123numeric geschrieben
        },
      );

      test(
        'should use prefixed notation for IRIs with numeric local names when option is enabled',
        () {
          // Arrange
          final graph = RdfGraph(
            triples: [
              Triple(
                IriTerm("http://example.org/subject"),
                IriTerm("http://example.org/predicate"),
                IriTerm("http://example.org/123numeric"),
              ),
            ],
          );
          final prefixes = {'ex': 'http://example.org/'};

          // Act
          final result = encoder
              .withOptions(
                TurtleEncoderOptions(
                  customPrefixes: prefixes,
                  useNumericLocalNames: true,
                ),
              )
              .convert(graph);

          // Assert
          expect(result, contains('@prefix ex: <http://example.org/> .'));
          expect(result, contains('ex:subject ex:predicate ex:123numeric'));
          // Geschrieben als ex:123numeric
        },
      );

      test(
        'should not include prefix for namespace with all numeric local names when option is disabled',
        () {
          // Arrange
          final graph = RdfGraph(
            triples: [
              Triple(
                IriTerm("http://example.org/subject"),
                IriTerm("http://example.org/predicate"),
                IriTerm("http://onlynumbers.org/123"),
              ),
              Triple(
                IriTerm("http://example.org/subject"),
                IriTerm("http://example.org/predicate2"),
                IriTerm("http://onlynumbers.org/456"),
              ),
            ],
          );
          final prefixes = {
            'ex': 'http://example.org/',
            'num': 'http://onlynumbers.org/',
          };

          // Act
          final result = encoder
              .withOptions(
                TurtleEncoderOptions(
                  customPrefixes: prefixes,
                  generateMissingPrefixes: false,
                ),
              )
              .convert(graph);

          // Assert
          expect(result, contains('@prefix ex: <http://example.org/> .'));
          // Prefix 'num:' sollte nicht erscheinen, da er nur für numerische lokale Namen verwendet würde
          expect(
            result,
            isNot(contains('@prefix num: <http://onlynumbers.org/> .')),
          );
          expect(result, contains('<http://onlynumbers.org/123>'));
          expect(result, contains('<http://onlynumbers.org/456>'));
        },
      );

      test(
        'should include prefix for namespace with mixed numeric and non-numeric local names',
        () {
          // Arrange
          final graph = RdfGraph(
            triples: [
              Triple(
                IriTerm("http://example.org/subject"),
                IriTerm("http://example.org/predicate"),
                IriTerm("http://mixed.org/123"),
              ),
              Triple(
                IriTerm("http://example.org/subject"),
                IriTerm("http://example.org/predicate2"),
                IriTerm("http://mixed.org/text"),
              ),
            ],
          );
          final prefixes = {
            'ex': 'http://example.org/',
            'mix': 'http://mixed.org/',
          };

          // Act
          final result = encoder
              .withOptions(
                TurtleEncoderOptions(
                  customPrefixes: prefixes,
                  generateMissingPrefixes: false,
                ),
              )
              .convert(graph);

          // Assert
          expect(result, contains('@prefix ex: <http://example.org/> .'));
          // Prefix 'mix:' sollte erscheinen, da er auch für nicht-numerische lokale Namen verwendet wird
          expect(result, contains('@prefix mix: <http://mixed.org/> .'));
          expect(result, contains('<http://mixed.org/123>'));
          expect(result, contains('mix:text'));
        },
      );
    });

    test('should generate valid prefixes for URLs with hyphens', () {
      // Arrange - Create a graph with IRIs containing hyphens
      final graph = RdfGraph(
        triples: [
          Triple(
            IriTerm('http://kalass.de/dart/rdf/test-ontology#subject'),
            IriTerm('http://kalass.de/dart/rdf/test-ontology#predicate'),
            IriTerm('http://example-domain.org/object'),
          ),
          Triple(
            IriTerm('http://other-domain.com/resource'),
            IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#type'),
            IriTerm('http://example-domain.org/Class'),
          ),
        ],
      );

      // Act
      final result = encoder.convert(graph);

      // Assert
      expect(
        result,
        contains('@prefix to: <http://kalass.de/dart/rdf/test-ontology#> .'),
        reason: 'Should generate valid prefix using initials for test-ontology',
      );

      // Prefix for example-domain should not contain hyphens
      expect(
        result,
        isNot(contains('@prefix example-domain:')),
        reason: 'Should not generate prefixes containing hyphens',
      );

      // The generated prefixes should be used in the triples
      expect(
        result,
        contains('to:subject to:predicate'),
        reason: 'Should use generated initials-based prefixes in the triples',
      );
    });

    test(
      'should generate valid prefixes for complex URL patterns with hyphens',
      () {
        // Test various complex URL patterns with hyphens
        final urls = [
          // URLs with complex path and hyphens
          'http://example.org/path-with/multiple-hyphens/in-segments#term',
          // URLs with hyphenated domain names
          'http://multi-part-domain-name.example.org/resource',
          // URLs with both domain and path hyphens
          'http://hyphenated-domain.org/hyphenated-path/resource',
          // URL with special characters and hyphens
          'http://domain.org/path/with_special-chars.and-hyphens',
        ];

        // Create a graph with a triple for each URL
        final triples =
            urls
                .map(
                  (url) => Triple(
                    IriTerm(url),
                    IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#type'),
                    IriTerm('http://example.org/Resource'),
                  ),
                )
                .toList();

        final graph = RdfGraph(triples: triples);

        // Act
        final result = encoder.convert(graph);

        // Assert - make sure no generated prefixes contain hyphens
        for (final line in result.split('\n')) {
          if (line.trim().startsWith('@prefix ')) {
            final prefixPart = line
                .split(':')[0]
                .trim()
                .replaceAll('@prefix ', '');
            expect(
              prefixPart.contains('-'),
              isFalse,
              reason: 'Prefix "$prefixPart" should not contain hyphens',
            );
          }
        }
      },
    );
  });
}
