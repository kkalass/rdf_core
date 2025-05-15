import 'package:rdf_core/rdf_core.dart';
import 'package:test/test.dart';

void main() {
  group('Turtle Base URI and Prefixes', () {
    test('should use prefixes for predicates even with base URI', () {
      // Arrange
      final turtleData = '''
<http://example.org/person/1> a <http://example.org/ns#Person> .
''';
      
      // Decode the input Turtle
      final graph = turtle.decode(turtleData);
      
      // Set up custom prefixes for the serialization
      final customPrefixes = {
        'ns': 'http://example.org/ns#',
      };

      // Act - encode with baseUri
      final encoded = turtle.encoder
          .withOptions(TurtleEncoderOptions(customPrefixes: customPrefixes))
          .convert(graph, baseUri: 'http://example.org/');

      // Assert
      expect(encoded, contains('@base <http://example.org/>'));
      expect(encoded, contains('@prefix ns: <http://example.org/ns#>'));
      
      // The predicate should use the prefix notation
      expect(encoded, contains('ns:Person'));
      
      // The subject should be relative to the base
      expect(encoded, contains('<person/1>'));
      
      // Should not contain full IRIs for predicates that have a prefix
      expect(encoded, isNot(contains('<http://example.org/ns#Person>')));
    });
  });
}
