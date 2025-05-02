// Example demonstrating the use of TurtleParsingFlags for handling non-standard Turtle documents
// This example showcases different parsing flags to make the Turtle parser more permissive

import 'package:rdf_core/rdf_core.dart';
import 'package:rdf_core/src/turtle/turtle_format.dart';
import 'package:rdf_core/src/turtle/turtle_tokenizer.dart';

void main() {
  print('RDF Core - Non-Standard Turtle Parsing Example');
  print('==============================================\n');

  // -------------------------------
  // 1. Default strict parsing
  // -------------------------------
  print('1. Default strict parsing behavior:');

  // This document has multiple syntax errors that would fail with strict parsing:
  // - Missing dot after prefix declaration
  // - Digit in local name (123)
  // - Missing final dot in the last triple
  final nonStandardTurtle = '''
@base <http://my.example.org/> .
@prefix ex: <http://example.org/> 
ex:resource123 a Type .
ex:anotherResource ex:hasValue "test"
''';

  print('Input document with non-standard syntax:');
  print('----------------------------------------');
  print(nonStandardTurtle);
  print('----------------------------------------\n');

  try {
    final strictRdf = RdfCore.withStandardFormats();
    // ignore: unused_local_variable
    final strictGraph = strictRdf.parse(
      nonStandardTurtle,
      contentType: 'text/turtle',
    );
    print('Document parsed successfully with strict parsing (unexpected!)');
  } catch (e) {
    print('Error with strict parsing (expected): $e\n');
  }

  // -------------------------------
  // 2. Configuring individual flags
  // -------------------------------
  print('2. Using specific TurtleParsingFlags:\n');

  // Create a custom TurtleFormat with specific parsing flags
  final customFormat = TurtleFormat(
    parsingFlags: {
      TurtleParsingFlag.allowIdentifiersWithoutColon,
      TurtleParsingFlag.allowMissingFinalDot,
      TurtleParsingFlag.allowMissingDotAfterPrefix,
    },
  );

  // Create an RDF Core instance with the custom format
  final customRdf = RdfCore.withFormats(formats: [customFormat]);

  try {
    final permissiveGraph = customRdf.parse(
      nonStandardTurtle,
      contentType: 'text/turtle',
    );
    print('Success! Document parsed with custom flags.');
    print('Parsed triples:');
    for (final triple in permissiveGraph.triples) {
      print('  ${triple.subject} ${triple.predicate} ${triple.object}');
    }
    print('');
  } catch (e) {
    print('Error with custom parsing flags (unexpected): $e\n');
  }

  // -------------------------------
  // 3. Using all permissive flags
  // -------------------------------
  print('3. Using all permissive flags for maximum compatibility:\n');

  // Create a format with all permissive flags
  final maxPermissiveFormat = TurtleFormat(
    parsingFlags: {
      TurtleParsingFlag.allowDigitInLocalName, // Allow numbers in local names
      TurtleParsingFlag
          .allowMissingDotAfterPrefix, // Allow prefix without trailing dot
      TurtleParsingFlag
          .autoAddCommonPrefixes, // Auto-add commonly used prefixes
      TurtleParsingFlag
          .allowPrefixWithoutAtSign, // Allow prefix without @ symbol
      TurtleParsingFlag
          .allowMissingFinalDot, // Allow missing dot in last triple
      TurtleParsingFlag
          .allowIdentifiersWithoutColon, // Allow bare identifiers without colon
    },
  );

  final maxPermissiveRdf = RdfCore.withFormats(formats: [maxPermissiveFormat]);

  // Even more problematic document with multiple syntax issues
  final veryNonStandardTurtle = '''
prefix ex: <http://example.org/> 
ex:resource123 a Type .
anotherResource ex:hasValue "test"
''';

  print('Input document with severe syntax issues:');
  print('----------------------------------------');
  print(veryNonStandardTurtle);
  print('----------------------------------------\n');

  try {
    final permissiveGraph = maxPermissiveRdf.parse(
      veryNonStandardTurtle,
      contentType: 'text/turtle',
      documentUrl: 'http://example.org/test',
    );
    print('Success! Document parsed with all permissive flags.');
    print('Parsed triples:');
    for (final triple in permissiveGraph.triples) {
      print('  ${triple.subject} ${triple.predicate} ${triple.object}');
    }
    print('');
  } catch (e) {
    print('Error with max permissive parsing (unexpected): $e\n');
  }

  // -------------------------------
  // 4. Real-world example: handling Wikidata exports
  // -------------------------------
  print('4. Real-world example - Handling Wikidata Turtle exports:\n');

  // Wikidata exports sometimes contain digits in local names (e.g., Q42)
  final wikidataExample = '''
@prefix wd: <http://www.wikidata.org/entity/> .
@prefix wdt: <http://www.wikidata.org/prop/direct/> .
@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .

wd:Q42 rdfs:label "Douglas Adams"@en ;
       wdt:P31 wd:Q5 ;  # instance of human
       wdt:P569 "1952-03-11T00:00:00Z"^^<http://www.w3.org/2001/XMLSchema#dateTime> .
''';

  final wikidataFormat = TurtleFormat(
    parsingFlags: {
      TurtleParsingFlag
          .allowDigitInLocalName, // Required for Wikidata's Q42, P31, etc.
    },
  );

  final wikidataRdf = RdfCore.withFormats(formats: [wikidataFormat]);

  try {
    final wikidataGraph = wikidataRdf.parse(
      wikidataExample,
      contentType: 'text/turtle',
    );
    print('Success! Wikidata document parsed correctly.');
    print('Number of triples: ${wikidataGraph.triples.length}');

    // Find all statements about Douglas Adams (Q42)
    final douglasAdams = IriTerm('http://www.wikidata.org/entity/Q42');
    final aboutDouglas = wikidataGraph.findTriples(subject: douglasAdams);

    print('\nStatements about Douglas Adams:');
    for (final triple in aboutDouglas) {
      print('  ${triple.predicate} ${triple.object}');
    }
  } catch (e) {
    print('Error parsing Wikidata example: $e');
  }
}
