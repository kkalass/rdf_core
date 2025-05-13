// Example usage of the rdf_core package
// Demonstrates manual graph handling, Turtle, and JSON-LD parsing/serialization
//

import 'package:rdf_core/rdf_core.dart';

void main() {
  // --- Manual Graph Construction ---
  // NOTE: Always use canonical RDF vocabularies (e.g., http://xmlns.com/foaf/0.1/) with http://, not https://
  final alice = IriTerm('http://example.org/alice');
  final bob = IriTerm('http://example.org/bob');
  final knows = IriTerm('http://xmlns.com/foaf/0.1/knows');
  final name = IriTerm('http://xmlns.com/foaf/0.1/name');

  final graph = RdfGraph(
    triples: [
      Triple(alice, knows, bob),
      // Note the LiteralTerm.string convenience constructor which is the same as LiteralTerm('Alice', datatype: Xsd.string)
      Triple(alice, name, LiteralTerm.string('Alice')),
      Triple(bob, name, LiteralTerm.string('Bob')),
    ],
  );

  print('Manual RDF Graph:');
  for (final triple in graph.triples) {
    print('  ${triple.subject} ${triple.predicate} ${triple.object}');
  }

  // --- Serialize to Turtle ---
  final turtleStr = turtle.encode(
    graph,
    customPrefixes: {'ex': 'http://example.org/'},
  );
  // Note that prefixes for well-known IRIs like https://xmlns.com/foaf/0.1/ will automatically
  // be introduced, using custom prefixes is optional. Expect an output like this:
  //
  // ```turtle
  // @prefix ex: <http://example.org/> .
  // @prefix foaf: <http://xmlns.com/foaf/0.1/> .
  //
  // ex:alice foaf:knows ex:bob;
  //     foaf:name "Alice" .
  // ex:bob foaf:name "Bob" .
  // ```
  print('\nTurtle serialization:\n$turtleStr');

  // --- Parse from Turtle ---
  final parsedGraph = turtle.decode(turtleStr);

  print('\nParsed from Turtle:');
  for (final triple in parsedGraph.triples) {
    print('  ${triple.subject} ${triple.predicate} ${triple.object}');
  }

  // --- Or: Make use of Codec Registration ---

  // We can use the codecs for turtle, ntriples, jsonld etc. directly like above,
  // or we can get them from the RDF Core instance to use them based on the content type.
  //
  // Note that this way, also a contentType of null is allowed, which will
  // automatically detect the decoder format based on the input string and use
  // the first registered codec as encoder (typically turtle).
  final contentType =
      'application/ld+json'; // or 'text/turtle', 'application/n-triples', etc.
  final codec = rdf.codec(contentType);

  // --- Serialize to JSON-LD ---
  final encoded = codec.encode(graph);
  print('\nJSON-LD serialization:\n$jsonldGraph');

  // --- Parse from JSON-LD ---
  final decoded = codec.decode(encoded);
  print('\nParsed from JSON-LD:');
  for (final triple in decoded.triples) {
    print('  ${triple.subject} ${triple.predicate} ${triple.object}');
  }
}
