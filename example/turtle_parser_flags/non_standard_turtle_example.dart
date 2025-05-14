// Example demonstrating the use of TurtleParsingFlags for handling non-standard Turtle documents
// This example shows how to handle Turtle documents with syntax issues using different approaches:
// 1. Using global convenience variables with options
// 2. Creating custom configured RdfCore instances
// 3. Working directly with codecs

import 'package:rdf_core/rdf_core.dart';

void main() {
  print('RDF Core - Non-Standard Turtle Parsing Example');
  print('==============================================\n');

  // Sample non-standard Turtle document with syntax issues:
  // - Missing dot after prefix declaration
  // - Digit in local name (resource123)
  // - Missing final dot in the last triple
  // - Type identifier without prefix
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

  // ---------------------------------------------
  // 1. Failing example with standard parsing
  // ---------------------------------------------
  print('1. Failing example with standard parsing:');
  print('----------------------------------------\n');

  try {
    // The 'rdf' global variable is equivalent to RdfCore.withStandardCodecs()
    // It uses strict parsing by default
    final graph = rdf.decode(nonStandardTurtle, contentType: 'text/turtle');
    print('Document parsed successfully with strict parsing (unexpected!)');
    print('Number of triples: ${graph.triples.length}\n');
  } catch (e) {
    print(
      'Error with strict parsing (expected): ${e.toString().split('\n')[0]}\n',
    );
  }

  // ---------------------------------------------
  // 2. Fix by providing options to rdf.decode
  // ---------------------------------------------
  print('2. Fixing with options provided to rdf.decode:');
  print('--------------------------------------------\n');

  print(
    'We can fix this by providing TurtleDecoderOptions directly to rdf.decode():\n',
  );

  try {
    // Using the global 'rdf' variable but with custom options
    final graph = rdf.decode(
      nonStandardTurtle,
      contentType: 'text/turtle',
      options: TurtleDecoderOptions(
        parsingFlags: {
          TurtleParsingFlag
              .allowMissingDotAfterPrefix, // For prefix without dot
          TurtleParsingFlag.allowDigitInLocalName, // For "resource123"
          TurtleParsingFlag.allowMissingFinalDot, // For missing final dot
          TurtleParsingFlag
              .allowIdentifiersWithoutColon, // For "Type" without prefix
        },
      ),
    );

    print('Success! Document parsed with custom flags.');
    print('Number of triples: ${graph.triples.length}');
    print('Parsed triples:');
    for (final triple in graph.triples) {
      print('  ${triple.subject} ${triple.predicate} ${triple.object}');
    }
    print('');
  } catch (e) {
    print('Error parsing with custom options: $e\n');
  }

  // ---------------------------------------------
  // 3. Custom configured RdfCore instance
  // ---------------------------------------------
  print('3. Using a custom configured RdfCore instance:');
  print('-------------------------------------------\n');

  print('Instead of providing options on each decode() call, we can create');
  print('a custom configured RdfCore instance with the desired options:\n');

  // Create a custom TurtleCodec with specific parsing flags
  final customTurtleCodec = TurtleCodec(
    decoderOptions: TurtleDecoderOptions(
      parsingFlags: {
        TurtleParsingFlag.allowMissingDotAfterPrefix,
        TurtleParsingFlag.allowDigitInLocalName,
        TurtleParsingFlag.allowMissingFinalDot,
        TurtleParsingFlag.allowIdentifiersWithoutColon,
      },
    ),
  );

  // Create a custom RdfCore instance with our configured codec
  final customRdf = RdfCore.withCodecs(codecs: [customTurtleCodec]);

  try {
    // Now we can use this custom RdfCore instance without specifying options each time
    final graph = customRdf.decode(
      nonStandardTurtle,
      contentType: 'text/turtle', // This will use our custom codec
    );

    print('Success! Document parsed with custom RdfCore instance.');
    print('Number of triples: ${graph.triples.length}\n');
  } catch (e) {
    print('Error with custom RdfCore: $e\n');
  }

  // ---------------------------------------------
  // 4. Working directly with codecs
  // ---------------------------------------------
  print('4. Working directly with codecs:');
  print('-----------------------------\n');

  print('The global variable "turtle" provides a convenience TurtleCodec');
  print('(similar to how "json" works in dart:convert):\n');

  try {
    // The 'turtle' global variable is equivalent to new TurtleCodec()
    // We can configure it with options using withOptions()
    final configuredTurtle = turtle.withOptions(
      decoder: TurtleDecoderOptions(
        parsingFlags: {
          TurtleParsingFlag.allowMissingDotAfterPrefix,
          TurtleParsingFlag.allowDigitInLocalName,
          TurtleParsingFlag.allowMissingFinalDot,
          TurtleParsingFlag.allowIdentifiersWithoutColon,
        },
      ),
    );

    // Now we can use the configured codec directly
    final graph = configuredTurtle.decode(nonStandardTurtle);

    print('Success using configured turtle codec.');
    print('Number of triples: ${graph.triples.length}\n');
  } catch (e) {
    print('Error using turtle codec: $e\n');
  }

  // Alternatively, we can access the codec through the RdfCore instance
  print('Alternatively, we can get the codec from an RdfCore instance:');
  try {
    // Get the appropriate codec from the RdfCore instance and configure it
    final configuredCodec = rdf.codec(
      contentType: 'text/turtle',
      decoderOptions: TurtleDecoderOptions(
        parsingFlags: {
          TurtleParsingFlag.allowMissingDotAfterPrefix,
          TurtleParsingFlag.allowDigitInLocalName,
          TurtleParsingFlag.allowMissingFinalDot,
          TurtleParsingFlag.allowIdentifiersWithoutColon,
        },
      ),
    );

    // Use the configured codec directly
    final graph = configuredCodec.decode(nonStandardTurtle);

    print('Success using codec from rdf.codec().');
    print('Number of triples: ${graph.triples.length}\n');
  } catch (e) {
    print('Error using rdf.codec(): $e\n');
  }

  // ---------------------------------------------
  // 5. Summary of approaches
  // ---------------------------------------------
  print('5. Summary of approaches:');
  print('----------------------\n');

  print('Global convenience variables:');
  print('- rdf: Equivalent to RdfCore.withStandardCodecs()');
  print('- turtle: Equivalent to new TurtleCodec()');
  print('');

  print('Options can be provided in different ways:');
  print('1. rdf.decode(data, options: TurtleDecoderOptions(...))');
  print('   - One-time use of options for a single decode call');
  print('   - Useful for quick, one-off parsing with special requirements');
  print('');
  print('2. customRdf = RdfCore.withCodecs([customCodec])');
  print('   customRdf.decode(data)');
  print('   - Create a custom RdfCore instance with pre-configured codecs');
  print('   - Useful when you need the same configuration for multiple calls');
  print('');
  print('3. configuredTurtle = turtle.withOptions(...)');
  print('   configuredTurtle.decode(data)');
  print('   - Configure a codec directly');
  print('   - Useful when working specifically with one format');
  print('');
  print('4. configuredCodec = rdf.codec(contentType, decoderOptions: ...)');
  print('   configuredCodec.decode(data)');
  print('   - Get and configure a codec from an RdfCore instance');
  print(
    '   - Combines the flexibility of approach 1 with the reusability of approach 3',
  );
}
