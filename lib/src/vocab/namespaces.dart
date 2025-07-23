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

// Static compiled regex patterns for performance
final _digitStartRegex = RegExp(r'^\d');
final _uriRegex = RegExp(r'^https?://(?:www\.)?([^/]+)(.*)');
final _versionOrDateRegex = RegExp(
  r'^(v\d+(\.\d+)*|\d+\.\d+|\d{4}(-\d{2}(-\d{2})?)?|latest)$',
);
final _percentEncodingRegex = RegExp(r'%');
final _doubleDotRegex = RegExp(r'\.\.');
final _hyphenDotRegex = RegExp(r'-\.');
final _domainSuffixRegex = RegExp(r'\.(me|com|org|net|edu|gov|mil)$');
final _pnLocalStartRegex = RegExp(r'^[a-zA-Z0-9_:]');
final _pnLocalSingleCharRegex = RegExp(r'^[a-zA-Z0-9_:]$');
final _pnLocalEndCharRegex = RegExp(r'[a-zA-Z0-9_:-]$');
final _pnLocalFullRegex =
    RegExp(r'^[a-zA-Z0-9_:][a-zA-Z0-9_\-.:]*[a-zA-Z0-9_:-]$');

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

  /// Helper method to find a key in a map based on its value.
  ///
  /// This utility method performs a reverse lookup in a map, finding the
  /// first key that maps to the specified value. It's used internally for
  /// finding prefixes given a namespace URI.
  ///
  /// The [map] is the map to search in, and [value] is the value to look for.
  /// Returns the first key that maps to the value, or null if not found.
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
  /// The [customMappings] parameter specifies the mappings to add to the standard ones.
  /// If [useDefaults] is true (default), the standard mappings are included as well.
  RdfNamespaceMappings.custom(
    Map<String, String> customMappings, {
    useDefaults = true,
  }) : _mappings = useDefaults
            ? {..._rdfNamespaceMappings, ...customMappings}
            : customMappings;

  /// Returns the number of mappings in this instance.
  ///
  /// This property provides a convenient way to determine how many prefix-to-URI
  /// mappings are defined in this instance, which is useful for debugging and
  /// for determining if custom mappings have been added.
  int get length => _mappings.length;

  /// Operator for retrieving a namespace URI by its prefix.
  ///
  /// The [key] is the prefix to look up. Returns the namespace URI for the
  /// prefix, or null if not found.
  String? operator [](Object? key) => _mappings[key];

  /// Returns the prefix for a given namespace URI.
  ///
  /// This method performs a reverse lookup in the mappings to find the first prefix
  /// that corresponds to the given namespace URI. Custom mappings are checked first,
  /// followed by the standard mappings.
  ///
  /// The [namespace] is the URI to look up, and [customMappings] are additional
  /// mappings to check before the standard ones. Returns the prefix for the namespace,
  /// or null if not found.
  String? getPrefix(
    String namespace, {
    Map<String, String> customMappings = const {},
  }) {
    // Check if the namespace is already mapped
    return _getKeyByValue(customMappings, namespace) ??
        _getKeyByValue(_mappings, namespace);
  }

  /// Returns the Prefix for a given namespace URI, generating a new one if not found.
  ///
  /// This method first tries to find an existing prefix for the given namespace URI
  /// by checking the provided custom mappings and then the standard mappings.
  /// If no existing prefix is found, it attempts to generate a meaningful prefix
  /// based on the structure of the namespace URI.
  ///
  /// Note that this will not change the immutable RdfNamespaceMappings instance.
  /// Instead, it will return a new prefix that can be used for custom mappings.
  ///
  /// The returned tuple contains:
  /// - The prefix: either an existing one or a newly generated one
  /// - A boolean indicating whether the prefix was generated (true) or found (false)
  ///
  /// The [namespace] is the URI to look up or generate a prefix for, and
  /// [customMappings] are additional mappings to check before the standard ones.
  (String prefix, bool generated) getOrGeneratePrefix(
    String namespace, {
    Map<String, String> customMappings = const {},
  }) {
    String? candidate = _getKeyByValue(customMappings, namespace) ??
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
    } while (
        customMappings.containsKey(prefix) && !_mappings.containsKey(prefix));

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
      final match = _uriRegex.firstMatch(namespace);
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
    // This is necessary because hyphens are not allowed in RDF prefixes
    if (firstPart.contains('-')) {
      final parts = firstPart.split('-');
      if (parts.length >= 2 && parts.every((p) => p.isNotEmpty)) {
        final initials = parts.map((p) => p[0]).join('');
        if (_isValidPrefix(initials)) return initials;
      }

      // If initials approach doesn't work, try removing hyphens
      final noHyphens = firstPart.replaceAll('-', '');
      if (_isValidPrefix(noHyphens)) return noHyphens;
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
    final components = path
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
    final versionOrDatePattern = _versionOrDateRegex;

    // Special case for w3.org paths with 'ns' segment
    final nsIndex = components.indexOf('ns');
    if (nsIndex >= 0 && nsIndex < components.length - 1) {
      final candidate = components[nsIndex + 1];
      final cleanedCandidate = _sanitizeComponentForPrefix(candidate);
      if (_isGoodPrefix(genericTerms, cleanedCandidate, versionOrDatePattern)) {
        return cleanedCandidate;
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

      // Clean the component (remove or replace invalid characters)
      final cleanedComponent = _sanitizeComponentForPrefix(component);

      // Skip version numbers and dates
      if (versionOrDatePattern.hasMatch(cleanedComponent)) continue;

      // Skip generic terms if not the only option
      if (genericTerms.contains(cleanedComponent.toLowerCase()) &&
          (components.length > 1 || i > 0)) {
        continue;
      }

      // If we've reached the first component and haven't found anything better
      if (i == 0 && components.length > 1) {
        // Try using the first segment if it's not a generic term
        if (_isGoodPrefix(
          genericTerms,
          cleanedComponent,
          versionOrDatePattern,
        )) {
          return cleanedComponent;
        }

        // If the second segment is not a generic term or version, consider it
        if (components.length > 1) {
          final secondCleanedComponent = _sanitizeComponentForPrefix(
            components[1],
          );
          if (_isGoodPrefix(
            genericTerms,
            secondCleanedComponent,
            versionOrDatePattern,
          )) {
            return secondCleanedComponent;
          }
        }
      }

      // Found a good candidate
      if (_isGoodPrefix(genericTerms, cleanedComponent, versionOrDatePattern)) {
        return cleanedComponent;
      }
    }

    // If no good prefix found, return null - we will use the domain then
    return null;
  }

  /// Sanitizes a URL component to create a valid RDF prefix.
  ///
  /// Makes a path or domain component suitable for use as an RDF prefix by:
  /// 1. For hyphenated components, preferring the initials of each part (e.g., "test-complex-ontology" → "tco")
  /// 2. If initials approach fails, falling back to removing hyphens
  /// 3. Ensuring the result complies with RDF prefix naming rules
  ///
  /// Returns a cleaned string that can be used as a valid RDF prefix,
  /// or the original string if no cleaning is needed or possible.
  String _sanitizeComponentForPrefix(String component) {
    // If component already valid, return it as is
    if (_isValidPrefix(component)) return component;

    // For components with hyphens, prioritize using initials
    if (component.contains('-')) {
      final parts = component.split('-');
      if (parts.length >= 2 && parts.every((p) => p.isNotEmpty)) {
        final initials = parts.map((p) => p.isNotEmpty ? p[0] : '').join('');
        if (_isValidPrefix(initials)) return initials;

        // If initials approach doesn't work, fall back to removing hyphens
        final noHyphens = component.replaceAll('-', '');
        if (_isValidPrefix(noHyphens)) return noHyphens;
      }
    } else {
      // For components without hyphens, just return the component
      return component;
    }

    // Return original if cleaning didn't work (will be filtered out later by _isValidPrefix)
    return component;
  }

  /// Determines if a string component makes a good prefix for a namespace.
  ///
  /// A good prefix must satisfy three conditions:
  /// 1. Not be in the predefined set of generic terms
  /// 2. Not match patterns for version numbers or dates
  /// 3. Be a valid prefix according to naming rules
  ///
  /// The [genericTerms] parameter contains common generic terms that would make poor prefixes.
  /// The [component] is the string component to evaluate, and [versionOrDatePattern] is a
  /// regular expression for identifying version numbers or dates.
  /// Returns true if the component makes a good prefix, false otherwise.
  bool _isGoodPrefix(
    Set<String> genericTerms,
    String component,
    RegExp versionOrDatePattern,
  ) {
    return !genericTerms.contains(component.toLowerCase()) &&
        !versionOrDatePattern.hasMatch(component) &&
        _isValidPrefix(component);
  }

  /// Checks if a string is valid for use as an RDF namespace prefix.
  ///
  /// A valid prefix must follow the Turtle/SPARQL specification for PN_PREFIX:
  /// 1. Must not be empty
  /// 2. First character must be a letter (A-Z, a-z) or underscore (_)
  /// 3. Subsequent characters can be letters, digits, underscore (_), or period (.)
  /// 4. If periods are used, they must not be the last character
  ///
  /// Note that according to the RDF specifications, hyphens (-) are not allowed in prefixes,
  /// although they are allowed in local names.
  ///
  /// These rules align with the Turtle/SPARQL specification for PN_PREFIX.
  ///
  /// The [name] parameter is the string to validate as a potential prefix.
  /// Returns true if the string is a valid prefix, false otherwise.
  bool _isValidPrefix(String name) {
    if (name.isEmpty) {
      return false;
    }

    // First character must be a letter or underscore (PN_CHARS_BASE)
    final firstChar = name.codeUnitAt(0);
    if (!((firstChar >= 65 && firstChar <= 90) || // A-Z
        (firstChar >= 97 && firstChar <= 122) || // a-z
        firstChar == 95)) {
      // _
      return false;
    }

    // Subsequent characters can include letters, digits, underscore and periods
    // but periods must not be the last character
    for (int i = 1; i < name.length; i++) {
      final char = name.codeUnitAt(i);
      if (!((char >= 65 && char <= 90) || // A-Z
          (char >= 97 && char <= 122) || // a-z
          (char >= 48 && char <= 57) || // 0-9
          char == 95 || // _
          char == 46)) {
        // .
        return false;
      }
    }

    // Period must not be the last character
    if (name.endsWith('.')) {
      return false;
    }

    return true;
  }

  /// Validates whether a string is a valid PN_LOCAL according to Turtle specification.
  ///
  /// PN_LOCAL ::= (PN_CHARS_U | ':' | [0-9] | PLX) ((PN_CHARS | '.' | ':' | PLX)* (PN_CHARS | ':' | PLX))?
  ///
  /// Key rules:
  /// - Can contain dots and colons in the middle
  /// - Cannot start with a dot (handled by first part)
  /// - Cannot end with a dot (enforced by the last part)
  /// - Can start with digits (if allowed)
  ///
  /// Returns true if the string is a valid PN_LOCAL, false otherwise.
  static bool _isValidPnLocal(String localPart,
      {bool allowNumericLocalNames = true}) {
    if (localPart.isEmpty) {
      return true; // Empty local part is valid (e.g., "prefix:")
    }

    // Check if starts with digit and not allowed
    if (!allowNumericLocalNames && _digitStartRegex.hasMatch(localPart)) {
      return false;
    }

    // Check for invalid characters like percent encoding
    if (_percentEncodingRegex.hasMatch(localPart)) {
      return false;
    }

    // Cannot end with a dot according to PN_LOCAL grammar
    if (localPart.endsWith('.')) {
      return false;
    }

    // Cannot start with a dot
    if (localPart.startsWith('.')) {
      return false;
    }

    // Cannot start with hyphen
    if (localPart.startsWith('-')) {
      return false;
    }

    // Cannot contain double dots (not explicitly in spec but generally invalid)
    if (_doubleDotRegex.hasMatch(localPart)) {
      return false;
    }

    // Cannot have hyphen followed by dot (invalid pattern)
    if (_hyphenDotRegex.hasMatch(localPart)) {
      return false;
    }

    // For conservative approach, reject domain-like suffixes that end with dots followed by common TLDs
    // This prevents confusion with domain names in URIs
    if (_domainSuffixRegex.hasMatch(localPart)) {
      return false;
    }

    // Basic character validation - must start with valid PN_CHARS_U or digit or colon
    // and contain only valid characters
    if (!_pnLocalStartRegex.hasMatch(localPart)) {
      return false;
    }

    // For single character, it must be a valid ending character
    if (localPart.length == 1) {
      return _pnLocalSingleCharRegex.hasMatch(localPart);
    }

    // For multi-character strings, validate that it doesn't end with problematic characters
    // According to PN_LOCAL grammar, last character must be PN_CHARS | ':' | PLX (not '.')
    if (!_pnLocalEndCharRegex.hasMatch(localPart)) {
      return false;
    }

    // Check that all characters are valid PN_LOCAL characters
    return _pnLocalFullRegex.hasMatch(localPart);
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
  /// Returns an unmodifiable map of the prefix-to-URI mappings.
  Map<String, String> asMap() => Map.unmodifiable(_mappings);

  /// Checks if the mappings contain a specific prefix.
  ///
  /// The [prefix] is the prefix to check for.
  /// Returns true if the prefix exists, false otherwise.
  bool containsKey(String prefix) => _mappings.containsKey(prefix);

  /// Extracts the namespace and local part from an IRI
  ///
  /// A namespace is defined as the part of the IRI up to and including the last '#' character,
  /// or the part up to and including the last '/' character if there is no '#'.
  /// However, if the resulting namespace would be a protocol-only URI (like 'http://' or 'https://'),
  /// the entire IRI is treated as the namespace to avoid generating invalid or meaningless prefixes.
  ///
  /// The [iri] is the IRI to split into namespace and local part.
  /// When [allowNumericLocalNames] is false, local parts that start with a digit will be
  /// considered invalid for prefixed notation (which is common in formats like Turtle),
  /// resulting in an empty local part and the full IRI as the namespace.
  ///
  /// Parameters:
  /// - [iri] The IRI to split
  /// - [allowNumericLocalNames] Whether to allow local names that start with digits (default: true)
  ///
  /// Returns a tuple containing (namespace, localPart).
  static (String namespace, String localPart) extractNamespaceAndLocalPart(
    String iri, {
    bool allowNumericLocalNames = true,
  }) {
    final hashIndex = iri.lastIndexOf('#');
    final slashIndex = iri.lastIndexOf('/');

    String namespace;
    String localPart;

    if (hashIndex > slashIndex && hashIndex != -1) {
      namespace = iri.substring(0, hashIndex + 1);
      localPart = iri.substring(hashIndex + 1);
    } else if (slashIndex != -1) {
      // Check if the namespace would only be a protocol like 'http://' or 'https://'
      namespace = iri.substring(0, slashIndex + 1);
      if (namespace == 'http://' ||
          namespace == 'https://' ||
          namespace == 'ftp://' ||
          namespace == 'file://') {
        // If just a protocol, use the entire IRI as namespace and leave local part empty
        return (iri, '');
      }
      localPart = iri.substring(slashIndex + 1);
    } else {
      return (iri, '');
    }

    if (!isValidLocalPart(localPart,
        allowNumericLocalNames: allowNumericLocalNames)) {
      return (iri, '');
    }
    return (namespace, localPart);
  }

  static bool isValidLocalPart(
    String localPart, {
    bool allowNumericLocalNames = true,
  }) {
    // If local part starts with a digit and numeric local names aren't allowed,
    // return the full IRI as namespace and an empty local part
    if (!allowNumericLocalNames &&
        localPart.isNotEmpty &&
        _digitStartRegex.hasMatch(localPart)) {
      return false;
    }
    if (_percentEncodingRegex.hasMatch(localPart)) {
      return false;
    }

    // Validate PN_LOCAL according to Turtle specification
    if (!_isValidPnLocal(localPart,
        allowNumericLocalNames: allowNumericLocalNames)) {
      return false;
    }

    return true;
  }
}
