/// # RDF Core Extension API
///
/// This library provides extension points for building custom RDF codecs
/// and tools that integrate with rdf_core.
///
/// **For implementers only** - if you're working with RDF data,
/// use `package:rdf_core/rdf_core.dart` instead.
///
/// ## Target Audience
///
/// This API is designed for:
/// - Developers implementing custom RDF serialization formats
/// - Library authors building RDF processing tools
/// - Advanced users needing low-level IRI and namespace manipulation
/// - Codec implementers extending rdf_core with new formats
///
/// ## What's Included
///
/// ### IRI Processing Utilities
/// - [relativizeIri] - Convert absolute IRIs to relative form (RFC 3986 compliant)
/// - [resolveIri] - Resolve relative IRIs against base URIs
/// - [BaseIriRequiredException] - Exception for missing base URI scenarios
///
/// ### Namespace and Prefix Management
/// - [IriCompaction] - Unified prefix generation and IRI compaction logic
/// - [IriCompactionResult] - Results containing prefixes and compacted IRIs
/// - [IriRole] - Enum for different IRI usage contexts (subject, predicate, etc.)
/// - [CompactIri] and its variants - Type-safe IRI compaction results
///
/// ### Namespace Utilities
/// - [RdfNamespaceMappings] - Standard namespace prefix mappings and generation
///
/// ## Key Features
///
/// ### RFC 3986 Compliant IRI Processing
/// The IRI utilities ensure roundtrip consistency: `resolveIri(relativizeIri(iri, base), base)`
/// will always return the original IRI.
///
/// ### Shared Compaction Logic
/// Both Turtle and JSON-LD encoders use the same [IriCompaction] system,
/// ensuring consistent prefix generation and namespace handling across formats.
///
/// ### Automatic Prefix Generation
/// The system can automatically generate meaningful prefixes for unknown
/// namespaces while respecting RDF namespace delimiter conventions.
///
/// ## Example: Custom Codec Implementation
///
/// ```dart
/// import 'package:rdf_core/rdf_core.dart';
/// import 'package:rdf_core/rdf_core_extend.dart';
///
/// class MyCustomEncoder extends RdfGraphEncoder {
///   final RdfNamespaceMappings _namespaceMappings;
///   late final IriCompaction _iriCompaction;
///
///   MyCustomEncoder({RdfNamespaceMappings? namespaceMappings})
///       : _namespaceMappings = namespaceMappings ?? RdfNamespaceMappings() {
///     _iriCompaction = IriCompaction(
///       _namespaceMappings,
///       IriCompactionSettings(
///         generateMissingPrefixes: true,
///         useNumericLocalNames: false,
///         allowRelativeIriForPredicate: false,
///         specialPredicates: {Rdf.type},
///         specialDatatypes: {Xsd.string, Xsd.integer},
///       ),
///     );
///   }
///
///   @override
///   String convert(RdfGraph graph, {String? baseUri}) {
///     // Use the IRI compaction system
///     final compactionResult = _iriCompaction.compactAllIris(
///       graph,
///       {}, // custom prefixes
///       baseUri: baseUri,
///     );
///
///     final buffer = StringBuffer();
///
///     // Write namespace declarations
///     for (final entry in compactionResult.prefixes.entries) {
///       buffer.writeln('NAMESPACE ${entry.key}: <${entry.value}>');
///     }
///
///     // Process triples using compacted IRIs
///     for (final triple in graph.triples) {
///       final subject = _renderTerm(triple.subject, IriRole.subject, compactionResult, baseUri);
///       final predicate = _renderTerm(triple.predicate, IriRole.predicate, compactionResult, baseUri);
///       final object = _renderTerm(triple.object, IriRole.object, compactionResult, baseUri);
///       buffer.writeln('$subject $predicate $object .');
///     }
///
///     return buffer.toString();
///   }
///
///   String _renderTerm(RdfTerm term, IriRole role, IriCompactionResult compaction, String? baseUri) {
///     switch (term) {
///       case IriTerm iri:
///         final compacted = compaction.compactIri(iri, role);
///         return switch (compacted) {
///           PrefixedIri prefixed => prefixed.colonSeparated,
///           RelativeIri relative => '<${relative.relative}>',
///           FullIri full => '<${full.iri}>',
///           SpecialIri special => '<<special:${special.iri.iri}>>',
///           null => '<${iri.iri}>',
///         };
///       case BlankNodeTerm blankNode:
///         return '_:b${blankNode.hashCode.abs()}';
///       case LiteralTerm literal:
///         return '"${literal.value}"';
///     }
///   }
///
///   @override
///   RdfGraphEncoder withOptions(RdfGraphEncoderOptions options) => this;
/// }
/// ```
///
/// ## Example: IRI Utilities Usage
///
/// ```dart
/// import 'package:rdf_core/rdf_core_extend.dart';
///
/// // Relativize IRIs for compact serialization
/// final baseUri = 'http://example.org/data/';
/// final absoluteIri = 'http://example.org/data/person/john';
/// final relative = relativizeIri(absoluteIri, baseUri); // Returns: 'person/john'
///
/// // Resolve relative IRIs during parsing
/// final resolvedBack = resolveIri(relative, baseUri); // Returns original IRI
/// assert(resolvedBack == absoluteIri);
///
/// // Handle base URI requirements
/// try {
///   resolveIri('relative/path', null);
/// } on BaseIriRequiredException catch (e) {
///   print('Cannot resolve ${e.relativeUri} without base URI');
/// }
/// ```
///
/// ## Stability and Versioning
///
/// This extension API may evolve more rapidly than the main rdf_core API
/// as internal needs change. While we aim for stability, implementers should
/// be prepared for occasional breaking changes in minor versions.
///
/// For the most stable API, use the high-level interfaces in the main
/// `rdf_core` library.
///
/// ## See Also
///
/// - Main library: `package:rdf_core/rdf_core.dart`
/// - Built-in codec implementations in `lib/src/turtle/` and `lib/src/jsonld/`
/// - RFC 3986 (URI Generic Syntax): https://tools.ietf.org/html/rfc3986
/// - RDF concepts: https://www.w3.org/TR/rdf-concepts/
library rdf_core_extend;

// Export essential codec implementation tools
export 'src/iri_util.dart';
export 'src/iri_compaction.dart';
export 'src/vocab/namespaces.dart';

// For vocabularies and common RDF terms please use rdf_vocabularies package
