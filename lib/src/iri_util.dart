/// IRI (Internationalized Resource Identifier) utilities for RDF processing.
///
/// This library provides functions for relativizing and resolving IRIs according
/// to RFC 3986 standards. IRIs are a generalization of URIs that allow
/// international characters - they're the standard identifier format in RDF.
///
/// The main operations are:
/// - [relativizeIri]: Convert absolute IRIs to relative form when possible
/// - [resolveIri]: Convert relative IRIs to absolute form using a base IRI
///
/// These functions ensure roundtrip consistency: relativizing an IRI and then
/// resolving it back should produce the original IRI.
library iri_util;

import 'package:rdf_core/rdf_core.dart';

/// Converts an absolute IRI to a relative form when possible.
///
/// Takes an [iri] and attempts to express it relative to the given [baseIri].
/// This is useful for creating shorter, more readable RDF serializations.
///
/// Returns the original [iri] unchanged if:
/// - [baseIri] is null or empty
/// - The IRI cannot be safely relativized
/// - The IRIs have different schemes or authorities
///
/// Examples:
/// ```dart
/// relativizeIri('http://example.org/path/file.txt', 'http://example.org/path/')
/// // Returns: 'file.txt'
///
/// relativizeIri('http://example.org/path#section', 'http://example.org/path#')
/// // Returns: '#section'
///
/// relativizeIri('https://other.org/file', 'http://example.org/')
/// // Returns: 'https://other.org/file' (unchanged - different domains)
/// ```
///
/// The function guarantees that `resolveIri(relativizeIri(iri, base), base)`
/// will return the original [iri].
String relativizeIri(String iri, String? baseIri) {
  if (baseIri == null || baseIri.isEmpty) {
    return iri;
  }
  return _relativizeUri(iri, baseIri);
}

/// Implements RFC 3986 compliant IRI relativization with roundtrip consistency.
///
/// This is the core relativization algorithm that ensures any relative IRI
/// produced can be resolved back to the original absolute IRI.
///
/// The algorithm tries several strategies in order of preference:
/// 1. Empty string for identical IRIs
/// 2. Fragment-only references (e.g., '#section')
/// 3. Path-based relativization for hierarchical IRIs
/// 4. Filename-only relativization for certain cases
///
/// Falls back to returning the absolute IRI if no safe relativization is possible.
String _relativizeUri(String iri, String baseIri) {
  try {
    final baseUri = Uri.parse(baseIri);
    final uri = Uri.parse(iri);

    // Only relativize if both URIs have scheme and authority
    if (baseUri.scheme.isEmpty ||
        uri.scheme.isEmpty ||
        !baseUri.hasAuthority ||
        !uri.hasAuthority) {
      return iri;
    }

    if (baseUri.scheme != uri.scheme || baseUri.authority != uri.authority) {
      return iri;
    }

    // Special case: if URIs are identical, return empty string
    if (iri == baseIri) {
      return '';
    }

    // Check for fragment-only differences (most optimal case)
    if (baseUri.path == uri.path &&
        baseUri.query == uri.query &&
        uri.hasFragment) {
      // Only the fragment differs, return just the fragment
      final fragmentRef = '#${uri.fragment}';
      final resolvedBack = resolveIri(fragmentRef, baseIri);
      if (resolvedBack.toString() == iri) {
        return fragmentRef;
      }
    }

    // Try simple path-based relativization
    if (!baseUri.hasQuery && !baseUri.hasFragment) {
      final basePath = baseUri.path;
      final iriPath = uri.path;

      // For simple cases where base ends with / and IRI starts with base path
      if (basePath.endsWith('/') && iriPath.startsWith(basePath)) {
        final relativePath = iriPath.substring(basePath.length);

        // Construct candidate relative URI
        var relativeUri = relativePath;
        if (uri.hasQuery) {
          relativeUri += '?${uri.query}';
        }
        if (uri.hasFragment) {
          relativeUri += '#${uri.fragment}';
        }

        // Verify roundtrip: resolve relative URI against base should give original
        final resolvedBack = resolveIri(relativeUri, baseIri);
        if (resolvedBack.toString() == iri) {
          return relativeUri;
        }
      }
    }

    // Try filename-only relativization (for cases like http://my.host/foo vs http://my.host/path#)
    // This is safe when:
    // 1. Base has no query (queries affect resolution)
    // 2. If base has fragment, it should not end with / (directory-like bases with fragments are ambiguous)
    if (uri.pathSegments.isNotEmpty && !baseUri.hasQuery) {
      // Additional check: if base has fragment and path ends with /, skip this relativization
      if (baseUri.hasFragment && baseUri.path.endsWith('/')) {
        // Skip this type of relativization for directory-like bases with fragments
      } else {
        final filename = uri.pathSegments.last;
        if (filename.isNotEmpty) {
          var candidate = filename;
          if (uri.hasQuery) {
            candidate += '?${uri.query}';
          }
          if (uri.hasFragment) {
            candidate += '#${uri.fragment}';
          }

          final resolvedBack = resolveIri(candidate, baseIri);
          if (resolvedBack.toString() == iri) {
            return candidate;
          }
        }
      }
    }

    // If no safe relativization found, return absolute URI
    return iri;
  } catch (e) {
    // If any parsing fails, return the absolute URI
    return iri;
  }
}

/// Exception thrown when a base IRI is required but not provided.
///
/// This occurs when trying to resolve a relative IRI without a base IRI.
/// Relative IRIs (like 'file.txt' or '#section') cannot be resolved to
/// absolute form without knowing what they're relative to.
///
/// Example:
/// ```dart
/// try {
///   resolveIri('#section', null); // Missing base IRI
/// } on baseIriRequiredException catch (e) {
///   print('Cannot resolve: ${e.relativeUri}');
/// }
/// ```
class BaseIriRequiredException extends RdfDecoderException {
  /// The relative IRI that could not be resolved.
  final String relativeUri;

  /// Creates a new base IRI required exception.
  ///
  /// The [relativeUri] parameter should contain the relative IRI that
  /// triggered this exception.
  const BaseIriRequiredException({required this.relativeUri})
    : super(
        'Base IRI is required to resolve relative IRI: $relativeUri',
        format: 'iri',
      );
}

/// Converts a relative IRI to absolute form using a base IRI.
///
/// Takes a potentially relative [iri] and resolves it against [baseIri] to
/// produce an absolute IRI. This is the inverse operation of [relativizeIri].
///
/// If [iri] is already absolute (contains a scheme like 'http:'), it's
/// returned unchanged regardless of [baseIri].
///
/// Throws [BaseIriRequiredException] if [iri] is relative but [baseIri]
/// is null or empty.
///
/// Examples:
/// ```dart
/// resolveIri('file.txt', 'http://example.org/path/')
/// // Returns: 'http://example.org/path/file.txt'
///
/// resolveIri('#section', 'http://example.org/document')
/// // Returns: 'http://example.org/document#section'
///
/// resolveIri('http://other.org/file', 'http://example.org/')
/// // Returns: 'http://other.org/file' (unchanged - already absolute)
/// ```
///
/// The function uses Dart's built-in [Uri.resolveUri] when possible,
/// falling back to manual resolution for edge cases.
String resolveIri(String iri, String? baseIri) {
  if (_isAbsoluteUri(iri)) {
    return iri;
  }

  if (baseIri == null || baseIri.isEmpty) {
    throw BaseIriRequiredException(relativeUri: iri);
  }

  try {
    final base = Uri.parse(baseIri);
    final resolved = base.resolveUri(Uri.parse(iri));
    return resolved.toString();
  } catch (e) {
    // Fall back to manual resolution if URI parsing fails
    return _manualResolveUri(iri, baseIri);
  }
}

/// Checks if an IRI is absolute by looking for a scheme component.
///
/// An absolute IRI has a scheme (like 'http:', 'https:', 'file:') followed
/// by scheme-specific content. Relative IRIs lack this scheme.
///
/// This is more efficient than using regular expressions and handles the
/// most common cases correctly.
bool _isAbsoluteUri(String uri) {
  final colonPos = uri.indexOf(':');
  if (colonPos <= 0) return false;

  // Validate scheme characters (letters, digits, +, -, .)
  for (int i = 0; i < colonPos; i++) {
    final char = uri.codeUnitAt(i);
    final isValidSchemeChar =
        (char >= 97 && char <= 122) || // a-z
        (char >= 65 && char <= 90) || // A-Z
        (char >= 48 && char <= 57) || // 0-9
        char == 43 || // +
        char == 45 || // -
        char == 46; // .

    if (!isValidSchemeChar) return false;
  }

  return true;
}

/// Fallback IRI resolution for cases where [Uri.resolveUri] fails.
///
/// This handles edge cases and malformed IRIs that Dart's built-in
/// [Uri] class cannot parse. Uses string manipulation to approximate
/// correct IRI resolution behavior.
///
/// Supports:
/// - Fragment references (starting with '#')
/// - Absolute paths (starting with '/')
/// - Relative paths (everything else)
String _manualResolveUri(String uri, String baseIri) {
  // Fragment identifier - replace fragment in base
  if (uri.startsWith('#')) {
    final baseWithoutFragment =
        baseIri.contains('#')
            ? baseIri.substring(0, baseIri.indexOf('#'))
            : baseIri;
    return '$baseWithoutFragment$uri';
  }

  // Absolute path - replace path portion of base
  if (uri.startsWith('/')) {
    final schemeEnd = baseIri.indexOf('://');
    if (schemeEnd >= 0) {
      final pathStart = baseIri.indexOf('/', schemeEnd + 3);
      if (pathStart >= 0) {
        return '${baseIri.substring(0, pathStart)}$uri';
      }
    }
    return baseIri.endsWith('/')
        ? '${baseIri.substring(0, baseIri.length - 1)}$uri'
        : '$baseIri$uri';
  }

  // Relative path - append to base directory
  final lastSlashPos = baseIri.lastIndexOf('/');
  if (lastSlashPos >= 0) {
    return '${baseIri.substring(0, lastSlashPos + 1)}$uri';
  } else {
    return '$baseIri/$uri';
  }
}
