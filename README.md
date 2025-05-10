<div align="center">
  <img src="https://kkalass.github.io/rdf_core/logo.svg" alt="rdf_core logo" width="96" height="96"/>
</div>

# RDF Core

[![pub package](https://img.shields.io/pub/v/rdf_core.svg)](https://pub.dev/packages/rdf_core)
[![build](https://github.com/kkalass/rdf_core/actions/workflows/ci.yml/badge.svg)](https://github.com/kkalass/rdf_core/actions)
[![codecov](https://codecov.io/gh/kkalass/rdf_core/branch/main/graph/badge.svg)](https://codecov.io/gh/kkalass/rdf_core)
[![license](https://img.shields.io/github/license/kkalass/rdf_core.svg)](https://github.com/kkalass/rdf_core/blob/main/LICENSE)


[🌐 **Official Homepage**](https://kkalass.github.io/rdf_core/)

A type-safe, and extensible Dart library for representing and manipulating RDF data without any further dependencies.

---

## Core of a whole family of projects

If you are looking for more rdf-related functionality, have a look at our companion projects:

* parse and serialize rdf/xml format: [rdf_xml](https://github.com/kkalass/rdf_xml) 
* easy-to-use constants for many well-known vocabularies: [rdf_vocabularies](https://github.com/kkalass/rdf_vocabularies)
* generate your own easy-to-use constants for other vocabularies with a build_runner: [rdf_vocabulary_to_dart](https://github.com/kkalass/rdf_vocabulary_to_dart)
* map Dart Objects ↔️ RDF: [rdf_mapper](https://github.com/kkalass/rdf_mapper)

---

## ✨ Features

- **Type-safe RDF model:** IRIs, Literals, Triples, Graphs, and more
- **Serialization-agnostic:** Clean separation from Turtle/JSON-LD/N-Triples
- **Extensible & modular:** Build your own adapters, plugins, and integrations
- **Spec-compliant:** Follows [W3C RDF 1.1](https://www.w3.org/TR/rdf11-concepts/) and related standards

## 🚀 Quick Start

### Manual Graph Creation

```dart
import 'package:rdf_core/rdf_core.dart';

void main() {
  final subject = IriTerm('http://example.org/alice');
  final predicate = IriTerm('http://xmlns.com/foaf/0.1/name');
  final object = LiteralTerm.withLanguage('Alice', 'en');
  final triple = Triple(subject, predicate, object);
  final graph = RdfGraph(triples: [triple]);

  print(graph);
}
```

### Parsing and Serializing Turtle

```dart
import 'package:rdf_core/rdf_core.dart';

void main() {
  // Example: Parse a simple Turtle document
  final turtle = '''
    @prefix foaf: <http://xmlns.com/foaf/0.1/> .
    <http://example.org/alice> foaf:name "Alice"@en .
  ''';

  final rdf = RdfCore.withStandardFormats();
  final graph = rdf.parse(turtle, contentType: 'text/turtle');

  // Print parsed triples
  for (final triple in graph.triples) {
    print('${triple.subject} ${triple.predicate} ${triple.object}');
  }

  // Serialize the graph back to Turtle
  final serialized = rdf.serialize(graph, contentType: 'text/turtle');
  print('\nSerialized Turtle:\n$serialized');
}
```

### Parsing and Serializing N-Triples

```dart
import 'package:rdf_core/rdf_core.dart';

void main() {
  // Example: Parse a simple N-Triples document
  final ntriples = '''
    <http://example.org/alice> <http://xmlns.com/foaf/0.1/name> "Alice"@en .
    <http://example.org/alice> <http://xmlns.com/foaf/0.1/knows> <http://example.org/bob> .
  ''';

  final rdf = RdfCore.withStandardFormats();
  final graph = rdf.parse(ntriples, contentType: 'application/n-triples');

  // Print parsed triples
  for (final triple in graph.triples) {
    print('${triple.subject} ${triple.predicate} ${triple.object}');
  }

  // Serialize the graph back to N-Triples
  final serialized = rdf.serialize(graph, contentType: 'application/n-triples');
  print('\nSerialized N-Triples:\n$serialized');
}
```

### Parsing and Serializing JSON-LD

```dart
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

  final rdf = RdfCore.withStandardFormats();
  final graph = rdf.parse(jsonLd, contentType: 'application/ld+json');

  // Print parsed triples
  for (final triple in graph.triples) {
    print('${triple.subject} ${triple.predicate} ${triple.object}');
  }

  // Serialize the graph back to JSON-LD
  final serialized = rdf.serialize(graph, contentType: 'application/ld+json');
  print('\nSerialized JSON-LD:\n$serialized');
}
```

## 🧑‍💻 Advanced Usage

### Parsing and Serializing N-Triples

With the help of the separate package [rdf_xml](https://github.com/kkalass/rdf_xml) you can easily serialize/deserialize RDF/XML as well.

```bash
dart pub add rdf_xml
```

```dart
import 'package:rdf_core/rdf_core.dart';
import 'package:rdf_xml/rdf_xml.dart';

void main() {
  // Register the format with the registry
  final rdfCore = RdfCore.withStandardFormats();
  rdfCore.registerFormat(RdfXmlFormat());

  // use this instance now for "application/rdf+xml"
  // ...
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
final bnode = BlankNodeTerm();
final newGraph = graph.withTriple(Triple(bnode, predicate, object));
```

### Non-Standard Turtle Parsing

```dart
import 'package:rdf_core/rdf_core.dart';

// Configure a TurtleFormat with specific parsing flags
final turtleFormat = TurtleFormat(
  parsingFlags: {
    TurtleParsingFlag.allowDigitInLocalName,
    TurtleParsingFlag.allowMissingDotAfterPrefix,
    TurtleParsingFlag.autoAddCommonPrefixes,
  }
);

// Create an RDF Core instance with the custom format
final rdf = RdfCore.withFormats(formats: [turtleFormat]);

// Parse a document with non-standard Turtle syntax
final nonStandardTurtle = '''
  @prefix ex: <http://example.org/> // Missing dot after prefix
  ex:resource123 a ex:Type . // Digit in local name
''';

final graph = rdf.parse(nonStandardTurtle, contentType: 'text/turtle');
```

### Serialization/Parsing

```dart
final turtleSerializer = TurtleSerializer();
final turtle = turtleSerializer.write(graph);

final jsonLdParser = JsonLdParser(jsonLdSource);
final parsedGraph = jsonLdParser.parse();
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
| `RdfParser`    | Interface for parsing RDF from various formats |
| `RdfSerializer`| Interface for serializing RDF                 |

---

## 📚 Standards & References

- [RDF 1.1 Concepts](https://www.w3.org/TR/rdf11-concepts/)
- [Turtle: Terse RDF Triple Language](https://www.w3.org/TR/turtle/)
- [JSON-LD 1.1](https://www.w3.org/TR/json-ld11/)
- [SHACL: Shapes Constraint Language](https://www.w3.org/TR/shacl/)

---

## 🛣️ Roadmap / Next Steps

- Make use of dart:convert classes, change from Parser/Serializer notation to decoder/encoder
- Support base uri in jsonld and turtle serialization
- Improve jsonld parser/serializer (and include realworld tests for e.g. foaf.jsonld)
- Named Graphs (maybe as separate project)
- Rdf-Star
- SHACL and schema validation
- Performance optimizations for large graphs
- streaming parsing and serialization

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
