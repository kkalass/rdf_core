import 'package:rdf_core/rdf_core.dart';

/// This example demonstrates how to quickly and easily
/// parse and work with an RDF document using rdf_core.
///
/// It shows the simplest ways to work with the library,
/// even for complex operations.
void main() {
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

  // Print some basic information
  print('Parsed ${graph.triples.length} triples');

  // Find all people that Alice knows
  final aliceNode = IriTerm('http://example.org/alice');
  final knowsPredicate = IriTerm('http://xmlns.com/foaf/0.1/knows');

  final friendTriples =
      graph.findTriples(subject: aliceNode, predicate: knowsPredicate);

  print("\nAlice's friends:");
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

  // Convert to a different format (JSON-LD)
  final jsonld = jsonldGraph.encode(graph);
  print('\nJSON-LD representation:');
  print(jsonld);
}
