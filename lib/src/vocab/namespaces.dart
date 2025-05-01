/// RDF Namespace mappings
///
/// Defines standard mappings between RDF namespace prefixes and their corresponding URIs.
/// These mappings are commonly used in RDF serialization formats like Turtle and JSON-LD.
///
/// Example usage:
/// ```dart
/// import 'package:rdf_core/src/vocab/namespaces.dart';
///
/// // Get a namespace URI from a prefix
/// final rdfNamespace = rdfNamespaceMappings['rdf']; // http://www.w3.org/1999/02/22-rdf-syntax-ns#
///
/// // Use spread operator with namespace mappings
/// final extendedMappings = {
///   ...RdfNamespaceMappings().asMap(),
///   'custom': 'http://example.org/custom#'
/// };
/// ```
library rdf_namespaces;

import 'package:rdf_core/src/vocab/rdf.dart';
import 'package:rdf_core/src/vocab/xsd.dart';

/// Standard mappings between RDF namespace prefixes and their corresponding URIs.
///
/// This constant provides a predefined set of common RDF namespace prefix-to-URI mappings
/// used across RDF serialization formats. These mappings follow common conventions in the
/// semantic web community.
const Map<String, String> _rdfNamespaceMappings = {
  // Core RDF vocabularies
  Rdf.prefix: Rdf.namespace,
  'rdfs': 'http://www.w3.org/2000/01/rdf-schema#',
  'owl': 'http://www.w3.org/2002/07/owl#',
  Xsd.prefix: Xsd.namespace,

  // Common community vocabularies
  'schema': 'https://schema.org/',
  'foaf': 'http://xmlns.com/foaf/0.1/',
  'dc': 'http://purl.org/dc/elements/1.1/',
  'dcterms': 'http://purl.org/dc/terms/',
  'skos': 'http://www.w3.org/2004/02/skos/core#',
  'vcard': 'http://www.w3.org/2006/vcard/ns#',

  // Linked Data Platform and Solid related
  'ldp': 'http://www.w3.org/ns/ldp#',
  'solid': 'http://www.w3.org/ns/solid/terms#',
  'acl': 'http://www.w3.org/ns/auth/acl#',
};

/// A class that provides access to RDF namespace mappings with support for custom mappings.
///
/// This immutable class provides RDF namespace prefix-to-URI mappings for common RDF vocabularies.
/// It can be extended with custom mappings and supports the spread operator via the [asMap] method.
///
/// To use with the spread operator:
///
/// ```dart
/// final mappings = {
///   ...RdfNamespaceMappings().asMap(),
///   'custom': 'http://example.org/custom#'
/// };
/// ```
///
/// To create custom mappings:
///
/// ```dart
/// final customMappings = RdfNamespaceMappings.custom({
///   'ex': 'http://example.org/',
///   'custom': 'http://example.org/custom#'
/// });
///
/// // Access a namespace URI by prefix
/// final exUri = customMappings['ex']; // http://example.org/
/// ```
@deprecated
class RdfNamespaceMappings {
  final Map<String, String> _mappings;

  /// Creates a new RdfNamespaceMappings instance with standard mappings.
  ///
  /// The standard mappings include common RDF vocabularies like RDF, RDFS, OWL, etc.
  const RdfNamespaceMappings() : _mappings = _rdfNamespaceMappings;

  /// Creates a new RdfNamespaceMappings instance with custom mappings.
  ///
  /// Custom mappings take precedence over standard mappings when there are conflicts.
  ///
  /// @param customMappings The custom mappings to add to the standard ones
  RdfNamespaceMappings.custom(Map<String, String> customMappings)
    : _mappings = {..._rdfNamespaceMappings, ...customMappings};

  /// Returns the number of mappings.
  get length => _mappings.length;

  /// Operator for retrieving a namespace URI by its prefix.
  ///
  /// @param key The prefix to look up
  /// @return The namespace URI for the prefix, or null if not found
  String? operator [](Object? key) => _mappings[key];

  /// Creates an unmodifiable view of the underlying mappings.
  ///
  /// This method provides support for the spread operator by returning a Map that can be spread.
  ///
  /// ```dart
  /// final mappings = {
  ///   ...RdfNamespaceMappings().asMap(),
  ///   'custom': 'http://example.org/custom#'
  /// };
  /// ```
  ///
  /// @return An unmodifiable map of the prefix-to-URI mappings
  Map<String, String> asMap() => Map.unmodifiable(_mappings);

  /// Checks if the mappings contain a specific prefix.
  ///
  /// @param prefix The prefix to check for
  /// @return true if the prefix exists, false otherwise
  bool containsKey(String prefix) => _mappings.containsKey(prefix);
}
