// A simple example demonstrating JSON-LD parsing and serialization with rdf_core.
import 'package:rdf_core/rdf_core.dart';

void main() {
  // Example: Parse a simple JSON-LD document
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

  // Initialize RdfCore with standard formats (includes JSON-LD)
  final rdf = RdfCore.withStandardFormats();
  final graph = rdf.parse(jsonLd, contentType: 'application/ld+json');

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
  final serialized = rdf.serialize(graph, contentType: 'application/ld+json');
  print('\n=== Serialized JSON-LD ===');
  print(serialized);
}