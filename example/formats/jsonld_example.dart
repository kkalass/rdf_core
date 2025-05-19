/// JSON-LD Format Example
///
/// This example demonstrates:
/// - Parsing JSON-LD data into an RDF graph
/// - Understanding JSON-LD context and term definitions
/// - Querying the resulting graph
/// - Serializing back to JSON-LD
///
/// JSON-LD is a JSON-based format to serialize Linked Data with support for
/// contexts that map JSON properties to IRIs and JSON values to typed RDF literals.
///
/// See the JSON-LD specification at: https://w3c.github.io/json-ld-syntax/
library;

import 'package:rdf_core/rdf_core.dart';

void main() {
  print('JSON-LD Format Example');
  print('=====================\n');

  // Example: Parse a JSON-LD document with a context that maps properties to IRIs
  final jsonLd = '''
  {
    "@context": {
      "name": "http://xmlns.com/foaf/0.1/name",
      "knows": {
        "@id": "http://xmlns.com/foaf/0.1/knows",
        "@type": "@id"
      },
      "Person": "http://xmlns.com/foaf/0.1/Person"
    },
    "@id": "http://example.org/alice",
    "@type": "Person",
    "name": "Alice",
    "knows": [
      {
        "@id": "http://example.org/bob",
        "@type": "Person",
        "name": "Bob"
      }
    ]
  }
  ''';

  final graph = jsonldGraph.decode(jsonLd);

  print('=== Parsed Triples ===');
  for (final triple in graph.triples) {
    print('${triple.subject} ${triple.predicate} ${triple.object}');
  }

  // Demonstrate querying the graph
  final aliceIri = IriTerm('http://example.org/alice');

  print('\n=== Query Results ===');
  final aliceTriples = graph.findTriples(subject: aliceIri);
  print('Alice has ${aliceTriples.length} triples:');
  for (final triple in aliceTriples) {
    print('  ${triple.predicate} ${triple.object}');
  }

  // Serialize the graph back to JSON-LD
  final serialized = jsonldGraph.encode(graph);
  print('\n=== Serialized JSON-LD ===');
  print(serialized);
}
