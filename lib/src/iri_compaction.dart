/// Prefix generation utilities for RDF serializers
///
/// This module provides common functionality for analyzing RDF graphs and generating
/// namespace prefixes automatically. It is used by both Turtle and JSON-LD encoders
/// to provide consistent prefix generation behavior.
library prefix_generator;

import 'package:logging/logging.dart';
import 'package:rdf_core/src/graph/rdf_graph.dart';
import 'package:rdf_core/src/graph/rdf_term.dart';
import 'package:rdf_core/src/iri_util.dart';
import 'package:rdf_core/src/vocab/namespaces.dart';
import 'package:rdf_core/src/vocab/rdf.dart';

final _log = Logger('rdf_core.iri_compaction');

enum IriRole {
  subject,
  predicate,
  object,
  type,
  datatype,
}

enum IriCompactionType {
  /// Use a prefix for the IRI
  prefixed,

  /// Use a full IRI in angle brackets
  full,

  /// Use a relative IRI (without base URI)
  relative,
}

/// Function type for filtering IRIs that should be considered for prefix generation.
///
/// This allows different serializers to implement their own logic for determining
/// which IRIs should have prefixes generated (vs being relativized, etc).
///
/// Parameters:
/// - [iri] The IRI to check
/// - [isPredicate] Whether this IRI is being used as a predicate
///
/// Returns true if the IRI should be processed for prefix generation.
typedef IriFilter = bool Function(IriTerm iri, {required IriRole role});
typedef AllowedCompactionTypes = Map<IriRole, Set<IriCompactionType>>;
final allowedCompactionTypesAll = {
  for (final role in IriRole.values) role: {...IriCompactionType.values},
};

class IriCompactionSettings {
  /// Controls automatic generation of namespace prefixes for IRIs without matching prefixes.
  ///
  /// When set to `true` (default), the encoder will automatically generate namespace
  /// prefixes for IRIs that don't have a matching prefix in either the custom prefixes
  /// or the standard namespace mappings.
  ///
  /// The prefix generation process:
  /// 1. Attempts to extract a meaningful namespace from the IRI (splitting at '/' or '#')
  /// 2. Skips IRIs with only protocol specifiers (e.g., "http://")
  /// 3. Only generates prefixes for namespaces ending with '/' or '#'
  ///    (proper RDF namespace delimiters)
  /// 4. Uses RdfNamespaceMappings.getOrGeneratePrefix to create a compact, unique prefix
  ///
  /// Setting this to `false` will result in all IRIs without matching prefixes being
  /// written as full IRIs in angle brackets (e.g., `<http://example.org/term>`).
  ///
  /// This option is particularly useful for:
  /// - Reducing the verbosity of the output
  /// - Making the serialized data more human-readable
  /// - Automatically handling unknown namespaces without manual prefix declaration
  final bool generateMissingPrefixes;

  final AllowedCompactionTypes allowedCompactionTypes;

  final Set<IriTerm> specialPredicates;
  final Set<IriTerm> specialDatatypes;

  IriCompactionSettings({
    required this.generateMissingPrefixes,
    required AllowedCompactionTypes? allowedCompactionTypes,
    required this.specialPredicates,
    required this.specialDatatypes,
  }) : allowedCompactionTypes =
            allowedCompactionTypes ?? allowedCompactionTypesAll;
}

sealed class CompactIri {}

final class PrefixedIri extends CompactIri {
  final String prefix;
  final String namespace;
  final String? localPart;

  String get colonSeparated => localPart == null || localPart!.isEmpty
      ? (prefix.isEmpty ? ':' : '$prefix:')
      : '${prefix.isEmpty ? '' : '$prefix'}:$localPart';

  PrefixedIri(this.prefix, this.namespace, String? localPart)
      : localPart = localPart?.isEmpty == true ? null : localPart;
}

final class FullIri extends CompactIri {
  final String iri;
  FullIri(this.iri);
}

final class RelativeIri extends CompactIri {
  final String relative;
  RelativeIri(this.relative);
}

final class SpecialIri extends CompactIri {
  final IriTerm iri;
  SpecialIri(this.iri);
}

final class IriCompactionResult {
  final Map<String, String> prefixes;
  final Map<
      (
        IriTerm iri,
        IriRole role,
      ),
      CompactIri> compactIris;

  IriCompactionResult({
    required this.prefixes,
    required this.compactIris,
  });

  CompactIri? compactIri(IriTerm iri, IriRole role) => compactIris[(iri, role)];
}

/// Utility class for analyzing RDF graphs and generating namespace prefixes.
///
/// This class provides static methods for extracting used prefixes from RDF graphs
/// and automatically generating new prefixes for unknown namespaces. The logic is
/// shared between different RDF serializers to ensure consistent behavior.
class IriCompaction {
  final RdfNamespaceMappings _namespaceMappings;
  final IriCompactionSettings _settings;
  final bool Function(String) _isValidIriLocalPart;
  const IriCompaction(
      this._namespaceMappings, this._settings, this._isValidIriLocalPart);

  IriCompactionResult compactAllIris(
    RdfGraph graph,
    Map<String, String> customPrefixes, {
    String? baseUri,
  }) {
    final prefixCandidates = {
      ..._namespaceMappings.asMap(),
    };
    prefixCandidates
        .removeWhere((key, value) => customPrefixes.values.contains(value));
    prefixCandidates.addAll(customPrefixes);

    final usedPrefixes = <String, String>{};
    final compactIris = <(
      IriTerm iri,
      IriRole role,
    ),
        CompactIri>{};
    // Create an inverted index for quick lookup
    final iriToPrefixMap = {
      for (final e in prefixCandidates.entries) e.value: e.key
    };
    if (iriToPrefixMap.length != prefixCandidates.length) {
      throw ArgumentError(
        'Duplicate namespace URIs found in prefix candidates: $prefixCandidates',
      );
    }
    final List<(IriTerm iri, IriRole role)> iris = graph.triples
        .expand((triple) => <(IriTerm iri, IriRole role)>[
              if (triple.subject is IriTerm)
                (triple.subject as IriTerm, IriRole.subject),
              if (triple.predicate is IriTerm)
                (triple.predicate as IriTerm, IriRole.predicate),
              if (triple.object is IriTerm && triple.predicate == Rdf.type)
                (triple.object as IriTerm, IriRole.type),
              if (triple.object is IriTerm && triple.predicate != Rdf.type)
                (triple.object as IriTerm, IriRole.object),
              if (triple.object is LiteralTerm)
                ((triple.object as LiteralTerm).datatype, IriRole.datatype),
            ])
        .toList();

    for (final (iri, role) in iris) {
      final compacted = compactIri(
          iri, role, baseUri, iriToPrefixMap, prefixCandidates, customPrefixes);
      compactIris[(iri, role)] = compacted;
      if (compacted
          case PrefixedIri(
            prefix: var prefix,
            namespace: var namespace,
          )) {
        // Add the prefix to all relevant maps
        usedPrefixes[prefix] = namespace;
        final oldNamespace = prefixCandidates[prefix];
        final oldPrefix = iriToPrefixMap[namespace];
        if (oldNamespace != null && oldNamespace != namespace) {
          throw ArgumentError(
            'Namespace conflict for prefix "$prefix": '
            'already mapped to "$oldNamespace", cannot map to "$namespace".',
          );
        }
        if (oldPrefix != null && oldPrefix != prefix) {
          throw ArgumentError(
            'Prefix conflict for namespace "$namespace": '
            'already mapped to "$oldPrefix", cannot map to "$prefix".',
          );
        }
        // Update candidates with new prefix
        prefixCandidates[prefix] = namespace;
        iriToPrefixMap[namespace] = prefix; // Update inverse mapping
      }
    }

    return IriCompactionResult(
        prefixes: usedPrefixes, compactIris: compactIris);
  }

  CompactIri compactIri(
      IriTerm term,
      IriRole role,
      String? baseUri,
      Map<String, String> iriToPrefixMap,
      Map<String, String> prefixCandidates,
      Map<String, String> customPrefixes) {
    if (role == IriRole.predicate &&
        _settings.specialPredicates.contains(term)) {
      return SpecialIri(term);
    }
    if (role == IriRole.datatype && _settings.specialDatatypes.contains(term)) {
      return SpecialIri(term);
    }

    // In Turtle, predicates cannot be relativized (they must use prefixes or full IRIs)
    final allowedTypes = _settings.allowedCompactionTypes[role] ??
        IriCompactionType.values.toSet();

    final relativized = allowedTypes.contains(IriCompactionType.relative)
        ? relativizeIri(term.iri, baseUri)
        : term.iri;
    final relativeUrl = relativized == term.iri ? null : relativized;

    if (relativeUrl != null && relativeUrl.isEmpty) {
      // If we have a relative URL that is empty, we do not need to check
      // for better matching prefixes, but use the relative URL directly
      return RelativeIri(relativeUrl);
    }
    final iri = term.iri;
    final prefixAllowed = allowedTypes.contains(IriCompactionType.prefixed);
    final fullAllowed = allowedTypes.contains(IriCompactionType.full);
    if (prefixAllowed && iriToPrefixMap.containsKey(iri)) {
      final prefix = iriToPrefixMap[iri]!;
      return PrefixedIri(prefix, iri, null);
    }

    if (relativeUrl != null) {
      // Special case: if we have a relative URL, check the custom prefixes
      // to see if any of them lead to a shorter local part than the relative URL
      if (prefixAllowed) {
        if (_bestMatch(iri, customPrefixes)
            case (String bestPrefix, String bestMatch)) {
          final localPart = _extractLocalPart(iri, bestMatch);
          if (localPart.length < relativeUrl.length &&
              _isValidIriLocalPart(localPart)) {
            // If the  local part of the best match is shorter than the relative one, use it instead
            return PrefixedIri(bestPrefix, bestMatch, localPart);
          }
        }
      }
      // Usually we want to use the relative URL if we have one
      return RelativeIri(relativeUrl);
    }

    // For prefix match, use the longest matching prefix (most specific)
    // This handles overlapping prefixes correctly (e.g., http://example.org/ and http://example.org/vocabulary/)
    if (prefixAllowed) {
      if (_bestMatch(iri, prefixCandidates)
          case (String bestPrefix, String bestMatch)) {
        // If we have a prefix match, use it
        final localPart = _extractLocalPart(iri, bestMatch);
        if (_isValidIriLocalPart(localPart)) {
          return PrefixedIri(bestPrefix, bestMatch, localPart);
        }
      }
    }

    if (prefixAllowed && _settings.generateMissingPrefixes) {
      // No existing prefix found, generate a new one using namespace mappings

      // Extract namespace from IRI
      final (
        namespace,
        localPart,
      ) = RdfNamespaceMappings.extractNamespaceAndLocalPart(
        iri,
      );
      if (fullAllowed &&
          (localPart.isEmpty || !_isValidIriLocalPart(localPart))) {
        // If we have no local part, we cannot generate a prefix
        return FullIri(iri);
      }
      // Warn if https:// is used and http:// is in the prefix map for the same path (or the other way around)
      _warnSchemaNamespaceMismatch(
          iri, namespace, prefixCandidates, "http://", "https://");
      _warnSchemaNamespaceMismatch(
          iri, namespace, prefixCandidates, "https://", "http://");

      // Skip generating prefixes for protocol-only URIs like "http://" or "https://"
      if (fullAllowed &&
          (namespace == "http://" ||
              namespace == "https://" ||
              namespace == "ftp://" ||
              namespace == "file://")) {
        // If it's just a protocol URI, don't add a prefix
        return FullIri(iri);
      }

      // Skip generating prefixes for namespaces that don't end with "/" or "#"
      // since these are not proper namespace delimiters in RDF
      if (fullAllowed &&
          (!namespace.endsWith('/') && !namespace.endsWith('#'))) {
        // For IRIs without proper namespace delimiters, don't add a prefix
        return FullIri(iri);
      }

      // Get or generate a prefix for this namespace
      final (prefix, _) = _namespaceMappings.getOrGeneratePrefix(
        namespace,
        customMappings: prefixCandidates,
      );
      return PrefixedIri(prefix, namespace, localPart);
    }
    if (!fullAllowed) {
      throw ArgumentError(
        'Cannot compact IRI "$iri" with role $role: '
        'no allowed compaction types for this role.',
      );
    }
    return FullIri(iri);
  }

  void _warnSchemaNamespaceMismatch(
      String iri,
      String namespace,
      Map<String, String> prefixCandidates,
      String actualSchema,
      String preferredSchema) {
    if (namespace.startsWith(actualSchema)) {
      final preferredNamespace =
          preferredSchema + namespace.substring(actualSchema.length);
      if (prefixCandidates.containsValue(preferredNamespace)) {
        _log.warning(
          'Namespace mismatch: Found IRI $iri, but canonical prefix uses $preferredNamespace. Consider using the canonical $preferredSchema form instead of $actualSchema.',
        );
      }
    }
  }

  String _extractLocalPart(String iri, String bestMatch) =>
      iri.substring(bestMatch.length);

  (String prefix, String namespace)? _bestMatch(
      String iri, Map<String, String> prefixCandidates) {
    var bestMatch = '';
    var bestPrefix = '';

    for (final entry in prefixCandidates.entries) {
      final namespace = entry.value;
      // Skip empty namespaces to avoid generating invalid prefixes
      if (namespace.isEmpty) continue;

      if (iri.startsWith(namespace) && namespace.length > bestMatch.length) {
        bestMatch = namespace;
        bestPrefix = entry.key;
      }
    }
    if (bestMatch.isEmpty && bestPrefix.isEmpty) {
      // If no match found, return empty prefix and namespace
      return null;
    }
    return (bestPrefix, bestMatch);
  }
}
