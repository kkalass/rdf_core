# RDF Core Cookbook

This collection of recipes shows you how to solve common RDF tasks quickly and easily with `rdf_core`.

## Contents

- [Basic Operations](#basic-operations)
- [Advanced Techniques](#advanced-techniques)
- [Practical Use Cases](#practical-use-cases)

## Basic Operations

### Creating Triples

```dart
import 'package:rdf_core/rdf_core.dart';

// Create a simple triple
final subject = IriTerm('http://example.org/alice');
final predicate = IriTerm('http://xmlns.com/foaf/0.1/name');
final object = LiteralTerm.string('Alice');
final triple = Triple(subject, predicate, object);
```

### Adding Triples to a Graph

```dart
import 'package:rdf_core/rdf_core.dart';

// Create a graph
final graph = RdfGraph();

// Create a triple
final triple = Triple(
  IriTerm('http://example.org/alice'),
  IriTerm('http://xmlns.com/foaf/0.1/name'),
  LiteralTerm.string('Alice')
);

// Add triple to graph (creating a new graph)
final updatedGraph = graph.withTriple(triple);
```

### Finding Triples

```dart
import 'package:rdf_core/rdf_core.dart';

// Find all triples for a specific subject
final subjectNode = IriTerm('http://example.org/alice');
final aliceTriples = graph.findTriples(subject: subjectNode);

// Find specific triple with subject and predicate
final nameTriples = graph.findTriples(
  subject: IriTerm('http://example.org/alice'),
  predicate: IriTerm('http://xmlns.com/foaf/0.1/name')
);
```

### Parsing from Different Formats

```dart
import 'package:rdf_core/rdf_core.dart';

// Parse Turtle
final turtleData = '''
  @prefix foaf: <http://xmlns.com/foaf/0.1/> .
  <http://example.org/alice> foaf:name "Alice" .
''';
final graph = turtle.decode(turtleData);

// Parse JSON-LD
final jsonLdData = '''
{
  "@context": {
    "foaf": "http://xmlns.com/foaf/0.1/"
  },
  "@id": "http://example.org/alice",
  "foaf:name": "Alice"
}
''';
final jsonLdGraph = jsonldGraph.decode(jsonLdData);

// Parse N-Triples
final ntriplesData = '<http://example.org/alice> <http://xmlns.com/foaf/0.1/name> "Alice" .';
final ntriplesGraph = ntriples.decode(ntriplesData);
```

### Serializing to Different Formats

```dart
import 'package:rdf_core/rdf_core.dart';

// Create a graph
final graph = RdfGraph(triples: [
  Triple(
    IriTerm('http://example.org/alice'),
    IriTerm('http://xmlns.com/foaf/0.1/name'),
    LiteralTerm.string('Alice')
  )
]);

// Serialize to Turtle
final turtleString = turtle.encode(graph);
print(turtleString);

// Serialize to JSON-LD
final jsonLdString = jsonldGraph.encode(graph);
print(jsonLdString);

// Serialize to N-Triples
final ntriplesString = ntriples.encode(graph);
print(ntriplesString);
```

## Advanced Techniques


### Working with Blank Nodes

```dart
import 'package:rdf_core/rdf_core.dart';

// Important: Equality is via object identity, we must re-use
// the same instance
final blankNode = BlankNodeTerm();

// Create a graph with blank nodes
final graph = RdfGraph(triples: [
  // Person has an address (blank node)
  Triple(
    IriTerm('http://example.org/john'),
    IriTerm('http://example.org/hasAddress'),
    blankNode
  ),
  // The address has a city
  Triple(
    blankNode,  // Use the same instance
    IriTerm('http://example.org/city'),
    LiteralTerm.string('Berlin')
  )
]);

// Find all blank nodes
final blankNodes = graph.triples
    .where((triple) => triple.subject is BlankNodeTerm || triple.object is BlankNodeTerm)
    .toList();
```

### Merging Graphs

```dart
import 'package:rdf_core/rdf_core.dart';

// Create two graphs
final graph1 = RdfGraph(triples: [
  Triple(
    IriTerm('http://example.org/alice'),
    IriTerm('http://xmlns.com/foaf/0.1/name'),
    LiteralTerm.string('Alice')
  )
]);

final graph2 = RdfGraph(triples: [
  Triple(
    IriTerm('http://example.org/alice'),
    IriTerm('http://xmlns.com/foaf/0.1/age'),
    LiteralTerm.integer(30)
  )
]);

// Merge the graphs
final mergedGraph = graph1.merge(graph2);
print('Merged graph has ${mergedGraph.triples.length} triples');
```

## Practical Use Cases

### Building a Knowledge Graph

```dart
import 'package:rdf_core/rdf_core.dart';

// Define vocabulary prefixes
final ex = 'http://example.org/';
final rdf = 'http://www.w3.org/1999/02/22-rdf-syntax-ns#';
final rdfs = 'http://www.w3.org/2000/01/rdf-schema#';

// Create class hierarchy
final graph = RdfGraph(triples: [
  // Define classes
  Triple(
    IriTerm('${ex}Person'),
    IriTerm('${rdf}type'),
    IriTerm('${rdfs}Class')
  ),
  Triple(
    IriTerm('${ex}Employee'),
    IriTerm('${rdf}type'),
    IriTerm('${rdfs}Class')
  ),
  Triple(
    IriTerm('${ex}Employee'),
    IriTerm('${rdfs}subClassOf'),
    IriTerm('${ex}Person')
  ),
  
  // Create instance
  Triple(
    IriTerm('${ex}john'),
    IriTerm('${rdf}type'),
    IriTerm('${ex}Employee')
  ),
  Triple(
    IriTerm('${ex}john'),
    IriTerm('${ex}name'),
    LiteralTerm.string('John Smith')
  ),
  Triple(
    IriTerm('${ex}john'),
    IriTerm('${ex}employeeID'),
    LiteralTerm.string('E12345')
  )
]);
```

### Simple SPARQL-like Queries

While `rdf_core` doesn't include a SPARQL engine, you can implement simple query patterns:

```dart
import 'package:rdf_core/rdf_core.dart';

// Find all employees
List<IriTerm> findAllEmployees(RdfGraph graph) {
  final employeeClass = IriTerm('http://example.org/Employee');
  final rdfType = IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#type');
  
  final employeeTriples = graph.findTriples(
    predicate: rdfType,
    object: employeeClass
  );
  
  return employeeTriples
      .map((triple) => triple.subject)
      .whereType<IriTerm>()
      .toList();
}

// Get all properties of a resource
Map<String, List<RdfObject>> getResourceProperties(RdfGraph graph, IriTerm subject) {
  final triples = graph.findTriples(subject: subject);
  
  final result = <String, List<RdfObject>>{};
  for (var triple in triples) {
    final predicate = (triple.predicate as IriTerm).value;
    result.putIfAbsent(predicate, () => []).add(triple.object);
  }
  
  return result;
}
```


## More Information

For more detailed examples and advanced usage, check out:

- [Getting Started](GETTING_STARTED.md) - Helps you getting started 
- [Design Philosophy](DESIGN_PHILOSOPHY.md) - Core design principles of rdf_core
- [API Documentation](https://kkalass.github.io/rdf_core/api/index.html) - Complete API reference
