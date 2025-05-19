# Quick Start Guide for rdf_core

`rdf_core` is a type-safe Dart library for RDF data that combines flexibility with user-friendliness. This guide helps you get started quickly.

## Installation

```dart
dart pub add rdf_core
```

## Simple Use Cases

### 1. Parse and Use Turtle Data

```dart
import 'package:rdf_core/rdf_core.dart';

void main() {
  // Simple Turtle document
  final turtleData = '''
    @prefix foaf: <http://xmlns.com/foaf/0.1/> .
    
    <http://example.org/john> foaf:name "John Doe" ;
                              foaf:age 30 .
  ''';

  // Parse the Turtle data
  final graph = turtle.decode(turtleData);
  
  // Find John's age
  final johnNode = IriTerm('http://example.org/john');
  final ageNode = IriTerm('http://xmlns.com/foaf/0.1/age');
  
  final ageTriples = graph.findTriples(
    subject: johnNode,
    predicate: ageNode,
  );
  
  if (ageTriples.isNotEmpty) {
    final age = (ageTriples.first.object as LiteralTerm).value;
    print('John is $age years old.');
  }
}
```

### 2. Creating and Adding Triples

Here's how to create and manipulate triples directly:

```dart
import 'package:rdf_core/rdf_core.dart';

void main() {
  // Parse Turtle data
  final turtleData = '''
    @prefix foaf: <http://xmlns.com/foaf/0.1/> .
    <http://example.org/john> foaf:name "John Doe" ; foaf:age 30 .
  ''';
  
  final graph = turtle.decode(turtleData);
  
  // Find John's age using direct access
  final ageTriples = graph.findTriples(
    subject: IriTerm('http://example.org/john'),
    predicate: IriTerm('http://xmlns.com/foaf/0.1/age')
  );
  
  if (ageTriples.isNotEmpty) {
    final age = (ageTriples.first.object as LiteralTerm).value;
    print('John is $age years old.');
  }
  
  // Create a new graph with additional data
  final email = Triple(
    IriTerm('http://example.org/john'),
    IriTerm('http://xmlns.com/foaf/0.1/email'),
    LiteralTerm.string('john@example.org')
  );
  final newGraph = graph.withTriple(email);
  
  // Write as Turtle
  print(turtle.encode(newGraph));
}
```

## Creating and Manipulating RDF Graphs

### Creating a New Graph

```dart
import 'package:rdf_core/rdf_core.dart';

void main() {
  // Create an empty graph
  final graph = RdfGraph();
  
  // Create subject, predicate, and object
  final subject = IriTerm('http://example.org/book');
  final titlePredicate = IriTerm('http://purl.org/dc/elements/1.1/title');
  final titleObject = LiteralTerm.string('RDF Programming in Dart');
  
  // Create a triple and add it to the graph
  final triple = Triple(subject, titlePredicate, titleObject);
  final updatedGraph = graph.withTriple(triple);
  
  // Print the graph in Turtle format
  print(turtle.encode(updatedGraph));
}
```

### Working with Graph Data

```dart
import 'package:rdf_core/rdf_core.dart';

void main() {
  // Create a graph with data
  final graph = RdfGraph(triples: [
    Triple(
      IriTerm('http://example.org/book1'),
      IriTerm('http://purl.org/dc/elements/1.1/title'),
      LiteralTerm.string('RDF Fundamentals')
    ),
    Triple(
      IriTerm('http://example.org/book1'),
      IriTerm('http://purl.org/dc/elements/1.1/author'),
      IriTerm('http://example.org/john')
    ),
    Triple(
      IriTerm('http://example.org/book2'),
      IriTerm('http://purl.org/dc/elements/1.1/title'),
      LiteralTerm.string('Advanced RDF')
    )
  ]);
  
  // Find all books with their titles
  final titlePredicate = IriTerm('http://purl.org/dc/elements/1.1/title');
  final titleTriples = graph.findTriples(predicate: titlePredicate);
  
  for (final triple in titleTriples) {
    final book = triple.subject as IriTerm;
    final title = triple.object as LiteralTerm;
    print('${book.value} has title: ${title.value}');
  }
}
```

## Working with Different RDF Formats

### JSON-LD

```dart
import 'package:rdf_core/rdf_core.dart';

void main() {
  // Create a simple graph
  final graph = RdfGraph(triples: [
    Triple(
      IriTerm('http://example.org/person'),
      IriTerm('http://xmlns.com/foaf/0.1/name'),
      LiteralTerm.string('Jane Smith')
    ),
    Triple(
      IriTerm('http://example.org/person'),
      IriTerm('http://xmlns.com/foaf/0.1/age'),
      LiteralTerm.integer(28)
    )
  ]);
  
  // Convert to JSON-LD
  final jsonLdString = jsonldGraph.encode(graph);
  print('JSON-LD:\n$jsonLdString');
  
  // Parse back from JSON-LD
  final parsedGraph = jsonldGraph.decode(jsonLdString);
  print('Parsed back to ${parsedGraph.triples.length} triples');
}
```

### N-Triples

```dart
import 'package:rdf_core/rdf_core.dart';

void main() {
  // Create a graph
  final graph = RdfGraph(triples: [
    Triple(
      IriTerm('http://example.org/resource'),
      IriTerm('http://purl.org/dc/elements/1.1/creator'),
      LiteralTerm.string('Example Creator')
    )
  ]);
  
  // Convert to N-Triples
  final ntriplesString = ntriples.encode(graph);
  print('N-Triples:\n$ntriplesString');
}
```

## More Information

For more detailed examples and advanced usage, check out:

- [Cookbook](COOKBOOK.md) - Common patterns and solutions
- [Design Philosophy](DESIGN_PHILOSOPHY.md) - Core design principles of rdf_core
- [API Documentation](https://kkalass.github.io/rdf_core/api/rdf/index.html) - Complete API reference
