// NOTE: Always use canonical RDF vocabularies (e.g., http://xmlns.com/foaf/0.1/) with http://, not https://
import 'dart:convert';

import 'package:rdf_core/graph/rdf_graph.dart';
import 'package:rdf_core/graph/rdf_term.dart';
import 'package:rdf_core/graph/triple.dart';
import 'package:rdf_core/jsonld/jsonld_serializer.dart';
import 'package:rdf_core/vocab/vocab.dart';
import 'package:test/test.dart';

void main() {
  group('JSON-LD Serializer', () {
    late JsonLdSerializer serializer;

    setUp(() {
      serializer = JsonLdSerializer();
    });

    test('should serialize empty graph to empty JSON object', () {
      final graph = RdfGraph();
      final result = serializer.write(graph);
      expect(result, '{}');
    });

    test('should serialize simple triple with literal', () {
      final graph = RdfGraph.fromTriples([
        Triple(
          IriTerm('http://example.org/subject'),
          IriTerm('http://example.org/predicate'),
          LiteralTerm.string('object'),
        ),
      ]);

      final result = serializer.write(graph);

      // Parse the JSON to verify structure
      final jsonObj = jsonDecode(result) as Map<String, dynamic>;

      expect(jsonObj.containsKey('@context'), isTrue);
      expect(jsonObj['@id'], equals('http://example.org/subject'));
      // Since example.org doesn't have a default prefix, the full IRI is used
      expect(jsonObj['http://example.org/predicate'], equals('object'));
    });

    test('should handle rdf:type with @type keyword', () {
      final graph = RdfGraph.fromTriples([
        Triple(
          IriTerm('http://example.org/subject'),
          RdfPredicates.type,
          IriTerm('http://example.org/Class'),
        ),
      ]);

      final result = serializer.write(graph);
      final jsonObj = jsonDecode(result) as Map<String, dynamic>;

      expect(jsonObj['@context']['rdf'], equals(Rdf.namespace));
      expect(jsonObj['@id'], equals('http://example.org/subject'));
      expect(jsonObj['@type'], isA<Map<String, dynamic>>());
      expect(jsonObj['@type']['@id'], equals('http://example.org/Class'));
    });

    test('should use @graph for multiple subjects', () {
      final graph = RdfGraph.fromTriples([
        Triple(
          IriTerm('http://example.org/subject1'),
          IriTerm('http://example.org/predicate'),
          LiteralTerm.string('object1'),
        ),
        Triple(
          IriTerm('http://example.org/subject2'),
          IriTerm('http://example.org/predicate'),
          LiteralTerm.string('object2'),
        ),
      ]);

      final result = serializer.write(graph);
      final jsonObj = jsonDecode(result) as Map<String, dynamic>;

      expect(jsonObj.containsKey('@context'), isTrue);
      expect(jsonObj.containsKey('@graph'), isTrue);
      expect(jsonObj['@graph'], isA<List>());
      expect(jsonObj['@graph'].length, equals(2));
    });

    test('should handle blank nodes', () {
      // Create a blank node and use it in a triple
      final blankNode = BlankNodeTerm();
      final graph = RdfGraph.fromTriples([
        Triple(
          IriTerm('http://example.org/subject'),
          IriTerm('http://example.org/predicate'),
          blankNode,
        ),
      ]);

      final result = serializer.write(graph);
      final jsonObj = jsonDecode(result) as Map<String, dynamic>;

      expect(
        jsonObj['http://example.org/predicate'],
        isA<Map<String, dynamic>>(),
      );

      // The blank node will have a generated label that starts with '_:'
      expect(jsonObj['http://example.org/predicate']['@id'], startsWith('_:'));
    });

    test('should handle typed literals', () {
      final graph = RdfGraph.fromTriples([
        Triple(
          IriTerm('http://example.org/subject'),
          IriTerm('http://example.org/intValue'),
          LiteralTerm(
            '42',
            datatype: IriTerm('http://www.w3.org/2001/XMLSchema#integer'),
          ),
        ),
        Triple(
          IriTerm('http://example.org/subject'),
          IriTerm('http://example.org/floatValue'),
          LiteralTerm(
            '3.14',
            datatype: IriTerm('http://www.w3.org/2001/XMLSchema#decimal'),
          ),
        ),
        Triple(
          IriTerm('http://example.org/subject'),
          IriTerm('http://example.org/boolValue'),
          LiteralTerm(
            'true',
            datatype: IriTerm('http://www.w3.org/2001/XMLSchema#boolean'),
          ),
        ),
      ]);

      final result = serializer.write(graph);
      final jsonObj = jsonDecode(result) as Map<String, dynamic>;

      expect(
        jsonObj['@context']['xsd'],
        equals('http://www.w3.org/2001/XMLSchema#'),
      );
      expect(jsonObj['http://example.org/intValue'], equals(42));
      expect(jsonObj['http://example.org/floatValue'], equals(3.14));
      expect(jsonObj['http://example.org/boolValue'], equals(true));
    });

    test('should handle language-tagged literals', () {
      final graph = RdfGraph.fromTriples([
        Triple(
          IriTerm('http://example.org/subject'),
          IriTerm('http://example.org/name'),
          LiteralTerm.withLanguage('John Doe', 'en'),
        ),
      ]);

      final result = serializer.write(graph);
      final jsonObj = jsonDecode(result) as Map<String, dynamic>;

      final nameValue = jsonObj['http://example.org/name'];
      expect(nameValue, isA<Map<String, dynamic>>());
      expect(nameValue['@value'], equals('John Doe'));
      expect(nameValue['@language'], equals('en'));
    });

    test('should use custom prefixes when provided', () {
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

      final result = serializer.write(graph, customPrefixes: customPrefixes);

      final jsonObj = jsonDecode(result) as Map<String, dynamic>;

      expect(jsonObj['@context']['ex'], equals('http://example.org/'));
      expect(
        jsonObj['@context']['vocab'],
        equals('http://example.org/vocabulary/'),
      );
      // Now we expect the prefixed version of the predicate
      expect(jsonObj['vocab:predicate'], equals('object'));
    });

    test('should serialize complex graph correctly using prefixes', () {
      final graph = RdfGraph.fromTriples([
        Triple(
          IriTerm('http://example.org/person/john'),
          RdfPredicates.type,
          IriTerm('http://xmlns.com/foaf/0.1/Person'),
        ),
        Triple(
          IriTerm('http://example.org/person/john'),
          IriTerm('http://xmlns.com/foaf/0.1/name'),
          LiteralTerm.string('John Doe'),
        ),
        Triple(
          IriTerm('http://example.org/person/john'),
          IriTerm('http://xmlns.com/foaf/0.1/age'),
          LiteralTerm(
            '42',
            datatype: IriTerm('http://www.w3.org/2001/XMLSchema#integer'),
          ),
        ),
        Triple(
          IriTerm('http://example.org/person/john'),
          IriTerm('http://xmlns.com/foaf/0.1/knows'),
          IriTerm('http://example.org/person/jane'),
        ),
        Triple(
          IriTerm('http://example.org/person/jane'),
          RdfPredicates.type,
          IriTerm('http://xmlns.com/foaf/0.1/Person'),
        ),
        Triple(
          IriTerm('http://example.org/person/jane'),
          IriTerm('http://xmlns.com/foaf/0.1/name'),
          LiteralTerm.string('Jane Smith'),
        ),
      ]);

      final result = serializer.write(graph);
      final jsonObj = jsonDecode(result) as Map<String, dynamic>;

      expect(jsonObj['@context']['foaf'], equals('http://xmlns.com/foaf/0.1/'));
      expect(jsonObj['@context']['rdf'], equals(Rdf.namespace));
      expect(jsonObj.containsKey('@graph'), isTrue);

      final graph1 = jsonObj['@graph'].firstWhere(
        (node) => node['@id'] == 'http://example.org/person/john',
      );

      expect(
        graph1['@type']['@id'],
        equals('http://xmlns.com/foaf/0.1/Person'),
      );
      expect(graph1['foaf:name'], equals('John Doe'));
      expect(graph1['foaf:age'], equals(42));
      expect(
        graph1['foaf:knows']['@id'],
        equals('http://example.org/person/jane'),
      );

      final graph2 = jsonObj['@graph'].firstWhere(
        (node) => node['@id'] == 'http://example.org/person/jane',
      );
      expect(graph2['foaf:name'], equals('Jane Smith'));
    });

    test(
      'should automatically add and use foaf prefix when relevant IRIs are present',
      () {
        final graph = RdfGraph.fromTriples([
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
        ]);

        final serializer = JsonLdSerializer();
        final result = serializer.write(graph);
        final jsonObj = jsonDecode(result) as Map<String, dynamic>;

        expect(
          jsonObj['@context']['foaf'],
          equals('http://xmlns.com/foaf/0.1/'),
        );
        expect(jsonObj['@context']['xsd'], isNull);
        expect(jsonObj['foaf:name'], equals('Alice'));
        expect(jsonObj['foaf:knows']['@id'], equals('http://example.org/bob'));
      },
    );

    test('should consistently handle blank nodes in a graph', () {
      // Create multiple triples using the same blank node
      final blankNode = BlankNodeTerm();

      final graph = RdfGraph.fromTriples([
        Triple(
          IriTerm('http://example.org/resource'),
          IriTerm('http://example.org/hasProperty'),
          blankNode,
        ),
        Triple(
          blankNode,
          IriTerm('http://example.org/name'),
          LiteralTerm.string('Property Name'),
        ),
        Triple(
          blankNode,
          IriTerm('http://example.org/value'),
          LiteralTerm.string('Property Value'),
        ),
      ]);

      final result = serializer.write(graph);
      final jsonObj = jsonDecode(result) as Map<String, dynamic>;

      // Extract all blank node IDs from the serialized JSON-LD
      final blankNodeIds = _extractAllBlankNodeIds(jsonObj);

      // There should be exactly one unique blank node ID used consistently
      expect(
        blankNodeIds.length,
        equals(1),
        reason: 'There should be exactly one unique blank node ID',
      );

      // The blank node ID should appear 3 times (once as object, twice as subject)
      expect(
        _countBlankNodeIdOccurrences(jsonObj, blankNodeIds.first),
        equals(3),
        reason: 'The blank node ID should be used 3 times',
      );
    });

    test('should handle non-parseable literals correctly', () {
      final graph = RdfGraph.fromTriples([
        Triple(
          IriTerm('http://example.org/subject'),
          IriTerm('http://example.org/invalidInt'),
          LiteralTerm(
            'not-an-integer',
            datatype: IriTerm('http://www.w3.org/2001/XMLSchema#integer'),
          ),
        ),
        Triple(
          IriTerm('http://example.org/subject'),
          IriTerm('http://example.org/invalidFloat'),
          LiteralTerm(
            'not-a-float',
            datatype: IriTerm('http://www.w3.org/2001/XMLSchema#decimal'),
          ),
        ),
        Triple(
          IriTerm('http://example.org/subject'),
          IriTerm('http://example.org/invalidBool'),
          LiteralTerm(
            'not-a-boolean',
            datatype: IriTerm('http://www.w3.org/2001/XMLSchema#boolean'),
          ),
        ),
      ]);

      final result = serializer.write(graph);
      final jsonObj = jsonDecode(result) as Map<String, dynamic>;

      // Check that non-parsable numeric values have correct type info
      expect(
        jsonObj['http://example.org/invalidInt']['@value'],
        equals('not-an-integer'),
      );
      expect(
        jsonObj['http://example.org/invalidInt']['@type'],
        equals('http://www.w3.org/2001/XMLSchema#integer'),
      );

      expect(
        jsonObj['http://example.org/invalidFloat']['@value'],
        equals('not-a-float'),
      );
      expect(
        jsonObj['http://example.org/invalidFloat']['@type'],
        equals('http://www.w3.org/2001/XMLSchema#decimal'),
      );

      expect(
        jsonObj['http://example.org/invalidBool']['@value'],
        equals('not-a-boolean'),
      );
      expect(
        jsonObj['http://example.org/invalidBool']['@type'],
        equals('http://www.w3.org/2001/XMLSchema#boolean'),
      );
    });

    test('should handle literals with custom datatypes', () {
      final graph = RdfGraph.fromTriples([
        Triple(
          IriTerm('http://example.org/subject'),
          IriTerm('http://example.org/predicate'),
          LiteralTerm(
            'custom value',
            datatype: IriTerm('http://example.org/custom-datatype'),
          ),
        ),
      ]);

      final result = serializer.write(graph);
      final jsonObj = jsonDecode(result) as Map<String, dynamic>;

      final value = jsonObj['http://example.org/predicate'];
      expect(value, isA<Map<String, dynamic>>());
      expect(value['@value'], equals('custom value'));
      expect(value['@type'], equals('http://example.org/custom-datatype'));
    });

    test('should handle multiple types as an array', () {
      final graph = RdfGraph.fromTriples([
        Triple(
          IriTerm('http://example.org/subject'),
          RdfPredicates.type,
          IriTerm('http://example.org/Type1'),
        ),
        Triple(
          IriTerm('http://example.org/subject'),
          RdfPredicates.type,
          IriTerm('http://example.org/Type2'),
        ),
      ]);

      final result = serializer.write(graph);
      final jsonObj = jsonDecode(result) as Map<String, dynamic>;

      expect(jsonObj['@type'], isA<List>());
      expect(jsonObj['@type'].length, equals(2));

      final typeIds = jsonObj['@type'].map((t) => t['@id']).toList();
      expect(typeIds, contains('http://example.org/Type1'));
      expect(typeIds, contains('http://example.org/Type2'));
    });

    test('should handle multiple values for predicates as arrays', () {
      final graph = RdfGraph.fromTriples([
        Triple(
          IriTerm('http://example.org/subject'),
          IriTerm('http://example.org/predicate'),
          LiteralTerm.string('value1'),
        ),
        Triple(
          IriTerm('http://example.org/subject'),
          IriTerm('http://example.org/predicate'),
          LiteralTerm.string('value2'),
        ),
      ]);

      final result = serializer.write(graph);
      final jsonObj = jsonDecode(result) as Map<String, dynamic>;

      expect(jsonObj['http://example.org/predicate'], isA<List>());
      expect(jsonObj['http://example.org/predicate'].length, equals(2));
      expect(jsonObj['http://example.org/predicate'], contains('value1'));
      expect(jsonObj['http://example.org/predicate'], contains('value2'));
    });

    test('should detect namespaces with overlap when creating context', () {
      final graph = RdfGraph.fromTriples([
        Triple(
          IriTerm('http://example.org/subject'),
          IriTerm('http://example.org/vocabulary/predicate1'),
          LiteralTerm.string('value1'),
        ),
        Triple(
          IriTerm('http://example.org/subject'),
          IriTerm('http://example.org/vocabulary/nested/predicate2'),
          LiteralTerm.string('value2'),
        ),
      ]);

      final customPrefixes = {
        'ex': 'http://example.org/',
        'vocab': 'http://example.org/vocabulary/',
        'nested': 'http://example.org/vocabulary/nested/',
      };

      final result = serializer.write(graph, customPrefixes: customPrefixes);
      final jsonObj = jsonDecode(result) as Map<String, dynamic>;

      // The more specific prefix should be used for the nested predicate
      expect(jsonObj['vocab:predicate1'], equals('value1'));
      expect(jsonObj['nested:predicate2'], equals('value2'));
    });

    test('should handle direct namespace match in context', () {
      final graph = RdfGraph.fromTriples([
        Triple(
          IriTerm('http://example.org/subject'),
          IriTerm('http://example.org/vocabulary/'),
          LiteralTerm.string('direct namespace'),
        ),
      ]);

      final customPrefixes = {'vocab': 'http://example.org/vocabulary/'};

      final result = serializer.write(graph, customPrefixes: customPrefixes);
      final jsonObj = jsonDecode(result) as Map<String, dynamic>;

      // When the predicate exactly matches a namespace, use the prefix with empty local part
      expect(jsonObj['vocab:'], equals('direct namespace'));
    });

    test('should preserve non-common namespaces in the context', () {
      final graph = RdfGraph.fromTriples([
        Triple(
          IriTerm('http://example.org/subject'),
          IriTerm('http://uncommon.namespace.org/predicate'),
          LiteralTerm.string('value'),
        ),
      ]);

      final result = serializer.write(graph);
      final jsonObj = jsonDecode(result) as Map<String, dynamic>;

      // The full IRI should be used since there's no prefix mapping
      expect(
        jsonObj['http://uncommon.namespace.org/predicate'],
        equals('value'),
      );
    });

    test('should handle double datatype literals', () {
      final graph = RdfGraph.fromTriples([
        Triple(
          IriTerm('http://example.org/subject'),
          IriTerm('http://example.org/doubleValue'),
          LiteralTerm(
            '3.14159265',
            datatype: IriTerm('http://www.w3.org/2001/XMLSchema#double'),
          ),
        ),
      ]);

      final result = serializer.write(graph);
      final jsonObj = jsonDecode(result) as Map<String, dynamic>;

      // The double value should be parsed and represented as a number
      expect(jsonObj['http://example.org/doubleValue'], equals(3.14159265));
    });
  });
}

/// Extracts all blank node IDs from a JSON-LD object.
Set<String> _extractAllBlankNodeIds(Map<String, dynamic> jsonLd) {
  final blankNodeIds = <String>{};

  // Check for direct blank node IDs in the main object
  _findBlankNodeIds(jsonLd, blankNodeIds);

  // Check for blank node IDs in @graph if present
  if (jsonLd.containsKey('@graph') && jsonLd['@graph'] is List) {
    for (final node in jsonLd['@graph']) {
      if (node is Map<String, dynamic>) {
        _findBlankNodeIds(node, blankNodeIds);
      }
    }
  }

  return blankNodeIds;
}

/// Recursively finds blank node IDs in a JSON-LD node.
void _findBlankNodeIds(Map<String, dynamic> node, Set<String> blankNodeIds) {
  // Check if this node itself is a blank node
  if (node.containsKey('@id') && node['@id'] is String) {
    final id = node['@id'] as String;
    if (id.startsWith('_:')) {
      blankNodeIds.add(id);
    }
  }

  // Check all properties for blank node references
  for (final entry in node.entries) {
    if (entry.key != '@context' && entry.key != '@graph') {
      if (entry.value is Map<String, dynamic>) {
        // Property with a single object value
        final valueObj = entry.value as Map<String, dynamic>;
        if (valueObj.containsKey('@id') &&
            valueObj['@id'] is String &&
            (valueObj['@id'] as String).startsWith('_:')) {
          blankNodeIds.add(valueObj['@id'] as String);
        }

        // Recursively check nested objects
        _findBlankNodeIds(valueObj, blankNodeIds);
      } else if (entry.value is List) {
        // Property with multiple values
        for (final item in entry.value) {
          if (item is Map<String, dynamic> &&
              item.containsKey('@id') &&
              item['@id'] is String &&
              (item['@id'] as String).startsWith('_:')) {
            blankNodeIds.add(item['@id'] as String);
          }

          // Recursively check nested objects in the list
          if (item is Map<String, dynamic>) {
            _findBlankNodeIds(item, blankNodeIds);
          }
        }
      }
    }
  }
}

/// Counts the number of occurrences of a specific blank node ID in a JSON-LD object.
int _countBlankNodeIdOccurrences(
  Map<String, dynamic> jsonLd,
  String blankNodeId,
) {
  int count = 0;

  // Check for occurrences in the main object
  count += _countBlankNodeIdInNode(jsonLd, blankNodeId);

  // Check for occurrences in @graph if present
  if (jsonLd.containsKey('@graph') && jsonLd['@graph'] is List) {
    for (final node in jsonLd['@graph']) {
      if (node is Map<String, dynamic>) {
        count += _countBlankNodeIdInNode(node, blankNodeId);
      }
    }
  }

  return count;
}

/// Recursively counts occurrences of a specific blank node ID in a JSON-LD node.
int _countBlankNodeIdInNode(Map<String, dynamic> node, String blankNodeId) {
  int count = 0;

  // Check if this node itself is the blank node we're looking for
  if (node.containsKey('@id') && node['@id'] == blankNodeId) {
    count++;
  }

  // Check all properties for references to our blank node
  for (final entry in node.entries) {
    if (entry.key != '@context' && entry.key != '@graph') {
      if (entry.value is Map<String, dynamic>) {
        // Property with a single object value
        final valueObj = entry.value as Map<String, dynamic>;
        if (valueObj.containsKey('@id') && valueObj['@id'] == blankNodeId) {
          count++;
        }

        // Recursively check nested objects
        count += _countBlankNodeIdInNode(valueObj, blankNodeId);
      } else if (entry.value is List) {
        // Property with multiple values
        for (final item in entry.value) {
          if (item is Map<String, dynamic> &&
              item.containsKey('@id') &&
              item['@id'] == blankNodeId) {
            count++;
          }

          // Recursively check nested objects in the list
          if (item is Map<String, dynamic>) {
            count += _countBlankNodeIdInNode(item, blankNodeId);
          }
        }
      }
    }
  }

  return count;
}
