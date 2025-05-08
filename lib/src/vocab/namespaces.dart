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

import 'dart:math';

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

  // Other well-known vocabularies
  "geo": "http://www.w3.org/2003/01/geo/wgs84_pos#",
  "contact": "http://www.w3.org/2000/10/swap/pim/contact#",
  "time": "http://www.w3.org/2006/time#",
  "vs": "http://www.w3.org/2003/06/sw-vocab-status/ns#",
  "dcmitype": "http://purl.org/dc/dcmitype/",
  "void": "http://rdfs.org/ns/void#",
  "prov": "http://www.w3.org/ns/prov#",
  "gr": "http://purl.org/goodrelations/v1#",
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
class RdfNamespaceMappings {
  final Map<String, String> _mappings;

  /// Creates a new RdfNamespaceMappings instance with standard mappings.
  ///
  /// The standard mappings include common RDF vocabularies like RDF, RDFS, OWL, etc.
  const RdfNamespaceMappings() : _mappings = _rdfNamespaceMappings;

  K? _getKeyByValue<K, V>(Map<K, V> map, V value) {
    for (final entry in map.entries) {
      if (entry.value == value) {
        return entry.key;
      }
    }
    return null;
  }

  /// Creates a new RdfNamespaceMappings instance with custom mappings.
  ///
  /// Custom mappings take precedence over standard mappings when there are conflicts.
  ///
  /// @param customMappings The custom mappings to add to the standard ones
  /// @param useDefaults Whether to include standard mappings (default: true)
  RdfNamespaceMappings.custom(
    Map<String, String> customMappings, {
    useDefaults = true,
  }) : _mappings =
           useDefaults
               ? {..._rdfNamespaceMappings, ...customMappings}
               : customMappings;

  /// Returns the number of mappings.
  get length => _mappings.length;

  /// Operator for retrieving a namespace URI by its prefix.
  ///
  /// @param key The prefix to look up
  /// @return The namespace URI for the prefix, or null if not found
  String? operator [](Object? key) => _mappings[key];

  /// Returns the Prefix for a given namespace URI.
  String? getPrefix(
    String namespace, {
    Map<String, String> customMappings = const {},
  }) {
    // Check if the namespace is already mapped
    return _getKeyByValue(customMappings, namespace) ??
        _getKeyByValue(_mappings, namespace);
  }

  /// Returns the Prefix for a given namespace URI, generating a new one if not found.
  /// Note that this will not change the immutable RdfNamespaceMappings instance.
  /// Instead, it will return a new prefix that can be used for custom mappings.
  (String prefix, bool generated) getOrGeneratePrefix(
    String namespace, {
    Map<String, String> customMappings = const {},
  }) {
    String? candidate =
        _getKeyByValue(customMappings, namespace) ??
        _getKeyByValue(_mappings, namespace);
    if (candidate != null) {
      return (candidate, false);
    }

    // Generate a meaningful prefix from domain when possible
    String? prefix = _tryGeneratePrefixFromUrl(namespace);

    // Ensure prefix is not already used
    if (prefix != null &&
        !customMappings.containsKey(prefix) &&
        !_mappings.containsKey(prefix)) {
      return (prefix, true);
    }

    // Fall back to numbered prefixes
    final computedPrefix = prefix ?? 'ns';
    int prefixNum = 1;
    do {
      prefix = '$computedPrefix$prefixNum';
      prefixNum++;
    } while (customMappings.containsKey(prefix) &&
        !_mappings.containsKey(prefix));

    return (prefix, true);
  }

  /// Attempts to generate a meaningful prefix from a namespace URI
  ///
  /// Uses pattern-based heuristics to extract the most meaningful part of a URI.
  /// The algorithm prioritizes semantic components over technical ones, avoiding
  /// version numbers, dates, and common generic terms when more specific elements exist.
  String? _tryGeneratePrefixFromUrl(String namespace) {
    try {
      // Handle URNs specifically
      if (namespace.startsWith('urn:')) {
        final parts = namespace.substring(4).split(':');
        if (parts.isNotEmpty) {
          final candidate = parts[0].toLowerCase();
          if (_isValidPrefix(candidate)) return candidate;
        }
        return null;
      }

      // Extract domain and path from HTTP/HTTPS URI
      final uriRegex = RegExp(r'^https?://(?:www\.)?([^/]+)(.*)');
      final match = uriRegex.firstMatch(namespace);
      if (match == null || match.groupCount < 2) return null;

      final domain = match.group(1);
      final path = match.group(2) ?? '';
      if (domain == null || domain.isEmpty) return null;

      // For common domain.tld formats, extract meaningful components
      final domainPrefix = _extractDomainPrefix(domain);

      // Skip the prefix generation from domain if empty string or null
      if (domainPrefix == null || domainPrefix.isEmpty) {
        // Empty or invalid domain prefix - fall back to path analysis only
      } else if (path.isEmpty || path == '/') {
        // If there's no path, just use the domain prefix
        return domainPrefix;
      }

      // Process path segments for meaningful parts
      return _extractPathPrefix(path) ?? domainPrefix;
    } catch (_) {
      return null;
    }
  }

  /// Extracts a meaningful prefix from the domain part of a URL
  String? _extractDomainPrefix(String domain) {
    final domainParts = domain.split('.');
    if (domainParts.isEmpty) return null;

    final firstPart = domainParts[0].toLowerCase();

    // For domains with hyphens, consider using initials (e.g., "data-gov" -> "dg")
    if (firstPart.contains('-')) {
      final parts = firstPart.split('-');
      if (parts.length >= 2 && parts.every((p) => p.isNotEmpty)) {
        final initials = parts.map((p) => p[0]).join('');
        if (_isValidPrefix(initials)) return initials;
      }
    }

    // For other domains, use short prefix or abbreviation from first domain part
    if (firstPart.length > 3) {
      // Use first two characters as a prefix for longer domains
      final shortPrefix = firstPart.substring(0, 2);
      if (_isValidPrefix(shortPrefix)) return shortPrefix;
    } else {
      // Use the entire first part for shorter domains
      if (_isValidPrefix(firstPart)) return firstPart;
    }

    return null;
  }

  /// Extracts a meaningful prefix from the path part of a URL
  String? _extractPathPrefix(String path) {
    // Split the path into components, removing empty parts
    final components =
        path
            .split('/')
            .where((p) => p.isNotEmpty)
            .map(
              (p) => p.split('#')[0].split('?')[0],
            ) // Remove fragment and query
            .where((p) => p.isNotEmpty)
            .toList();

    if (components.isEmpty) return null;

    // List of common generic terms that would make poor prefixes on their own
    final genericTerms = {
      'api',
      'ns',
      'vocab',
      'schema',
      'ontology',
      'vocabulary',
      'terms',
      'v1',
      'v2',
      'v3',
      'core',
      'standard',
      'spec',
      'definition',
      'namespace',
      'resource',
    };

    // List of patterns indicating version numbers or dates
    final versionOrDatePattern = RegExp(
      r'^(v\d+(\.\d+)*|\d+\.\d+|\d{4}(-\d{2}(-\d{2})?)?|latest)$',
    );

    // Special case for w3.org paths with 'ns' segment
    final nsIndex = components.indexOf('ns');
    if (nsIndex >= 0 && nsIndex < components.length - 1) {
      final candidate = components[nsIndex + 1];
      if (_isGoodPrefix(genericTerms, candidate, versionOrDatePattern)) {
        return candidate;
      }
    }

    // Try to find the most meaningful segment
    // Start from the end of the path, but exclude fragments like '#'
    for (int i = components.length - 1; i >= 0; i--) {
      var component = components[i];

      // Skip components that look like fragment identifiers (those containing '#')
      if (component.contains('#')) {
        component = component.split('#')[0];
        if (component.isEmpty) continue;
      }

      // Skip URLs or fragments that end with generic delimiters
      if (component.endsWith('/') || component.endsWith('#')) {
        component = component.substring(0, component.length - 1);
      }

      // Skip version numbers and dates
      if (versionOrDatePattern.hasMatch(component)) continue;

      // Skip generic terms if not the only option
      if (genericTerms.contains(component.toLowerCase()) &&
          (components.length > 1 || i > 0)) {
        continue;
      }

      // If we've reached the first component and haven't found anything better
      if (i == 0 && components.length > 1) {
        // Try using the first segment if it's not a generic term
        if (_isGoodPrefix(genericTerms, component, versionOrDatePattern)) {
          return component;
        }

        // If the second segment is not a generic term or version, consider it
        if (components.length > 1 &&
            _isGoodPrefix(genericTerms, components[1], versionOrDatePattern)) {
          return components[1];
        }
      }

      // Found a good candidate
      if (_isGoodPrefix(genericTerms, component, versionOrDatePattern)) {
        return component;
      }
    }

    // If no good prefix found, return null - we will use the domain then
    return null;
  }

  bool _isGoodPrefix(
    Set<String> genericTerms,
    String component,
    RegExp versionOrDatePattern,
  ) {
    return !genericTerms.contains(component.toLowerCase()) &&
        !versionOrDatePattern.hasMatch(component) &&
        _isValidPrefix(component);
  }

  bool _isValidPrefix(String name) {
    if (name.isEmpty) {
      return false;
    }

    // First character must be a letter or underscore
    final firstChar = name.codeUnitAt(0);
    if (!((firstChar >= 65 && firstChar <= 90) || // A-Z
        (firstChar >= 97 && firstChar <= 122) || // a-z
        firstChar == 95)) {
      // _
      return false;
    }

    // Subsequent characters can also include digits and some symbols
    for (int i = 1; i < name.length; i++) {
      final char = name.codeUnitAt(i);
      if (!((char >= 65 && char <= 90) || // A-Z
          (char >= 97 && char <= 122) || // a-z
          (char >= 48 && char <= 57) || // 0-9
          char == 95 || // _
          char == 45 || // -
          char == 46)) {
        // .
        return false;
      }
    }

    return true;
  }

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
