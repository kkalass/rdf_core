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

import 'dart:math' as math;
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
/// - The relativization would violate the provided [options] constraints
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
///
/// // With conservative options
/// relativizeIri('http://example.org/other/file', 'http://example.org/path/',
///     options: IriRelativizationOptions.local())
/// // Returns: 'http://example.org/other/file' (unchanged - no cross-directory navigation)
/// ```
///
/// The function guarantees that `resolveIri(relativizeIri(iri, base, options: opts), base)`
/// will return the original [iri].
String relativizeIri(String iri, String? baseIri,
    {IriRelativizationOptions? options}) {
  if (baseIri == null || baseIri.isEmpty) {
    return iri;
  }
  final relativizationOptions =
      options ?? const IriRelativizationOptions.full();
  final result = _relativizeUri(iri, baseIri, relativizationOptions);
  if (result == iri) {
    return iri;
  }
  if (iri != resolveIri(result, baseIri)) {
    // If the relativized IRI does not resolve back to the original, return original
    return iri;
  }
  return result;
}

/// Implements RFC 3986 compliant IRI relativization with roundtrip consistency.
///
/// This is the core relativization algorithm that ensures any relative IRI
/// produced can be resolved back to the original absolute IRI.
///
/// The algorithm tries several strategies in order of preference:
/// 1. Empty string for identical IRIs
/// 2. Fragment-only references (e.g., '#section')
/// 3. Path-based relativization with dot notation (e.g., '../file', './file')
/// 4. Simple path relativization for directory-based cases
/// 5. Filename-only relativization for certain edge cases
///
/// The [options] parameter controls the aggressiveness and constraints of relativization.
///
/// Falls back to returning the absolute IRI if no safe relativization is possible.
String _relativizeUri(
    String iri, String baseIri, IriRelativizationOptions options) {
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
    if (options.maxUpLevels != null && options.maxUpLevels! < 0) {
      // Special case: negative maxUpLevels means no relativization allowed
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
      return '#${uri.fragment}';
    }

    // Try sophisticated path-based relativization with dot notation
    if (!baseUri.hasQuery &&
        (!baseUri.hasFragment || baseUri.fragment.isEmpty)) {
      final dotNotationResult =
          _tryDotNotationRelativization(uri, baseUri, options);
      if (dotNotationResult != null) {
        return dotNotationResult;
      }
    }

    // If no safe relativization found, return absolute URI
    return iri;
  } catch (e) {
    // If any parsing fails, return the absolute URI
    return iri;
  }
}

/// Attempts to create a relative path using dot notation (../, ./).
///
/// This function analyzes the path segments of both URIs to determine if
/// a relative path with dot notation can be generated. It handles cases where
/// the target IRI is in a different directory than the base IRI.
///
/// Returns a relative path string if successful, null if not possible.
/// The result includes query and fragment components when present.
///
/// The [options] parameter controls the constraints and aggressiveness of relativization:
/// - maxUpLevels: limits the number of "../" components
/// - allowSiblingDirectories: whether to allow "../sibling/" patterns
/// - maxAdditionalLength: prevents excessively long relative paths
///
/// Examples:
/// - Base: http://example.org/a/b/ Target: http://example.org/a/c/file.txt → ../c/file.txt
/// - Base: http://example.org/a/b/file Target: http://example.org/a/c/file.txt → ../c/file.txt
/// - Base: http://example.org/a/ Target: http://example.org/a/b/file.txt → b/file.txt
/// - Base: http://example.org/a/b/ Target: http://example.org/a/b/file.txt → file.txt
String? _tryDotNotationRelativization(
    Uri uri, Uri baseUri, IriRelativizationOptions options) {
  final targetSegments = uri.pathSegments.toList();
  final baseSegments = baseUri.pathSegments.toList();

  // Remove empty segments at the end (trailing slashes)
  while (baseSegments.isNotEmpty && baseSegments.last.isEmpty) {
    baseSegments.removeLast();
  }
  while (targetSegments.isNotEmpty && targetSegments.last.isEmpty) {
    targetSegments.removeLast();
  }

  // Handle the case where base doesn't end with / (file reference)
  // In this case, we need to go up to the parent directory
  if (!baseUri.path.endsWith('/') && baseSegments.isNotEmpty) {
    baseSegments.removeLast();
  }

  // Find common prefix
  int commonLength = 0;
  final minLength = math.min(baseSegments.length, targetSegments.length);

  for (int i = 0; i < minLength; i++) {
    if (baseSegments[i] == targetSegments[i]) {
      commonLength++;
    } else {
      break;
    }
  }

  // Calculate how many directories to go up
  final upLevels = baseSegments.length - commonLength;

  // Apply options constraints
  if (options.maxUpLevels != null && options.maxUpLevels! < 0) {
    // Special case: negative maxUpLevels means no relativization allowed
    return null;
  }

  if (options.maxUpLevels != null && upLevels > options.maxUpLevels!) {
    return null;
  }

  // Conservative check: handle sibling directory constraints
  if (upLevels > 0 && !options.allowSiblingDirectories) {
    // Check if we're navigating to a sibling directory:
    // - We go up at least one level (upLevels > 0), AND
    // - We then go down into a different directory structure

    // Count target directory segments after common prefix (excluding final file if any)
    var targetDirSegmentsAfterCommon = targetSegments.length - commonLength;

    // If target doesn't end with '/', the last segment might be a file
    if (!uri.path.endsWith('/') && targetDirSegmentsAfterCommon > 0) {
      targetDirSegmentsAfterCommon--; // Exclude potential file segment
    }

    if (targetDirSegmentsAfterCommon > 0) {
      // This is sibling directory navigation: up then down to different directory
      return null;
    }
    // If targetDirSegmentsAfterCommon == 0, it's just parent navigation (allowed)
  }

  // Build relative path
  final pathParts = <String>[];

  // Add ../ for each level up needed
  for (int i = 0; i < upLevels; i++) {
    pathParts.add('..');
  }

  // Add remaining target segments
  for (int i = commonLength; i < targetSegments.length; i++) {
    pathParts.add(targetSegments[i]);
  }

  // Build the relative path string
  var relativePath = pathParts.join('/');

  // Add query and fragment if present
  if (uri.hasQuery) {
    relativePath += '?${uri.query}';
  }
  if (uri.hasFragment) {
    relativePath += '#${uri.fragment}';
  }

  // Check that the relative IRI is not too much longer than the absolute IRI
  if (options.maxAdditionalLength != null) {
    final absoluteIri = uri.toString();
    final maxAllowed = absoluteIri.length + options.maxAdditionalLength!;
    if (relativePath.length > maxAllowed) {
      return null;
    }
  }

  return relativePath;
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
    final isValidSchemeChar = (char >= 97 && char <= 122) || // a-z
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
    final baseWithoutFragment = baseIri.contains('#')
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
