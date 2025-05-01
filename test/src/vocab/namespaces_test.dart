// Tests for the RDF Namespace mappings
import 'package:rdf_core/src/vocab/namespaces.dart';
import 'package:rdf_core/src/vocab/rdf.dart';
import 'package:rdf_core/src/vocab/xsd.dart';

import 'package:test/test.dart';

void main() {
  group('RdfNamespaceMappings', () {
    final rdfNamespaceMappings = RdfNamespaceMappings();

    test('contains correct mappings for all supported vocabularies', () {
      // Core vocabularies
      expect(
        rdfNamespaceMappings['rdf'],
        equals('http://www.w3.org/1999/02/22-rdf-syntax-ns#'),
      );
      expect(
        rdfNamespaceMappings['rdfs'],
        equals('http://www.w3.org/2000/01/rdf-schema#'),
      );
      expect(
        rdfNamespaceMappings['owl'],
        equals('http://www.w3.org/2002/07/owl#'),
      );
      expect(
        rdfNamespaceMappings['xsd'],
        equals('http://www.w3.org/2001/XMLSchema#'),
      );

      // Common community vocabularies
      expect(rdfNamespaceMappings['schema'], equals('https://schema.org/'));
      expect(
        rdfNamespaceMappings['foaf'],
        equals('http://xmlns.com/foaf/0.1/'),
      );
      expect(
        rdfNamespaceMappings['dc'],
        equals('http://purl.org/dc/elements/1.1/'),
      );
      expect(
        rdfNamespaceMappings['dcterms'],
        equals('http://purl.org/dc/terms/'),
      );
      expect(
        rdfNamespaceMappings['skos'],
        equals('http://www.w3.org/2004/02/skos/core#'),
      );
      expect(
        rdfNamespaceMappings['vcard'],
        equals('http://www.w3.org/2006/vcard/ns#'),
      );

      // Linked Data Platform and Solid related
      expect(rdfNamespaceMappings['ldp'], equals('http://www.w3.org/ns/ldp#'));
      expect(
        rdfNamespaceMappings['solid'],
        equals('http://www.w3.org/ns/solid/terms#'),
      );
      expect(
        rdfNamespaceMappings['acl'],
        equals('http://www.w3.org/ns/auth/acl#'),
      );
    });

    test('prefixes match their respective class prefix constants', () {
      expect(rdfNamespaceMappings[Rdf.prefix], equals(Rdf.namespace));
      expect(rdfNamespaceMappings[Xsd.prefix], equals(Xsd.namespace));
    });

    test('contains all required vocabularies', () {
      final requiredPrefixes = [
        'rdf',
        'rdfs',
        'owl',
        'xsd',
        'schema',
        'foaf',
        'dc',
        'dcterms',
        'skos',
        'vcard',
        'ldp',
        'solid',
        'acl',
      ];

      for (final prefix in requiredPrefixes) {
        expect(
          rdfNamespaceMappings.containsKey(prefix),
          isTrue,
          reason: "Missing namespace mapping for prefix: $prefix",
        );
      }

      expect(
        rdfNamespaceMappings.length,
        equals(requiredPrefixes.length),
        reason: "Different number of mappings than expected",
      );
    });

    group('custom mappings', () {
      test('custom mappings override standard mappings', () {
        final customMappings = {
          'rdf': 'http://custom.org/rdf#',
          'custom': 'http://example.org/custom#',
        };

        final mappings = RdfNamespaceMappings.custom(customMappings);

        // Custom mapping should override standard mapping
        expect(mappings['rdf'], equals('http://custom.org/rdf#'));
        expect(mappings['rdf'], isNot(equals(Rdf.namespace)));

        // Custom mapping should be present
        expect(mappings['custom'], equals('http://example.org/custom#'));
      });

      test('constructor creates immutable instance', () {
        final customMappings = {'custom': 'http://example.org/custom#'};

        final mappings = RdfNamespaceMappings.custom(customMappings);

        // Modifying the original map should not affect the instance
        customMappings['custom'] = 'http://changed.org/';

        expect(mappings['custom'], equals('http://example.org/custom#'));
      });
    });

    group('spread operator support', () {
      test('supports spread operator via asMap() in map literals', () {
        final mappings = RdfNamespaceMappings();

        // Create a new map using spread operator
        final extended = {
          ...mappings.asMap(),
          'custom': 'http://example.org/custom#',
        };

        // Should contain both standard and custom mappings
        expect(extended['rdf'], equals(Rdf.namespace));
        expect(extended['custom'], equals('http://example.org/custom#'));
      });

      test('spread operator with customized mappings', () {
        final customMappings = {'ex': 'http://example.org/'};

        final mappings = RdfNamespaceMappings.custom(customMappings);

        // Create a new map using spread operator
        final extended = {
          ...mappings.asMap(),
          'another': 'http://another.org/',
        };

        // Should contain standard, custom and extended mappings
        expect(extended['rdf'], equals(Rdf.namespace));
        expect(extended['ex'], equals('http://example.org/'));
        expect(extended['another'], equals('http://another.org/'));
      });

      test('spread operator retains all original entries', () {
        final mappings = RdfNamespaceMappings();
        final map = {...mappings.asMap()};

        expect(map.length, equals(mappings.length));

        // Check that map contains expected keys/values
        expect(map['rdf'], equals(Rdf.namespace));
        expect(map['xsd'], equals(Xsd.namespace));
      });
    });

    group('utility methods', () {
      test('asMap returns unmodifiable map view', () {
        final mappings = RdfNamespaceMappings();
        final map = mappings.asMap();

        expect(
          map['rdf'],
          equals('http://www.w3.org/1999/02/22-rdf-syntax-ns#'),
        );

        // Verify it's an unmodifiable map
        expect(() => map['test'] = 'value', throwsUnsupportedError);
      });

      test('containsKey checks for existence of prefix', () {
        final mappings = RdfNamespaceMappings();

        expect(mappings.containsKey('rdf'), isTrue);
        expect(mappings.containsKey('nonexistent'), isFalse);
      });

      test('length returns correct number of mappings', () {
        final mappings = RdfNamespaceMappings();

        expect(
          mappings.length,
          equals(13),
        ); // Match with number of standard namespaces
      });
    });

    test('const constructor produces identical instances', () {
      const mappings1 = RdfNamespaceMappings();
      const mappings2 = RdfNamespaceMappings();

      // Should be identical (same instance) due to const constructor
      expect(identical(mappings1, mappings2), isTrue);
    });
  });
}
