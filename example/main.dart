// RDF Core Quick-Start Example
//
// This example demonstrates the key features of rdf_core:
// - Creating RDF graphs manually and from data
// - Querying triples in a graph
// - Serializing and parsing RDF in different formats
// - Using custom prefixes and codecs

import 'package:rdf_core/rdf_core.dart';

void main() {
  print('RDF Core Quick-Start Example');
  print('===========================\n');

  // PART 1: Parse an existing RDF document
  print('PART 1: Parsing RDF Data\n');

  // Simple RDF document in Turtle format
  final turtleDoc = '''
    @prefix foaf: <http://xmlns.com/foaf/0.1/> .
    @prefix ex: <http://example.org/> .
    
    # Person with name and friends
    ex:alice foaf:name "Alice" ;
             foaf:knows ex:bob, ex:charlie .
    
    # Information about Bob
    ex:bob foaf:name "Bob" ;
           foaf:mbox "bob@example.org" .
  ''';

  // Parse the document using the global turtle parser
  final graph = turtle.decode(turtleDoc);

  print('Parsed ${graph.triples.length} triples\n');

  // PART 2: Query the graph to find information
  print('PART 2: Querying RDF Data\n');

  // Find all people that Alice knows
  final aliceNode = IriTerm('http://example.org/alice');
  final knowsPredicate = IriTerm('http://xmlns.com/foaf/0.1/knows');

  final friendTriples =
      graph.findTriples(subject: aliceNode, predicate: knowsPredicate);

  print("Alice's friends:");
  for (final triple in friendTriples) {
    final friendIri = triple.object as IriTerm;

    // Find the name of each friend
    final nameTriples = graph.findTriples(
        subject: friendIri,
        predicate: IriTerm('http://xmlns.com/foaf/0.1/name'));

    if (nameTriples.isNotEmpty) {
      final name = (nameTriples.first.object as LiteralTerm).value;
      print('- $name (${friendIri.iri})');
    } else {
      print('- ${friendIri.iri} (unnamed)');
    }
  }

  // PART 3: Manually create and extend an RDF graph
  print('\nPART 3: Creating RDF Data Manually\n');

  // Create some terms for our graph
  // NOTE: Always use canonical RDF vocabularies (e.g., http://xmlns.com/foaf/0.1/) with http://, not https://
  final alice = IriTerm('http://example.org/alice');
  final bob = IriTerm('http://example.org/bob');
  final charlie = IriTerm('http://example.org/charlie');
  final knows = IriTerm('http://xmlns.com/foaf/0.1/knows');
  final name = IriTerm('http://xmlns.com/foaf/0.1/name');
  final age = IriTerm('http://xmlns.com/foaf/0.1/age');

  // Create a new graph with manual triples
  final newGraph = RdfGraph(
    triples: [
      Triple(alice, name, LiteralTerm.string('Alice')),
      Triple(alice, age, LiteralTerm.integer(30)),
      Triple(alice, knows, bob),
      Triple(alice, knows, charlie),
      Triple(bob, name, LiteralTerm.string('Bob')),
      Triple(charlie, name, LiteralTerm.string('Charlie')),
    ],
  );

  print('Manual graph created with ${newGraph.triples.length} triples:');
  for (final triple in newGraph.triples) {
    print('  ${triple.subject} ${triple.predicate} ${triple.object}');
  }

  // PART 4: Serialize to different formats
  print('\nPART 4: Serializing RDF Data\n');

  // Serialize to Turtle with automatic prefixes
  final turtleStr = turtle.encode(newGraph);
  print('Turtle encoding (with automatic prefixes):\n$turtleStr');

  // Serialize to Turtle with custom prefixes
  final customTurtle = turtle
      .withOptions(
        encoder: RdfGraphEncoderOptions(
          customPrefixes: {
            'ex': 'http://example.org/',
            'foaf': 'http://xmlns.com/foaf/0.1/',
            'xsd': 'http://www.w3.org/2001/XMLSchema#',
          },
        ),
      )
      .encode(newGraph);

  print('\nTurtle encoding (with custom prefixes):\n$customTurtle');

  // Serialize to JSON-LD
  final jsonLd = jsonldGraph.encode(newGraph);
  print('\nJSON-LD encoding:\n$jsonLd');

  // PART 5: Using codecs based on content type
  print('\nPART 5: Using Content Type-Based Codecs\n');

  // Get a codec based on content type
  final contentType = 'application/n-triples';
  final codec = rdf.codec(contentType: contentType);

  // Encode using the selected codec (N-Triples in this case)
  final ntriplesStr = codec.encode(newGraph);
  print('N-Triples encoding (via content type):\n$ntriplesStr');

  // Auto-detect format when decoding
  print('\nAuto-detecting format:');
  final autoDetectedGraph = rdf.decode(ntriplesStr);
  print('Successfully decoded ${autoDetectedGraph.triples.length} triples');
}
