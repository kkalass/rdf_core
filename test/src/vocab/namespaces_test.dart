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

      group('getPrefix', () {
        test('returns correct prefix for standard namespace URI', () {
          final mappings = RdfNamespaceMappings();

          expect(mappings.getPrefix(Rdf.namespace), equals('rdf'));
          expect(
            mappings.getPrefix('http://www.w3.org/2000/01/rdf-schema#'),
            equals('rdfs'),
          );
          expect(
            mappings.getPrefix('http://www.w3.org/ns/ldp#'),
            equals('ldp'),
          );
        });

        test('returns null for unknown namespace URI', () {
          final mappings = RdfNamespaceMappings();

          expect(mappings.getPrefix('http://unknown.example.org/'), isNull);
        });

        test('handles custom mappings correctly', () {
          final mappings = RdfNamespaceMappings();
          final customMappings = {'custom': 'http://example.org/custom#'};

          expect(
            mappings.getPrefix(
              'http://example.org/custom#',
              customMappings: customMappings,
            ),
            equals('custom'),
          );
        });

        test('custom mappings take precedence over standard ones', () {
          final mappings = RdfNamespaceMappings();
          // Override an existing standard mapping
          final customMappings = {'custom-rdf': Rdf.namespace};

          expect(
            mappings.getPrefix(Rdf.namespace, customMappings: customMappings),
            equals('custom-rdf'),
          );
        });
      });

      group('getOrGeneratePrefix', () {
        test('returns existing prefix for known namespace URI', () {
          final mappings = RdfNamespaceMappings();

          final (prefix, generated) = mappings.getOrGeneratePrefix(
            Rdf.namespace,
          );

          expect(prefix, equals('rdf'));
          expect(generated, isFalse);
        });

        test('generates prefix for unknown namespace URI', () {
          final mappings = RdfNamespaceMappings();

          final (prefix, generated) = mappings.getOrGeneratePrefix(
            'http://example.org/',
          );

          expect(prefix, isNotEmpty);
          expect(generated, isTrue);
        });

        test('generates prefix from domain when possible', () {
          final mappings = RdfNamespaceMappings();

          final (prefix, _) = mappings.getOrGeneratePrefix(
            'http://example.org/',
          );
          expect(prefix, equals('ex'));

          final (prefix2, _) = mappings.getOrGeneratePrefix(
            'https://google.com/namespace',
          );
          expect(prefix2, equals('go'));
        });

        test('handles conflict with existing prefix when generating', () {
          final mappings = RdfNamespaceMappings();
          // First call should generate 'ex'
          final (prefix1, _) = mappings.getOrGeneratePrefix(
            'http://example.org/',
          );

          // Create a custom mapping that already uses 'ex'
          final customMappings = {prefix1: 'http://existing-example.org/'};

          // Now try with a different URI but same prefix pattern
          final (prefix2, generated2) = mappings.getOrGeneratePrefix(
            'http://example2.org/',
            customMappings: customMappings,
          );

          expect(prefix1, equals('ex'));
          expect(prefix2, isNot(equals('ex')));
          expect(generated2, isTrue);
          // Should add a number to make unique
          expect(prefix2, equals('ex1'));
        });

        test(
          'falls back to ns prefix pattern when domain extraction fails',
          () {
            final mappings = RdfNamespaceMappings();

            // URI with invalid or no extractable domain part
            final (prefix, generated) = mappings.getOrGeneratePrefix(
              'urn:isbn:1234567890',
            );

            expect(prefix, startsWith('isbn'));
            expect(generated, isTrue);
          },
        );

        test('respects custom mappings for existing prefixes', () {
          final mappings = RdfNamespaceMappings();
          final customMappings = {'custom': 'http://example.org/custom#'};

          final (prefix, generated) = mappings.getOrGeneratePrefix(
            'http://example.org/custom#',
            customMappings: customMappings,
          );

          expect(prefix, equals('custom'));
          expect(generated, isFalse);
        });

        test('handles domain with special characters correctly', () {
          final mappings = RdfNamespaceMappings();

          // Special characters in domain
          final (prefix, _) = mappings.getOrGeneratePrefix(
            'http://special-chars.example.org/',
          );

          expect(prefix, equals('sc'));
        });
      });
    });

    group('advanced prefix generation', () {
      test(
        'purl.org is so non-standard that we have to rely on explicit mappings',
        () {
          final mappings = RdfNamespaceMappings.custom({}, useDefaults: false);

          // Test for dcterms pattern
          final (dcPrefix, dcGenerated) = mappings.getOrGeneratePrefix(
            'http://purl.org/dc/terms/',
          );
          expect(dcPrefix, equals('dc'));
          expect(dcGenerated, isTrue);

          // Test for dc pattern
          final (elementsPrefix, elementsGenerated) = mappings
              .getOrGeneratePrefix('http://purl.org/dc/elements/1.1/');
          expect(elementsPrefix, equals('elements'));
          expect(elementsGenerated, isTrue);

          // Test for goodrelations pattern (gr)
          final (grPrefix, grGenerated) = mappings.getOrGeneratePrefix(
            'http://purl.org/goodrelations/v1#',
          );
          expect(grPrefix, equals('goodrelations'));
          expect(grGenerated, isTrue);

          // Test for generic purl.org case
          final (otherPrefix, otherGenerated) = mappings.getOrGeneratePrefix(
            'http://purl.org/other/resource/',
          );
          expect(otherPrefix, equals('other'));
          expect(otherGenerated, isTrue);
        },
      );

      test('generates correct prefixes for w3.org URIs', () {
        final mappings = RdfNamespaceMappings.custom({}, useDefaults: false);

        // Test for w3.org/ns/ pattern
        final (ldpPrefix, ldpGenerated) = mappings.getOrGeneratePrefix(
          'http://www.w3.org/ns/ldp/new#',
        );
        expect(ldpPrefix, equals('ldp'));
        expect(ldpGenerated, isTrue);

        // Test for w3.org with date patterns (should skip dates)
        final (skosPrefix, skosGenerated) = mappings.getOrGeneratePrefix(
          'http://www.w3.org/2004/02/skos/core#',
        );
        expect(skosPrefix, equals('skos'));
        expect(skosGenerated, isTrue);

        // Test for w3.org with multiple segments
        final (vocabPrefix, vocabGenerated) = mappings.getOrGeneratePrefix(
          'http://www.w3.org/2006/vcard/ns#',
        );
        expect(vocabPrefix, equals('vcard'));
        expect(vocabGenerated, isTrue);
      });

      test('generates correct prefixes for xmlns.com URIs', () {
        final mappings = RdfNamespaceMappings.custom({}, useDefaults: false);

        // Test for xmlns.com pattern (like foaf)
        final (foafPrefix, foafGenerated) = mappings.getOrGeneratePrefix(
          'http://xmlns.com/foaf/0.1/',
        );
        expect(foafPrefix, equals('foaf'));
        expect(foafGenerated, isTrue);

        // Test for another xmlns.com case
        final (newPrefix, newGenerated) = mappings.getOrGeneratePrefix(
          'http://xmlns.com/newvocab/1.0/',
        );
        expect(newPrefix, equals('newvocab'));
        expect(newGenerated, isTrue);
      });

      test('handles domain parts correctly', () {
        final mappings = RdfNamespaceMappings();

        // For longer domain name, use first 2 chars
        final (examplePrefix, exampleGenerated) = mappings.getOrGeneratePrefix(
          'http://example.com/',
        );
        expect(examplePrefix, equals('ex'));
        expect(exampleGenerated, isTrue);

        // For short domain name, use whole name
        final (ibmPrefix, ibmGenerated) = mappings.getOrGeneratePrefix(
          'http://ibm.com/vocabulary/',
        );
        expect(ibmPrefix, equals('ibm'));
        expect(ibmGenerated, isTrue);

        // For hyphenated domain name, use initials
        final (dataGovPrefix, dataGovGenerated) = mappings.getOrGeneratePrefix(
          'http://data-gov.example.org/vocab/',
        );
        expect(dataGovPrefix, equals('dg'));
        expect(dataGovGenerated, isTrue);
      });

      test('handles URN format correctly', () {
        final mappings = RdfNamespaceMappings();

        final (isbnPrefix, isbnGenerated) = mappings.getOrGeneratePrefix(
          'urn:isbn:1234567890',
        );
        expect(isbnPrefix, equals('isbn'));
        expect(isbnGenerated, isTrue);

        final (uuidPrefix, uuidGenerated) = mappings.getOrGeneratePrefix(
          'urn:uuid:6e8bc430-9c3a-11d9-9669-0800200c9a66',
        );
        expect(uuidPrefix, equals('uuid'));
        expect(uuidGenerated, isTrue);
      });

      test('handles edge cases gracefully', () {
        final mappings = RdfNamespaceMappings();

        final custom = <String, String>{};
        // Invalid or malformed URI should still generate a prefix
        final (badPrefix, badGenerated) = mappings.getOrGeneratePrefix(
          'not-a-valid-uri',
          customMappings: custom,
        );
        expect(badPrefix, equals('ns1'));
        expect(badGenerated, isTrue);
        custom[badPrefix] = 'not-a-valid-uri';

        // Empty string
        final (emptyPrefix, emptyGenerated) = mappings.getOrGeneratePrefix(
          '',
          customMappings: custom,
        );
        expect(emptyPrefix, equals('ns2'));
        expect(emptyGenerated, isTrue);
      });

      test('prefix collisions', () {
        final mappings = RdfNamespaceMappings();

        final custom = <String, String>{};
        // Invalid or malformed URI should still generate a prefix
        final (ex, exGenerated) = mappings.getOrGeneratePrefix(
          'http://example.org/vocab#',
          customMappings: custom,
        );
        expect(ex, equals('ex'));
        expect(exGenerated, isTrue);
        custom[ex] = 'http://example.org/vocab#';

        // Empty string
        final (ex1Prefix, ex1Generated) = mappings.getOrGeneratePrefix(
          'http://examples.org#',
          customMappings: custom,
        );
        expect(ex1Prefix, equals('ex1'));
        expect(ex1Generated, isTrue);
      });
      test('overlapping namespace with collision', () {
        final mappings = RdfNamespaceMappings();

        final custom = <String, String>{};
        // Invalid or malformed URI should still generate a prefix
        final (ex, exGenerated) = mappings.getOrGeneratePrefix(
          'http://example.org/',
          customMappings: custom,
        );
        expect(ex, equals('ex'));
        expect(exGenerated, isTrue);
        custom[ex] = 'http://example.org/';

        // Empty string
        final (ex1Prefix, ex1Generated) = mappings.getOrGeneratePrefix(
          'http://example.org/ex#',
          customMappings: custom,
        );
        expect(ex1Prefix, equals('ex1'));
        expect(ex1Generated, isTrue);
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
