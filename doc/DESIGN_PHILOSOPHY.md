# RDF Core - Design Philosophy and Use Cases

## Why We Created RDF Core

RDF Core was designed with specific goals in mind to address challenges in building robust, maintainable RDF applications in Dart. This document outlines our design philosophy and helps you understand when RDF Core might be the right choice for your project.

## Design Philosophy

The RDF Core library follows several key design principles:

### Type Safety and Robustness

- **Strong typing**: All RDF components (IRIs, literals, blank nodes, triples) are strongly typed
- **Compile-time safety**: Many potential errors are caught at compile time rather than runtime
- **Clear contracts**: Interfaces define clear expectations for all components

### Modularity and Extensibility

- **Separation of concerns**: Data model is separate from serialization formats
- **Plugin architecture**: Easy to add new serialization formats or processing modules
- **Dependency injection**: Components can be easily replaced with custom implementations

### Simplicity and Elegance

- **Progressive disclosure**: Simple for basic tasks, powerful for complex needs
- **Minimal boilerplate**: Common operations expressed concisely in one line
- **Smart defaults**: Sensible configurations that work out of the box
- **Focus on the essentials**: Core abstractions map directly to RDF concepts

### Developer Experience

- **Convenience globals**: Easy access to common functionality through global variables
- **Expressive API**: Code reads naturally and expresses intent clearly
- **Comprehensive documentation**: Examples and explanations for all features

## When to Use RDF Core

RDF Core is well-suited for projects that:

1. Require **type safety and robustness**
2. Need to **work with multiple RDF formats**
3. Are maintained by **teams of developers**
4. Implement **complex RDF processing pipelines**
5. Need to be **maintained over long periods**
6. Benefit from **advanced features** like custom codecs and plugins

## RDF Core is Straightforward to Use

Despite its comprehensive feature set, RDF Core was designed for ease of use:

```dart
import 'package:rdf_core/rdf_core.dart';

// Parse Turtle data with just one line
final graph = turtle.decode('@prefix ex: <http://example.org/> . ex:s ex:p "o" .');

// Search for data
final results = graph.findTriples(predicate: const IriTerm('http://example.org/p'));

// Export as JSON-LD
final jsonld = jsonldGraph.encode(graph);
```

## Conclusion

RDF Core provides a solid foundation for building RDF applications in Dart, balancing power and flexibility with developer-friendly APIs. The global convenience variables (`turtle`, `jsonldGraph`, `ntriples`, `rdf`) make common operations simple and intuitive, while the underlying architecture supports more complex use cases as needed.

## More Information

For more detailed examples and advanced usage, check out:

- [Getting Started](GETTING_STARTED.md) - Helps you getting started 
- [Cookbook](COOKBOOK.md) - Common patterns and solutions
- [API Documentation](https://kkalass.github.io/rdf_core/api/rdf/index.html) - Complete API reference
