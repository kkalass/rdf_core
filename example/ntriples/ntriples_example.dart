// Copyright (c) 2025, Klas Kalaß
// All rights reserved. Use of this source code is governed by a
// MIT-style license that can be found in the LICENSE file.

/// Example showing how to use N-Triples parsing and serialization
///
/// This example demonstrates:
/// - Parsing N-Triples data
/// - Serializing RDF graphs to N-Triples
/// - Converting between N-Triples and Turtle formats
/// - Format auto-detection
///
/// N-Triples is a line-based, plain-text format for RDF data, where each line
/// represents a single triple, and everything is written out explicitly without
/// abbreviations or prefixes.
///
/// See the W3C specification at: https://www.w3.org/TR/n-triples/

import 'package:rdf_core/rdf_core.dart';
import 'package:rdf_core/src/ntriples/ntriples_parser.dart';
import 'package:rdf_core/src/ntriples/ntriples_serializer.dart';

void main() {
  print('N-Triples Format Example\n');

  // Example N-Triples document
  final ntriplesData = '''
<http://example.org/alice> <http://xmlns.com/foaf/0.1/name> "Alice Smith" .
<http://example.org/alice> <http://xmlns.com/foaf/0.1/knows> <http://example.org/bob> .
<http://example.org/alice> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://xmlns.com/foaf/0.1/Person> .
<http://example.org/bob> <http://xmlns.com/foaf/0.1/name> "Bob Jones" .
<http://example.org/bob> <http://xmlns.com/foaf/0.1/knows> <http://example.org/alice> .
<http://example.org/bob> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://xmlns.com/foaf/0.1/Person> .
''';

  print('Original N-Triples data:');
  print(ntriplesData);
  print('------------------------');

  // Create RDF Core instance with standard formats (includes N-Triples)
  final rdf = RdfCore.withStandardFormats();

  // Parse N-Triples using explicit content type
  print('\nParsing with explicit content type: "application/n-triples"');
  final graph = rdf.parse(ntriplesData, contentType: 'application/n-triples');

  // Examine the parsed graph
  print('\nParsed graph contains ${graph.triples.length} triples:');
  for (final triple in graph.triples) {
    print('  ${triple.subject} ${triple.predicate} ${triple.object}');
  }

  // N-Triples auto-detection example
  print('\nParsing with format auto-detection:');
  final autoDetectedGraph = rdf.parse(ntriplesData);
  print(
    'Auto-detected graph contains ${autoDetectedGraph.triples.length} triples',
  );

  // Serialize back to N-Triples
  print('\nSerializing back to N-Triples:');
  final serializedNTriples = rdf.serialize(
    graph,
    contentType: 'application/n-triples',
  );
  print(serializedNTriples);

  // Convert between formats - serialize to Turtle
  print('\nConverting to Turtle format:');
  final turtle = rdf.serialize(
    graph,
    contentType: 'text/turtle',
    customPrefixes: {
      'ex': 'http://example.org/',
      'foaf': 'http://xmlns.com/foaf/0.1/',
    },
  );
  print(turtle);

  // Working with different types of terms in N-Triples
  print('\nDifferent types of terms in N-Triples:');

  // Example with literals having language tags and datatypes
  final advancedNTriples = '''
<http://example.org/resource> <http://example.org/property> "Simple literal" .
<http://example.org/resource> <http://example.org/property> "English text"@en .
<http://example.org/resource> <http://example.org/property> "42"^^<http://www.w3.org/2001/XMLSchema#integer> .
<http://example.org/resource> <http://example.org/property> "3.14"^^<http://www.w3.org/2001/XMLSchema#decimal> .
<http://example.org/resource> <http://example.org/property> "true"^^<http://www.w3.org/2001/XMLSchema#boolean> .
<http://example.org/resource> <http://example.org/property> _:blank1 .
_:blank1 <http://example.org/property> "Value from blank node" .
''';

  final advancedGraph = rdf.parse(
    advancedNTriples,
    contentType: 'application/n-triples',
  );

  print('Parsed advanced N-Triples graph:');
  for (final triple in advancedGraph.triples) {
    print('  ${triple.subject} ${triple.predicate} ${triple.object}');
  }

  // Direct use of NTriplesParser and NTriplesSerializer
  print('\nDirect use of NTriplesParser and NTriplesSerializer:');

  final directParser = NTriplesParser();
  final directGraph = directParser.parse(ntriplesData);

  final directSerializer = NTriplesSerializer();
  // ignore: unused_local_variable
  final directOutput = directSerializer.write(directGraph);

  print(
    'Direct parsing and serialization produced ${directGraph.triples.length} triples',
  );

  // Create and serialize a new graph programmatically
  print('\nCreating and serializing a new graph:');

  final customGraph = RdfGraph(
    triples: [
      Triple(
        IriTerm('http://example.org/subject'),
        IriTerm('http://example.org/predicate'),
        LiteralTerm.string('String value'),
      ),
      Triple(
        IriTerm('http://example.org/subject'),
        IriTerm('http://example.org/predicate'),
        LiteralTerm.integer(42),
      ),
      Triple(
        IriTerm('http://example.org/subject'),
        IriTerm('http://example.org/predicate'),
        LiteralTerm.withLanguage('Text with language', 'en'),
      ),
      Triple(
        BlankNodeTerm(),
        IriTerm('http://example.org/predicate'),
        IriTerm('http://example.org/object'),
      ),
    ],
  );

  final customOutput = rdf.serialize(
    customGraph,
    contentType: 'application/n-triples',
  );

  print(customOutput);

  print('\nExample completed');
}
