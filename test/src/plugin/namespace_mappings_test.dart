import 'package:rdf_core/src/vocab/namespaces.dart';
import 'package:test/test.dart';

// Tests for RdfNamespaceMappings class
void main() {
  group('RdfNamespaceMappings Tests', () {
    test('constructor creates standard mappings', () {
      // Act
      final mappings = RdfNamespaceMappings();

      // Assert
      // Standard mappings should have at least 'rdf' and 'xsd'
      expect(mappings['rdf'], isNotNull);
      expect(mappings['xsd'], isNotNull);
      expect(mappings.length, greaterThan(0));
    });

    test('custom constructor creates mappings with custom values', () {
      // Arrange
      final map = {
        'ex': 'http://example.org/',
        'dc': 'http://purl.org/dc/elements/1.1/',
      };

      // Act
      final mappings = RdfNamespaceMappings.custom(map);

      // Assert
      expect(mappings['ex'], equals('http://example.org/'));
      expect(mappings['dc'], equals('http://purl.org/dc/elements/1.1/'));
      // Should also contain standard mappings
      expect(mappings['rdf'], isNotNull);
    });

    test(
      'custom constructor with useDefaults=false only includes custom mappings',
      () {
        // Arrange
        final map = {
          'ex': 'http://example.org/',
          'dc': 'http://purl.org/dc/elements/1.1/',
        };

        // Act
        final mappings = RdfNamespaceMappings.custom(map, useDefaults: false);

        // Assert
        expect(mappings['ex'], equals('http://example.org/'));
        expect(mappings['dc'], equals('http://purl.org/dc/elements/1.1/'));
        // Should not contain standard mappings
        expect(mappings['rdf'], isNull);
        expect(mappings.length, equals(2));
      },
    );

    test('operator [] returns the namespace URI for a prefix', () {
      // Arrange
      final mappings = RdfNamespaceMappings.custom({
        'ex': 'http://example.org/',
      });

      // Act & Assert
      expect(mappings['ex'], equals('http://example.org/'));
    });

    test('operator [] returns null for an unknown prefix', () {
      // Arrange
      final mappings = RdfNamespaceMappings();

      // Act & Assert
      expect(mappings['unknown'], isNull);
    });

    test('getPrefix returns the prefix for a namespace URI', () {
      // Arrange
      final mappings = RdfNamespaceMappings.custom({
        'ex': 'http://example.org/',
      }, useDefaults: false);

      // Act & Assert
      expect(mappings.getPrefix('http://example.org/'), equals('ex'));
    });

    test('getPrefix returns null for an unknown namespace URI', () {
      // Arrange
      final mappings = RdfNamespaceMappings.custom({}, useDefaults: false);

      // Act & Assert
      expect(mappings.getPrefix('http://unknown.org/'), isNull);
    });

    test('length property returns correct number of mappings', () {
      // Arrange
      final mappings = RdfNamespaceMappings.custom({
        'ex': 'http://example.org/',
        'dc': 'http://purl.org/dc/elements/1.1/',
      }, useDefaults: false);

      // Assert
      expect(mappings.length, equals(2));
    });

    test('getOrGeneratePrefix returns existing prefix for known namespace', () {
      // Arrange
      final mappings = RdfNamespaceMappings.custom({
        'ex': 'http://example.org/',
      }, useDefaults: false);

      // Act
      final (prefix, generated) = mappings.getOrGeneratePrefix(
        'http://example.org/',
      );

      // Assert
      expect(prefix, equals('ex'));
      expect(generated, isFalse);
    });

    test('getOrGeneratePrefix generates new prefix for unknown namespace', () {
      // Arrange
      final mappings = RdfNamespaceMappings.custom({}, useDefaults: false);

      // Act
      final (prefix, generated) = mappings.getOrGeneratePrefix(
        'http://example.org/',
      );

      // Assert
      expect(prefix, isNotEmpty);
      expect(generated, isTrue);
    });

    test(
      'getOrGeneratePrefix generates a prefix for URLs that follows a pattern',
      () {
        // Arrange
        final mappings = RdfNamespaceMappings.custom({}, useDefaults: false);

        // Act
        final (prefix, generated) = mappings.getOrGeneratePrefix(
          'http://example.org/path/to/resource',
        );

        // Assert
        expect(prefix, isNotEmpty);
        expect(generated, isTrue);
        // We don't test for a specific prefix since the algorithm might change,
        // we just want to make sure it generates something valid
      },
    );

    test('getOrGeneratePrefix handles custom mappings parameter', () {
      // Arrange
      final mappings = RdfNamespaceMappings.custom({}, useDefaults: false);
      final customMappings = {'custom': 'http://custom.org/'};

      // Act
      final (prefix, generated) = mappings.getOrGeneratePrefix(
        'http://custom.org/',
        customMappings: customMappings,
      );

      // Assert
      expect(prefix, equals('custom'));
      expect(generated, isFalse);
    });

    test('containsKey returns true for existing prefix', () {
      // Arrange
      final mappings = RdfNamespaceMappings.custom({
        'ex': 'http://example.org/',
      }, useDefaults: false);

      // Act & Assert
      expect(mappings.containsKey('ex'), isTrue);
    });

    test('containsKey returns false for non-existing prefix', () {
      // Arrange
      final mappings = RdfNamespaceMappings.custom({}, useDefaults: false);

      // Act & Assert
      expect(mappings.containsKey('ex'), isFalse);
    });

    test('asMap returns unmodifiable map of the mappings', () {
      // Arrange
      final mappings = RdfNamespaceMappings.custom({
        'ex': 'http://example.org/',
      }, useDefaults: false);

      // Act
      final map = mappings.asMap();

      // Assert
      expect(map['ex'], equals('http://example.org/'));
      expect(() => map['test'] = 'test', throwsUnsupportedError);
    });
  });
}
