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
      // Note the LiteralTerm.string convenience constructor which is the same as LiteralTerm('Alice', datatype: XsdTypes.string)
      Triple(alice, name, LiteralTerm.string('Alice')),
      Triple(bob, name, LiteralTerm.string('Bob')),
    ],
  );

  print('Manual RDF Graph:');
  for (final triple in graph.triples) {
    print('  ${triple.subject} ${triple.predicate} ${triple.object}');
  }

  // --- Serialize to Turtle ---
  var rdfCore = RdfCore.withStandardFormats();
  final turtleSerializer = rdfCore.getSerializer(contentType: 'text/turtle');
  final turtle = turtleSerializer.write(
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
  print('\nTurtle serialization:\n$turtle');

  // --- Parse from Turtle ---
  final parsedGraph = rdfCore
      .getParser(contentType: 'text/turtle')
      .parse(turtle);
  print('\nParsed from Turtle:');
  for (final triple in parsedGraph.triples) {
    print('  ${triple.subject} ${triple.predicate} ${triple.object}');
  }

  // --- Serialize to JSON-LD ---
  final jsonldSerializer = rdfCore.getSerializer(
    contentType: 'application/ld+json',
  );
  final jsonld = jsonldSerializer.write(graph);
  print('\nJSON-LD serialization:\n$jsonld');

  // --- Parse from JSON-LD ---
  final parsedFromJsonLd = rdfCore
      .getParser(contentType: 'application/ld+json')
      .parse(jsonld);
  print('\nParsed from JSON-LD:');
  for (final triple in parsedFromJsonLd.triples) {
    print('  ${triple.subject} ${triple.predicate} ${triple.object}');
  }
}
