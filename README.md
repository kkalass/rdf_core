<div align="center">
  <img src="https://kkalass.github.io/rdf_core/logo.svg" alt="rdf_core logo" width="96" height="96"/>
</div>

# RDF Core

[![pub package](https://img.shields.io/pub/v/rdf_core.svg)](https://pub.dev/packages/rdf_core)
[![build](https://github.com/kkalass/rdf_core/actions/workflows/ci.yml/badge.svg)](https://github.com/kkalass/rdf_core/actions)
[![codecov](https://codecov.io/gh/kkalass/rdf_core/branch/main/graph/badge.svg)](https://codecov.io/gh/kkalass/rdf_core)
[![license](https://img.shields.io/github/license/kkalass/rdf_core.svg)](https://github.com/kkalass/rdf_core/blob/main/LICENSE)

A type-safe and extensible Dart library for representing and manipulating RDF data without additional dependencies (except for logging).

## Core of a whole family of projects

If you are looking for more rdf-related functionality, have a look at our companion projects:

- Encode and decode RDF/XML format: [rdf_xml](https://github.com/kkalass/rdf_xml)
- Easy-to-use constants for many well-known vocabularies: [rdf_vocabularies](https://github.com/kkalass/rdf_vocabularies)
- Generate your own easy-to-use constants for other vocabularies with a build_runner: [rdf_vocabulary_to_dart](https://github.com/kkalass/rdf_vocabulary_to_dart)
- Map Dart Objects ↔️ RDF: [rdf_mapper](https://github.com/kkalass/rdf_mapper)

**Further Resources:** [🚀 **Getting Started Guide**](doc/GETTING_STARTED.md) | [📚 **Cookbook with Recipes**](doc/COOKBOOK.md) | [🛠️ **Design Philosophy**](doc/DESIGN_PHILOSOPHY.md) | [🌐 **Official Homepage**](https://kkalass.github.io/rdf_core/)

## Installation

```dart
dart pub add rdf_core
```

## 🚀 Quick Start

```dart
import 'package:rdf_core/rdf_core.dart';

void main() {
  // Parse Turtle data
  final turtleString = '''
    @prefix foaf: <http://xmlns.com/foaf/0.1/> .
    <http://example.org/john> foaf:name "John Doe" ; foaf:age 30 .
  ''';
  
  // Decode turtle data to an RDF graph
  final graph = turtle.decode(turtleString);
  
  // Find triples with specific subject and predicate
  final nameTriples = graph.findTriples(
    subject: IriTerm('http://example.org/john'),
    predicate: IriTerm('http://xmlns.com/foaf/0.1/name')
  );
  
  if (nameTriples.isNotEmpty) {
    final name = (nameTriples.first.object as LiteralTerm).value;
    print('Name: $name');
  }
  
  // Create and add a new triple
  final subject = IriTerm('http://example.org/john');
  final predicate = IriTerm('http://xmlns.com/foaf/0.1/email');
  final object = LiteralTerm.string('john@example.org');
  final triple = Triple(subject, predicate, object);
  final updatedGraph = graph.withTriple(triple);
  
  // Encode the graph as Turtle
  print(turtle.encode(updatedGraph));
}
```

## ✨ Features

- **Type-safe RDF model:** IRIs, literals, triples, graphs, and more
- **Serialization-agnostic:** Clean separation of Turtle/JSON-LD/N-Triples
- **Extensible & modular:** Create your own adapters, plugins, and integrations
- **Specification compliant:** Follows [W3C RDF 1.1](https://www.w3.org/TR/rdf11-concepts/) and related standards
- **Convenient global variables:** Easy to use with `turtle`, `jsonld` and `ntriples` for quick encoding/decoding

## Core API Usage

### Global Variables for Easy Access

```dart
import 'package:rdf_core/rdf_core.dart';

// Global variables for quick access to codecs
final graphFromTurtle = turtle.decode(turtleString);
final graphFromJsonLd = jsonldGraph.decode(jsonLdString);
final graphFromNTriples = ntriples.decode(ntriplesString);

// Or use the preconfigured RdfCore instance
final graph = rdf.decode(data, contentType: 'text/turtle');
final encoded = rdf.encode(graph, contentType: 'application/ld+json');
```

### Manually Creating a Graph

```dart
import 'package:rdf_core/rdf_core.dart';

void main() {
  // Create an empty graph
  final graph = RdfGraph();
  
  // Create a triple
  final subject = IriTerm('http://example.org/alice');
  final predicate = IriTerm('http://xmlns.com/foaf/0.1/name');
  final object = LiteralTerm.string('Alice');
  final triple = Triple(subject, predicate, object);
  final graph = RdfGraph(triples: [triple]);

  print(graph);
}
```

### Decoding and Encoding Turtle

```dart
import 'package:rdf_core/rdf_core.dart';

void main() {
  // Example: Decode a simple Turtle document
  final turtleData = '''
    @prefix foaf: <http://xmlns.com/foaf/0.1/> .
    <http://example.org/alice> foaf:name "Alice"@en .
  ''';

  // Option 1: Using the convenience global variable
  final graph = turtle.decode(turtleData);
  
  // Option 2: Using RdfCore instance
  // final rdfCore = RdfCore.withStandardCodecs();
  // final graph = rdfCore.decode(turtleData, contentType: 'text/turtle');

  // Print decoded triples
  for (final triple in graph.triples) {
    print('${triple.subject} ${triple.predicate} ${triple.object}');
  }

  // Encode the graph back to Turtle
  final serialized = turtle.encode(graph);
  print('\nEncoded Turtle:\n$serialized');
}
```

### Decoding and Encoding N-Triples

```dart
import 'package:rdf_core/rdf_core.dart';

void main() {
  // Example: Decode a simple N-Triples document
  final ntriplesData = '''
    <http://example.org/alice> <http://xmlns.com/foaf/0.1/name> "Alice"@en .
    <http://example.org/alice> <http://xmlns.com/foaf/0.1/knows> <http://example.org/bob> .
  ''';

  // Using the convenience global variable
  final graph = ntriples.decode(ntriplesData);

  // Print decoded triples
  for (final triple in graph.triples) {
    print('${triple.subject} ${triple.predicate} ${triple.object}');
  }

  // Encode the graph back to N-Triples
  final serialized = ntriples.encode(graph);
  print('\nEncoded N-Triples:\n$serialized');
}
```

### Decoding and Encoding JSON-LD

```dart
import 'package:rdf_core/rdf_core.dart';

void main() {
  // Example: Decode a simple JSON-LD document
  final jsonLdData = '''
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

  // Using the convenience global variable
  final graph = jsonldGraph.decode(jsonLdData);

  // Print decoded triples
  for (final triple in graph.triples) {
    print('${triple.subject} ${triple.predicate} ${triple.object}');
  }

  // Encode the graph back to JSON-LD
  final serialized = jsonldGraph.encode(graph);
  print('\nEncoded JSON-LD:\n$serialized');
}
```

## 🧑‍💻 Advanced Usage

### Decoding and Encoding RDF/XML

With the help of the separate package [rdf_xml](https://github.com/kkalass/rdf_xml) you can easily encode/decode RDF/XML as well.

```bash
dart pub add rdf_xml
```

```dart
import 'package:rdf_core/rdf_core.dart';
import 'package:rdf_xml/rdf_xml.dart';

void main() {
  
  // Option 1: Use the codec directly
  final graph = rdfxml.decode(rdfXmlData);
  final serialized = rdfxml.encode(graph);
  
  // Option 2: Register with RdfCore
  final rdf = RdfCore.withStandardCodecs(additionalCodecs: [RdfXmlCodec()])
  
  // Now it can be used with the rdf instance in addition to turtle etc.
  final graphFromRdf = rdf.decode(rdfXmlData, contentType: 'application/rdf+xml');
}
```

### Graph Merging

```dart
final merged = graph1.merge(graph2);
```

### Pattern Queries

```dart
final results = graph.findTriples(subject: subject);
```

### Blank Node Handling

```dart
// Note: BlankNodeTerm is based on identity - if you call BlankNodeTerm() 
// a second time, it will be a different blank node and get a different 
// label in encoding codecs. You have to reuse an instance, if you
// want to refer to the same blank node.
final bnode = BlankNodeTerm();
final newGraph = graph.withTriple(Triple(bnode, predicate, object));
```

### Non-Standard Turtle decoding

```dart
import 'package:rdf_core/rdf_core.dart';

final nonStandardTurtle = '''
@base <http://my.example.org/> .
@prefix ex: <http://example.org/> 
ex:resource123 a Type . // "Type" without prefix is resolved to <http://my.example.org/Type>
''';

// Create an options instance with the appropriate configuration
final options = TurtleDecoderOptions(
  parsingFlags: {
    TurtleParsingFlag.allowDigitInLocalName,       // Allow local names with digits like "resource123"
    TurtleParsingFlag.allowMissingDotAfterPrefix,  // Allow prefix declarations without trailing dot
    TurtleParsingFlag.allowIdentifiersWithoutColon, // Treat terms without colon as IRIs resolved against base URI
  }
);

// Option 1: Use the options with the global rdf variable
final graph = rdf.decode(nonStandardTurtle, options: options);

// Option 2: Use the options to derive a new codec from the global turtle variable
final configuredTurtle = turtle.withOptions(decoder: options);
final graph2 = configuredTurtle.decode(nonStandardTurtle);

// Option 3: Configure a custom TurtleCodec with specific parsing flags
final customTurtleCodec = TurtleCodec(decoderOptions: options);
final graph3 = customTurtleCodec.decode(nonStandardTurtle);

// Option 4: Register the custom codec with an RdfCore instance - note that this 
// time we register only the specified codecs here. If we want jsonld, we have to 
// add it to the list as well.
final customRdf = RdfCore.withCodecs(codecs: [customTurtleCodec]);
final graph4 = customRdf.decode(nonStandardTurtle, contentType: 'text/turtle');
```

---

## ⚠️ Error Handling

- All core methods throw Dart exceptions (e.g., `ArgumentError`, `RdfValidationException`) for invalid input or constraint violations.
- Catch and handle exceptions for robust RDF processing.

---

## 🚦 Performance

- Triple, Term, and IRI equality/hashCode are O(1)
- Graph queries (`findTriples`) are O(n) in the number of triples
- Designed for large-scale, high-performance RDF workloads

---

## 🗺️ API Overview

| Type           | Description                                   |
|----------------|-----------------------------------------------|
| `IriTerm`      | Represents an IRI (Internationalized Resource Identifier) |
| `LiteralTerm`  | Represents an RDF literal value               |
| `BlankNodeTerm`| Represents a blank node                       |
| `Triple`       | Atomic RDF statement (subject, predicate, object) |
| `RdfGraph`     | Collection of RDF triples                     |
| `RdfGraphCodec`     | Base class for decoding/encoding RDF Graphs in various formats |
| `RdfGraphDecoder`   | Base class for decoding RDF Graphs                   |
| `RdfGraphEncoder`   | Base class for encoding RDF Graphs                   |
| `turtle`       | Global convenience variable for Turtle codec |
| `jsonldGraph`       | Global convenience variable for JSON-LD codec |
| `ntriples`     | Global convenience variable for N-Triples codec |
| `rdf`          | Global RdfCore instance with standard codecs  |

---

## 📚 Standards & References

- [RDF 1.1 Concepts](https://www.w3.org/TR/rdf11-concepts/)
- [Turtle: Terse RDF Triple Language](https://www.w3.org/TR/turtle/)
- [JSON-LD 1.1](https://www.w3.org/TR/json-ld11/)
- [SHACL: Shapes Constraint Language](https://www.w3.org/TR/shacl/)

---

## 🧠 Object Mapping with rdf_mapper

For object-oriented access to RDF data, our companion project `rdf_mapper` allows seamless mapping between Dart objects and RDF. It works especially well with `rdf_vocabularies`, which provides constants for well-known vocabularies (like schema.org's `Person` available as the `SchemaPerson` class):

```dart
// Our simple dart class
class Person {
  final String id;
  final String givenName;

  Person({required this.id, this.givenName})
}

// Define a Mapper with our API for mapping between RDF and Objects
class PersonMapper implements IriNodeMapper<Person> {
  @override
  IriTerm? get typeIri => SchemaPerson.classIri;
  
  @override
  (IriTerm, List<Triple>) toRdfNode(Person value, SerializationContext context, {RdfSubject? parentSubject}) {

    // convert dart objects to triples using the fluent builder API
    return context.nodeBuilder(IriTerm(value.id))
      .literal(SchemaPerson.givenName, value.givenName)
      .build();
  }
  
  @override
  Person fromRdfNode(IriTerm term, DeserializationContext context) {
    final reader = context.reader(term);
    
    return Person(
      id: term.iri,
      name: reader.require<String>(SchemaPerson.givenName),
    );
  }
}

// Register our Mapper and create the rdfMapper facade
final rdfMapper = RdfMapper.withMappers((registry) {
  registry.registerMapper<Person>(PersonMapper());
});

// Create RDF representation from Dart objects
final person = Person(id: "https://example.com/person/234234", givenName: "John");
final turtle = rdfMapper.encode(person);

// Create JSON-LD representation
final jsonLd = rdfMapper.encode(person, contentType: 'application/ld+json');

// Access the underlying RDF graph
final graph = rdfMapper.graph.encode(person);
```

## 🛣️ Roadmap / Next Steps

- RDF 1.1: Datasets with Named Graphs 
- Improve jsonld decoder/encoder (full RdfDataset support, better support for base uri, include realworld tests for e.g. foaf.jsonld)
- RDF 1.2: Rdf-Star
- SHACL and schema validation
- Performance optimizations for large graphs
- Optimize streaming decoding and encoding

---

## 🤝 Contributing

Contributions, bug reports, and feature requests are welcome!

- Fork the repo and submit a PR
- See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines
- Join the discussion in [GitHub Issues](https://github.com/kkalass/rdf_core/issues)

---

## 🤖 AI Policy

This project is proudly human-led and human-controlled, with all key decisions, design, and code reviews made by people. At the same time, it stands on the shoulders of LLM giants: generative AI tools are used throughout the development process to accelerate iteration, inspire new ideas, and improve documentation quality. We believe that combining human expertise with the best of AI leads to higher-quality, more innovative open source software.

---

© 2025 Klas Kalaß. Licensed under the MIT License.
