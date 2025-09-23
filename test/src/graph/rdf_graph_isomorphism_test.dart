import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:rdf_core/src/graph/rdf_graph_isomorphism.dart';
import 'package:test/test.dart';
import 'package:rdf_core/rdf_core.dart';

void main() {
  group('RDF Graph Isomorphism Extension', () {
    // Helper function to load graph from TTL file
    RdfGraph loadGraphFromFile(String filePath) {
      final content = File(filePath).readAsStringSync();
      return turtle.decode(content);
    }

    // Helper function to create graph from TTL string
    RdfGraph createGraphFromTurtle(String turtleContent) {
      return turtle.decode(turtleContent);
    }

    group('Basic Isomorphism Tests', () {
      test('identical graphs are isomorphic', () {
        const turtle = '''
@prefix ex: <http://example.org/> .
ex:alice ex:name "Alice"@en .
ex:alice ex:age "25"^^<http://www.w3.org/2001/XMLSchema#int> .
''';
        final graph1 = createGraphFromTurtle(turtle);
        final graph2 = createGraphFromTurtle(turtle);

        expect(graph1.isIsomorphicTo(other: graph2), isTrue);
      });

      test('graphs with different blank node labels are isomorphic', () {
        const turtle1 = '''
@prefix ex: <http://example.org/> .
_:a ex:name "Alice"@en .
_:a ex:friend _:b .
_:b ex:name "Bob"@en .
''';
        const turtle2 = '''
@prefix ex: <http://example.org/> .
_:x ex:name "Alice"@en .
_:x ex:friend _:y .
_:y ex:name "Bob"@en .
''';
        final graph1 = createGraphFromTurtle(turtle1);
        final graph2 = createGraphFromTurtle(turtle2);

        expect(graph1.isIsomorphicTo(other: graph2), isTrue);
      });

      test('graphs with different structure are not isomorphic', () {
        const turtle1 = '''
@prefix ex: <http://example.org/> .
_:a ex:name "Alice"@en .
_:a ex:friend _:b .
''';
        const turtle2 = '''
@prefix ex: <http://example.org/> .
_:a ex:name "Alice"@en .
_:a ex:enemy _:b .
''';
        final graph1 = createGraphFromTurtle(turtle1);
        final graph2 = createGraphFromTurtle(turtle2);

        expect(graph1.isIsomorphicTo(other: graph2), isFalse);
      });

      test('graphs with different triple counts are not isomorphic', () {
        const turtle1 = '''
@prefix ex: <http://example.org/> .
_:a ex:name "Alice"@en .
''';
        const turtle2 = '''
@prefix ex: <http://example.org/> .
_:a ex:name "Alice"@en .
_:a ex:age "25"^^<http://www.w3.org/2001/XMLSchema#int> .
''';
        final graph1 = createGraphFromTurtle(turtle1);
        final graph2 = createGraphFromTurtle(turtle2);

        expect(graph1.isIsomorphicTo(other: graph2), isFalse);
      });
    });

    group('Edge Cases', () {
      test('empty graphs are isomorphic', () {
        final graph1 = RdfGraph();
        final graph2 = RdfGraph();

        expect(graph1.isIsomorphicTo(other: graph2), isTrue);
      });

      test('empty graph vs non-empty graph are not isomorphic', () {
        final graph1 = RdfGraph();
        const turtle = '''
@prefix ex: <http://example.org/> .
ex:alice ex:name "Alice"@en .
''';
        final graph2 = createGraphFromTurtle(turtle);

        expect(graph1.isIsomorphicTo(other: graph2), isFalse);
        expect(graph2.isIsomorphicTo(other: graph1), isFalse);
      });

      test('single triple graphs with same content are isomorphic', () {
        const turtle = '''
@prefix ex: <http://example.org/> .
ex:alice ex:name "Alice"@en .
''';
        final graph1 = createGraphFromTurtle(turtle);
        final graph2 = createGraphFromTurtle(turtle);

        expect(graph1.isIsomorphicTo(other: graph2), isTrue);
      });

      test('single triple graphs with blank nodes are isomorphic', () {
        const turtle1 = '''
@prefix ex: <http://example.org/> .
_:a ex:name "Alice"@en .
''';
        const turtle2 = '''
@prefix ex: <http://example.org/> .
_:x ex:name "Alice"@en .
''';
        final graph1 = createGraphFromTurtle(turtle1);
        final graph2 = createGraphFromTurtle(turtle2);

        expect(graph1.isIsomorphicTo(other: graph2), isTrue);
      });

      test('graphs with only blank nodes - simple case', () {
        const turtle1 = '''
@prefix ex: <http://example.org/> .
_:a ex:connects _:b .
_:b ex:connects _:c .
''';
        const turtle2 = '''
@prefix ex: <http://example.org/> .
_:x ex:connects _:y .
_:y ex:connects _:z .
''';
        final graph1 = createGraphFromTurtle(turtle1);
        final graph2 = createGraphFromTurtle(turtle2);

        expect(graph1.isIsomorphicTo(other: graph2), isTrue);
      });

      test('graphs with only blank nodes - different structure', () {
        const turtle1 = '''
@prefix ex: <http://example.org/> .
_:a ex:connects _:b .
_:b ex:connects _:c .
''';
        const turtle2 = '''
@prefix ex: <http://example.org/> .
_:x ex:connects _:y .
_:x ex:connects _:z .
''';
        final graph1 = createGraphFromTurtle(turtle1);
        final graph2 = createGraphFromTurtle(turtle2);

        expect(graph1.isIsomorphicTo(other: graph2), isFalse);
      });

      test('self-referencing blank nodes', () {
        const turtle1 = '''
@prefix ex: <http://example.org/> .
_:a ex:self _:a .
''';
        const turtle2 = '''
@prefix ex: <http://example.org/> .
_:x ex:self _:x .
''';
        final graph1 = createGraphFromTurtle(turtle1);
        final graph2 = createGraphFromTurtle(turtle2);

        expect(graph1.isIsomorphicTo(other: graph2), isTrue);
      });

      test('circular blank node references', () {
        const turtle1 = '''
@prefix ex: <http://example.org/> .
_:a ex:next _:b .
_:b ex:next _:c .
_:c ex:next _:a .
''';
        const turtle2 = '''
@prefix ex: <http://example.org/> .
_:x ex:next _:y .
_:y ex:next _:z .
_:z ex:next _:x .
''';
        final graph1 = createGraphFromTurtle(turtle1);
        final graph2 = createGraphFromTurtle(turtle2);

        expect(graph1.isIsomorphicTo(other: graph2), isTrue);
      });

      test('graphs with different blank node degrees', () {
        const turtle1 = '''
@prefix ex: <http://example.org/> .
_:a ex:connects _:b .
_:a ex:connects _:c .
_:a ex:connects _:d .
''';
        const turtle2 = '''
@prefix ex: <http://example.org/> .
_:x ex:connects _:y .
_:z ex:connects _:y .
_:w ex:connects _:y .
''';
        final graph1 = createGraphFromTurtle(turtle1);
        final graph2 = createGraphFromTurtle(turtle2);

        expect(graph1.isIsomorphicTo(other: graph2), isFalse);
      });
    });

    group('Complex Structural Tests', () {
      test('graphs with mixed named and blank nodes', () {
        const turtle1 = '''
@prefix ex: <http://example.org/> .
ex:alice ex:address _:addr1 .
_:addr1 ex:street "Main St"@en .
_:addr1 ex:city ex:NewYork .
ex:bob ex:address _:addr2 .
_:addr2 ex:street "Oak Ave"@en .
_:addr2 ex:city ex:Boston .
''';
        const turtle2 = '''
@prefix ex: <http://example.org/> .
ex:alice ex:address _:address1 .
_:address1 ex:street "Main St"@en .
_:address1 ex:city ex:NewYork .
ex:bob ex:address _:address2 .
_:address2 ex:street "Oak Ave"@en .
_:address2 ex:city ex:Boston .
''';
        final graph1 = createGraphFromTurtle(turtle1);
        final graph2 = createGraphFromTurtle(turtle2);

        expect(graph1.isIsomorphicTo(other: graph2), isTrue);
      });

      test('graphs with different literal values', () {
        const turtle1 = '''
@prefix ex: <http://example.org/> .
_:a ex:name "Alice"@en .
_:a ex:age "25"^^<http://www.w3.org/2001/XMLSchema#int> .
''';
        const turtle2 = '''
@prefix ex: <http://example.org/> .
_:x ex:name "Bob"@en .
_:x ex:age "25"^^<http://www.w3.org/2001/XMLSchema#int> .
''';
        final graph1 = createGraphFromTurtle(turtle1);
        final graph2 = createGraphFromTurtle(turtle2);

        expect(graph1.isIsomorphicTo(other: graph2), isFalse);
      });

      test('graphs with different datatypes', () {
        const turtle1 = '''
@prefix ex: <http://example.org/> .
_:a ex:value "25"^^<http://www.w3.org/2001/XMLSchema#int> .
''';
        const turtle2 = '''
@prefix ex: <http://example.org/> .
_:x ex:value "25"^^<http://www.w3.org/2001/XMLSchema#string> .
''';
        final graph1 = createGraphFromTurtle(turtle1);
        final graph2 = createGraphFromTurtle(turtle2);

        expect(graph1.isIsomorphicTo(other: graph2), isFalse);
      });

      test('graphs with language tags', () {
        const turtle1 = '''
@prefix ex: <http://example.org/> .
_:a ex:name "Alice"@en .
_:a ex:name "Alicia"@es .
''';
        const turtle2 = '''
@prefix ex: <http://example.org/> .
_:x ex:name "Alice"@en .
_:x ex:name "Alicia"@es .
''';
        final graph1 = createGraphFromTurtle(turtle1);
        final graph2 = createGraphFromTurtle(turtle2);

        expect(graph1.isIsomorphicTo(other: graph2), isTrue);
      });

      test('graphs with different language tags', () {
        const turtle1 = '''
@prefix ex: <http://example.org/> .
_:a ex:name "Alice"@en .
''';
        const turtle2 = '''
@prefix ex: <http://example.org/> .
_:x ex:name "Alice"@fr .
''';
        final graph1 = createGraphFromTurtle(turtle1);
        final graph2 = createGraphFromTurtle(turtle2);

        expect(graph1.isIsomorphicTo(other: graph2), isFalse);
      });
    });

    group('Performance Tests', () {
      test('large graphs performance test', () {
        final stopwatch = Stopwatch()..start();

        final graph1 = loadGraphFromFile('test/assets/isomorphism/large.ttl');
        final graph2 =
            loadGraphFromFile('test/assets/isomorphism/large_iso.ttl');

        final result = graph1.isIsomorphicTo(other: graph2);

        stopwatch.stop();

        expect(result, isTrue);
        expect(
          stopwatch.elapsedMilliseconds,
          lessThan(5000),
          reason: 'Large graph isomorphism should complete within 5 seconds',
        );

        print(
          'Large graph isomorphism took ${stopwatch.elapsedMilliseconds}ms',
        );
      });

      test('very complex graphs performance test', () {
        final stopwatch = Stopwatch()..start();

        final graph1 =
            loadGraphFromFile('test/assets/isomorphism/very_complex.ttl');
        final graph2 =
            loadGraphFromFile('test/assets/isomorphism/very_complex_iso.ttl');

        final result = graph1.isIsomorphicTo(other: graph2);

        stopwatch.stop();

        expect(result, isTrue);
        expect(
          stopwatch.elapsedMilliseconds,
          lessThan(10000),
          reason:
              'Very complex graph comparison should complete within 10 seconds',
        );

        print(
          'Very complex graph comparison took ${stopwatch.elapsedMilliseconds}ms',
        );
      });

      test('non-isomorphic large graphs performance test', () {
        final stopwatch = Stopwatch()..start();

        final graph1 = loadGraphFromFile('test/assets/isomorphism/large.ttl');
        final graph2 =
            loadGraphFromFile('test/assets/isomorphism/large_noniso.ttl');

        final result = graph1.isIsomorphicTo(other: graph2);

        stopwatch.stop();

        expect(result, isFalse);
        expect(
          stopwatch.elapsedMilliseconds,
          lessThan(5000),
          reason:
              'Large non-isomorphic graph check should complete within 5 seconds',
        );

        print(
          'Large non-isomorphic graph check took ${stopwatch.elapsedMilliseconds}ms',
        );
      });

      test('performance with many blank nodes', () {
        // Create a graph with many interconnected blank nodes
        final turtleContent = StringBuffer();
        turtleContent.writeln('@prefix ex: <http://example.org/> .');

        // Create a chain of 50 blank nodes
        for (int i = 0; i < 49; i++) {
          turtleContent.writeln('_:node$i ex:next _:node${i + 1} .');
          turtleContent.writeln(
            '_:node$i ex:value "$i"^^<http://www.w3.org/2001/XMLSchema#int> .',
          );
        }
        turtleContent.writeln(
          '_:node49 ex:value "49"^^<http://www.w3.org/2001/XMLSchema#int> .',
        );

        final stopwatch = Stopwatch()..start();

        final graph1 = createGraphFromTurtle(turtleContent.toString());
        final graph2 = createGraphFromTurtle(turtleContent.toString());

        final result = graph1.isIsomorphicTo(other: graph2);

        stopwatch.stop();

        expect(result, isTrue);
        expect(
          stopwatch.elapsedMilliseconds,
          lessThan(3000),
          reason:
              'Many blank nodes isomorphism should complete within 3 seconds',
        );

        print(
          'Many blank nodes isomorphism took ${stopwatch.elapsedMilliseconds}ms',
        );
      });
    });

    group('Isomorphism File Tests', () {
      // Pull all "regular" ttl files
      final files = Directory('test/assets/isomorphism')
          .listSync()
          .whereType<File>()
          .where((file) {
        final name = p.basenameWithoutExtension(file.path);
        final ext = p.extension(file.path);

        // Only accept if extension is '.ttl' and base name does not end with '_iso' or '_noniso'
        final isRegular = ext == '.ttl' &&
            !name.endsWith('_iso') &&
            !name.endsWith('_noniso');
        return isRegular;
      });

      for (final file in files) {
        final regularGraph = loadGraphFromFile('${file.path}');
        final basename = p.basenameWithoutExtension(file.path);
        final dirname = p.dirname(file.path);

        test(
            'validates `${basename}.ttl` is isomorphic to `${basename}_iso.ttl`',
            () async {
          final graph =
              loadGraphFromFile(p.join(dirname, '${basename}_iso.ttl'));

          expect(graph.isIsomorphicTo(other: regularGraph), isTrue);
        });

        test(
            'validates `${basename}.ttl` is NOT isomorphic to `${basename}_noniso.ttl`',
            () async {
          final graph =
              loadGraphFromFile(p.join(dirname, '${basename}_noniso.ttl'));

          expect(graph.isIsomorphicTo(other: regularGraph), isFalse);
        });
      }
    });

    group('Regression Tests', () {
      test(
        'graphs with identical structure but different blank node counts',
        () {
          const turtle1 = '''
@prefix ex: <http://example.org/> .
_:a ex:prop ex:value .
_:b ex:prop ex:value .
''';
          const turtle2 = '''
@prefix ex: <http://example.org/> .
_:x ex:prop ex:value .
''';
          final graph1 = createGraphFromTurtle(turtle1);
          final graph2 = createGraphFromTurtle(turtle2);

          expect(graph1.isIsomorphicTo(other: graph2), isFalse);
        },
      );

      test('graphs with same triples but different blank node usage', () {
        const turtle1 = '''
@prefix ex: <http://example.org/> .
_:a ex:name "Alice"@en .
_:a ex:friend _:b .
_:b ex:name "Bob"@en .
''';
        const turtle2 = '''
@prefix ex: <http://example.org/> .
_:x ex:name "Alice"@en .
_:x ex:friend _:y .
_:y ex:name "Bob"@en .
''';
        final graph1 = createGraphFromTurtle(turtle1);
        final graph2 = createGraphFromTurtle(turtle2);

        expect(graph1.isIsomorphicTo(other: graph2), isTrue);
      });

      test('complex nested blank node structures', () {
        const turtle1 = '''
@prefix ex: <http://example.org/> .
_:root ex:child _:child1 .
_:root ex:child _:child2 .
_:child1 ex:grandchild _:gc1 .
_:child1 ex:grandchild _:gc2 .
_:child2 ex:grandchild _:gc3 .
_:gc1 ex:value "1"^^<http://www.w3.org/2001/XMLSchema#int> .
_:gc2 ex:value "2"^^<http://www.w3.org/2001/XMLSchema#int> .
_:gc3 ex:value "3"^^<http://www.w3.org/2001/XMLSchema#int> .
''';
        const turtle2 = '''
@prefix ex: <http://example.org/> .
_:r ex:child _:c1 .
_:r ex:child _:c2 .
_:c1 ex:grandchild _:g1 .
_:c1 ex:grandchild _:g2 .
_:c2 ex:grandchild _:g3 .
_:g1 ex:value "1"^^<http://www.w3.org/2001/XMLSchema#int> .
_:g2 ex:value "2"^^<http://www.w3.org/2001/XMLSchema#int> .
_:g3 ex:value "3"^^<http://www.w3.org/2001/XMLSchema#int> .
''';
        final graph1 = createGraphFromTurtle(turtle1);
        final graph2 = createGraphFromTurtle(turtle2);

        expect(graph1.isIsomorphicTo(other: graph2), isTrue);
      });
    });
  });
}
