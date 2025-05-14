// Example demonstrating the use of Schema.org PostalAddress in RDF
//
// This example shows how to create and query postal address data
// using the Schema.org vocabulary in RDF Core.

import 'package:rdf_core/rdf_core.dart';

void main() {
  // Create a graph with an organization that has a postal address
  final graph = createOrganizationWithAddress();

  // Print the graph as triples
  print('Organization with Postal Address:');
  printGraph(graph);

  // Serialize to Turtle format for a nicer view
  final turtleStr = turtle // or use: rdf.codec('text/turtle')
      .encode(graph);

  print('\nTurtle serialization:\n\n```turtle\n$turtleStr\n```');

  // Extract and print the address information
  final organization = IriTerm('http://example.org/acme');
  printAddressInfo(graph, organization);

  // Add a second address (branch office)
  final updatedGraph = addBranchOffice(graph);

  // Print the updated graph
  print('\nUpdated Graph with Branch Office:');
  final updatedTurtle = turtle // or use: rdf.codec('text/turtle')
      .encode(updatedGraph);

  print('\n```turtle\n$updatedTurtle\n```');
}

/// Creates a graph with an organization and its postal address
RdfGraph createOrganizationWithAddress() {
  // Define the subject for our organization
  final organization = IriTerm('http://example.org/acme');

  // Create a blank node for the postal address
  final address = BlankNodeTerm();

  // Create triples for the organization and its address
  final triples = [
    // Define the organization
    Triple(
      organization,
      IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#type'),
      IriTerm('https://schema.org/Organization'),
    ),
    Triple(
      organization,
      IriTerm('https://schema.org/name'),
      LiteralTerm.string('ACME Corporation'),
    ),
    Triple(
      organization,
      IriTerm('https://schema.org/url'),
      IriTerm('https://example.org'),
    ),
    Triple(
      organization,
      IriTerm('https://schema.org/legalName'),
      LiteralTerm.string('ACME Corporation GmbH'),
    ),

    // Link to address
    Triple(organization, IriTerm('https://schema.org/address'), address),

    // Define the address details
    Triple(
      address,
      IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#type'),
      IriTerm('https://schema.org/PostalAddress'),
    ),
    Triple(
      address,
      IriTerm('https://schema.org/streetAddress'),
      LiteralTerm.string('123 Main Street'),
    ),
    Triple(
      address,
      IriTerm('https://schema.org/addressLocality'),
      LiteralTerm.string('Berlin'),
    ),
    Triple(
      address,
      IriTerm('https://schema.org/postalCode'),
      LiteralTerm.string('10115'),
    ),
    Triple(
      address,
      IriTerm('https://schema.org/addressRegion'),
      LiteralTerm.string('Berlin'),
    ),
    Triple(
      address,
      IriTerm('https://schema.org/addressCountry'),
      LiteralTerm.string('DE'),
    ),
  ];

  return RdfGraph(triples: triples);
}

/// Prints all triples in the given graph
void printGraph(RdfGraph graph) {
  for (final triple in graph.triples) {
    print('  $triple');
  }
}

/// Extracts and prints the address information for an entity
void printAddressInfo(RdfGraph graph, IriTerm entity) {
  print('\nAddress Information for ${entity.iri}:');

  // Find address nodes linked to this entity
  final addressTriples = graph.triples.where(
    (triple) =>
        triple.subject == entity &&
        triple.predicate == IriTerm('https://schema.org/address'),
  );

  for (final addressTriple in addressTriples) {
    final addressNode = addressTriple.object;
    print('  Address:');

    // Find address properties
    final addressProperties = [
      IriTerm('https://schema.org/streetAddress'),
      IriTerm('https://schema.org/addressLocality'),
      IriTerm('https://schema.org/addressRegion'),
      IriTerm('https://schema.org/postalCode'),
      IriTerm('https://schema.org/addressCountry'),
    ];

    for (final property in addressProperties) {
      final values =
          graph.triples
              .where((t) => t.subject == addressNode && t.predicate == property)
              .map((t) => t.object)
              .toList();

      if (values.isNotEmpty) {
        final propertyName = property.iri.split('/').last;
        print('    $propertyName: ${values.first}');
      }
    }
  }
}

/// Adds a branch office to the organization and returns a new graph
RdfGraph addBranchOffice(RdfGraph graph) {
  // Define the organization and new address
  final organization = IriTerm('http://example.org/acme');
  final branchAddress = BlankNodeTerm();

  // Create triples for the branch office
  final branchTriples = [
    Triple(organization, IriTerm('https://schema.org/address'), branchAddress),
    Triple(
      branchAddress,
      IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#type'),
      IriTerm('https://schema.org/PostalAddress'),
    ),
    Triple(
      branchAddress,
      IriTerm('https://schema.org/streetAddress'),
      LiteralTerm.string('456 Innovation Blvd'),
    ),
    Triple(
      branchAddress,
      IriTerm('https://schema.org/addressLocality'),
      LiteralTerm.string('Munich'),
    ),
    Triple(
      branchAddress,
      IriTerm('https://schema.org/postalCode'),
      LiteralTerm.string('80331'),
    ),
    Triple(
      branchAddress,
      IriTerm('https://schema.org/addressRegion'),
      LiteralTerm.string('Bavaria'),
    ),
    Triple(
      branchAddress,
      IriTerm('https://schema.org/addressCountry'),
      LiteralTerm.string('DE'),
    ),
    Triple(
      branchAddress,
      IriTerm('https://schema.org/name'),
      LiteralTerm.string('Branch Office'),
    ),
  ];

  // Add all branch office triples to the graph
  return RdfGraph(triples: [...graph.triples, ...branchTriples]);
}
