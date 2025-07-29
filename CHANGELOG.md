# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **Fragment IRI Rendering Control**: New `renderFragmentsAsPrefixed` option for Turtle encoder
  - Controls how fragment IRIs are rendered in Turtle output (prefixed vs. relative format)
  - When `true` (default): `http://example.org/doc#term` becomes `:term` with `@prefix : <#> .`
  - When `false`: `http://example.org/doc#term` becomes `<#term>` when using base URI
  - Provides flexibility for different RDF serialization preferences and use cases

### Improved

- **Enhanced Encoder Options API**: Added missing `copyWith()` methods for better developer experience
  - `RdfGraphEncoderOptions.copyWith()` for immutable option updates
  - `TurtleEncoderOptions.copyWith()` with full parameter support including new fragment rendering option
  - `JsonLdEncoderOptions.copyWith()` and `NTriplesEncoderOptions.copyWith()` for consistency
  - Enables fluent API patterns and easier configuration management
- **Documentation Updates**: Updated roadmap with better Turtle relative IRI handling plans

## [0.9.11] - 2025-07-24

### Improved
- Removed debugging files
- dart format

## [0.9.10] - 2025-07-24

### Improved

- **Enhanced IRI Compaction Error Handling**: Improved robustness and reliability of namespace prefix handling
  - `IriCompactionResult.compactIri()` now provides guaranteed non-null results with automatic fallback to full IRI format
  - Added helpful warning messages when IRIs cannot be compacted, including suggestions for correct `IriRole` usage  
  - Eliminates potential null pointer exceptions in serializers by ensuring graceful degradation
  - Improved type safety in Turtle and JSON-LD encoders by removing null-handling branches
  - Better handling of `rdf:type` object serialization with proper IRI role context

## [0.9.9] - 2025-07-23

### Added

- **Extension API for Third-Party Codec Implementers**: New `rdf_core_extend.dart` library opens internal APIs
  - **BREAKING THE ENCAPSULATION BARRIER**: Exposes previously internal utilities for external codec developers
  - Makes `relativizeIri` and `resolveIri` functions available to libraries like `rdf_xml`.
  - Provides public access to the `IriCompaction` system used internally by Turtle and JSON-LD encoders
  - Enables external codecs to achieve the same level of namespace handling and IRI processing
  - Includes comprehensive documentation and examples for building production-quality RDF serialization formats
  - **Strategic API Decision**: Allows ecosystem growth while maintaining internal consistency across all formats

### Changed

- **IRI Compaction System Refactoring**: Major improvements to namespace and prefix handling
  - Moved `IriCompaction` from `lib/src/vocab/` to `lib/src/` for better organization
  - Added `IriRole.type` enum value for proper handling of `rdf:type` object IRIs
  - Replaced boolean flags with type-safe `AllowedCompactionTypes` configuration
  - `IriCompaction` constructor now accepts configurable local name validation function
  - Enhanced type safety with sealed `CompactIri` classes and pattern matching
  - Both Turtle and JSON-LD encoders now use unified compaction logic
  - Improved handling of `rdf:type` objects in serializers for semantic accuracy

## [0.9.8] - 2025-07-23

### Added

- **IRI Utilities**: New `iri_util.dart` library providing standardized IRI relativization and resolution
  - `relativizeIri()` function converts absolute IRIs to relative form when possible  
  - `resolveIri()` function resolves relative IRIs against base URIs with RFC 3986 compliance
  - Ensures roundtrip consistency between relativization and resolution operations
  - Handles edge cases including malformed IRIs, international characters, and various URI schemes
  - Used internally by serializers for consistent base URI handling

- **IRI Compaction System**: New centralized prefix management and IRI compaction infrastructure
  - `IriCompaction` class provides unified logic for namespace prefix extraction and generation
  - Shared between Turtle and JSON-LD encoders for consistent behavior
  - Automatic prefix generation for unknown namespaces with proper RDF delimiter validation  
  - Smart handling of overlapping prefixes (selects most specific match)
  - Validates local name compliance with format-specific requirements

### Enhanced

- **TurtleEncoder**: Major improvements to prefix handling and base URI support
  - Added `includeBaseDeclaration` option to control `@base` directive output
  - Improved automatic prefix generation with validation of numeric local names
  - Better handling of relative IRIs when base URI is provided
  - Enhanced validation prevents generation of invalid Turtle syntax
  - Predicates now always use prefixes or full IRIs (never relative IRIs for better compliance)

- **JsonLdEncoder**: Enhanced context generation and base URI handling  
  - Added `includeBaseDeclaration` option for `@base` in JSON-LD context
  - Improved automatic prefix generation with shared logic from IRI compaction system
  - Better relative IRI handling in JSON-LD objects
  - Enhanced `@type` serialization (now outputs compact IRI strings instead of `@id` objects)
  - More efficient namespace detection and context minimization

- **JsonLdDecoder**: Improved IRI resolution and context handling
  - Better relative IRI resolution using centralized `resolveIri()` function
  - Enhanced context processing for prefix expansion
  - More robust handling of base URI resolution edge cases

- **TurtleDecoder**: Enhanced IRI resolution with centralized utilities
  - Uses new `resolveIri()` function for consistent relative IRI handling
  - Better error messages for missing base URI scenarios
  - Improved RFC 3986 compliance for IRI resolution

### Changed

- **RdfNamespaceMappings**: Enhanced validation and local name checking
  - Added `isValidLocalPart()` method for validating local name components
  - Better handling of numeric local names and special characters
  - Improved validation prevents generation of invalid namespace prefixes

### Fixed

- **Cross-format consistency**: Both Turtle and JSON-LD now use identical prefix generation logic
- **Base URI handling**: Consistent relative IRI resolution across all decoders and encoders
- **Prefix conflicts**: Better detection and handling of overlapping namespace prefixes
- **Test compatibility**: Updated test expectations to reflect improved prefix generation behavior

## [0.9.7] - 2025-07-18

### Fixed
- Formatting

## [0.9.6] - 2025-07-18

### Fixed

- **NTriplesDecoder**: Improved blank node identity consistency during parsing
  - Blank nodes with the same label (e.g., `_:node1`) now map to identical `BlankNodeTerm` instances throughout the document
  - Maintains proper RDF semantics where blank node labels within a document scope refer to the same resource
  - Uses efficient label-to-instance mapping to ensure reference identity consistency
  - Critical for applications that rely on blank node identity for data integrity and graph operations

- **NTriplesEncoder**: Implemented proper blank node labeling with sequential numbering
  - Blank nodes now receive consistent, sequential labels (b0, b1, b2, etc.) following N-Triples best practices
  - Maintains stable mapping of `BlankNodeTerm` instances to labels throughout serialization
  - Replaced non-deterministic hash-based labeling with predictable counter-based approach
  - Ensures same blank node instance always serializes to the same label across multiple references
  - Added comprehensive test coverage for blank node consistency and sequential labeling

## [0.9.5] - 2025-07-16

### Changed
- **RdfGraph** accepts an Iterable now for Triples

## [0.9.4] - 2025-07-09

### Added

- **RdfGraph**: Added `without(RdfGraph other)` method for graph subtraction operations
  - Enables removing all triples from another graph to compute graph differences
  - Useful for removing knowledge subsets, undoing merge operations, and comparing graph versions
  - Returns a new immutable graph instance with specified triples removed

- **RdfGraph**: Added `withoutTriples(Iterable<Triple> triples)` method for bulk triple removal
  - Performs set subtraction to remove multiple triples in a single operation
  - Supports removing collections of triples based on exact equality matching
  - Optimized for removing temporary working sets or outdated statements

### Changed

- **RdfGraph**: `merge(RdfGraph other)` and `withTriples(Iterable<Triple> triples)` behavior updated
  - Now automatically remove duplicate triples to enforce mathematical set semantics
  - **BREAKING**: Triple ordering is no longer preserved in the resulting graph
  - Aligns with RDF specification that treats graphs as sets rather than ordered collections
  - Improves performance by eliminating redundant triple storage

### Enhanced

- **Documentation**: Comprehensive API documentation added for new graph subtraction methods
  - Added detailed method descriptions, parameter documentation, and usage examples
  - Included performance considerations and common use case scenarios
  - Enhanced code examples showing practical applications in RDF data management
  - Updated documentation for `merge` and `withTriples` to reflect new deduplication behavior

## [0.9.3] 2025-06-24

### Fixed

- **TurtleDecoder**: Fixed parsing of prefixed names with colons in local parts
  - Corrected prefixed name splitting to only split on the first colon, allowing colons in local names per W3C Turtle specification
  - Updated parser to properly handle IRIs like `prefix:local:name` which are valid according to PN_LOCAL grammar

- **TurtleTokenizer**: Enhanced local name validation according to PN_LOCAL specification
  - Implemented proper PN_LOCAL grammar validation that prevents invalid patterns like dots at the end of local names
  - Added validation to reject local names ending with dots (e.g., `author.me` → invalid)
  - Added validation to reject local names starting with dots or hyphens
  - Added validation to reject double dots and hyphen-dot patterns
  - Improved tokenizer to properly handle dots in the middle of valid local names
  - Fixed tokenizer backtracking when invalid trailing dots are detected

- **RdfNamespaceMappings**: Enhanced IRI validation for prefix generation
  - Added comprehensive `_isValidPnLocal` validation function that enforces W3C Turtle PN_LOCAL rules
  - Improved `extractNamespaceAndLocalPart` to reject IRIs with invalid local name patterns
  - Added validation for domain-like suffixes and percent encoding in local names
  - Performance optimization: pre-compiled regex patterns as static final fields to avoid repeated compilation

### Enhanced

- **Performance**: Optimized regex usage in TurtleTokenizer by using static final compiled patterns
  - Replaced inline `RegExp(r'[0-9]')` calls with pre-compiled `_isDigitRegExp`
  - Replaced inline character class regexes with static compiled patterns for better performance

### Added

- **Testing**: Added comprehensive test suite for Turtle local name validation
  - Tests for invalid PN_LOCAL patterns (dots at end, double dots, hyphen-dot combinations)
  - Tests for valid PN_LOCAL patterns with dots in the middle
  - Validation that invalid local names are serialized as full IRIs instead of using prefix notation

## [0.9.2] - 2025-05-15

### Fixed

- Turtle encoding of IRIs that contain url escape (e.g. %20) must not use prefixes

## [0.9.1] - 2025-05-15

### Changed

- **TurtleEncoder**: Fixed prefix and relative URI handling with base URI
  - Improved handling of IRIs with baseUri to correctly prioritize relative IRIs for subjects/objects
  - Always use prefixes for predicates, even when they fall under the base URI
  - Apply prefixes only to subjects/objects when their namespace is longer than the base URI
  - Fixed issue where base URI namespaces were sometimes incorrectly used as prefixes

- **TurtleEncoder**: Improved handling of local names that start with a digit
  - Local names that start with a digit are now consistently serialized as full IRIs rather than using prefix notation by default
  - This behavior can be configured through the `useNumericLocalNames` option in `TurtleEncoderOptions`
  - Fixed internal parameter consistency to ensure proper serialization of IRIs with numeric local names regardless of prefix availability

- **RdfNamespaceMappings**: Improved prefix generation for URIs with hyphens
  - Changed prefix generation strategy to use initials for components with hyphens (e.g., "test-complex-ontology" → "tco")
  - Ensures compliance with RDF specifications that prohibit hyphens in prefixes
  - Makes prefix generation consistent between domain names and path components with hyphens
  - Added comprehensive tests for hyphen handling in prefix generation

## [0.9.0] - 2025-05-14

### Breaking Changes

- **RdfCore API**: Changed signature for codec retrieval
  - Modified how codecs are accessed and configured in the RdfCore class
  - Users who directly access or modify codecs will need to update their code

- **Codec Architecture**: Enhanced options support
  - `RdfGraphCodec`, `RdfGraphEncoder`, and `RdfGraphDecoder` now support distinct `RdfGraphEncoderOptions` and `RdfGraphDecoderOptions`
  - All codec implementations must now properly handle these options

### Added

- **TurtleEncoder**: Added support for automatic prefix generation
  - New `generateMissingPrefixes` option in `TurtleEncoderOptions` (enabled by default)
  - The encoder now automatically generates meaningful prefixes for IRIs that don't match existing prefixes
  - Reuses generated prefixes consistently within the same serialization

### Enhanced

- Documentation was greatly enhanced for all exported classes

- **RdfNamespaceMappings**: Added static utility method for namespace manipulation
  - New public static method `extractNamespaceAndLocalPart` for splitting IRIs into namespace and local part
  - Can be used by clients to implement custom namespace-aware functionality

- **TurtleEncoder**: Improved handling of base URIs and relative IRIs
  - Properly writes base directive in Turtle output when baseUri is provided
  - Correctly converts absolute IRIs to relative IRIs when they start with the base URI
  - Ensures no prefix generation for IRIs that should be serialized as relative paths


## [0.8.2] - 2025-05-13

### Fixed

- **AutoDetectingGraphCodec**: Improved handling of codec detection failures
  - Fixed implementation to properly delegate to registry.detectGraphCodec
  - Modified AutoDetectingGraphDecoder to try all registered codecs in sequence when auto-detection fails
  - Corrected supportedMimeTypes to use the default codec's supported types
- **Turtle Encoder**: Enhanced relative URI support
  - Added proper handling of relative URIs when baseUri is provided
  - Improved base URI handling in the Turtle output format
- **Exception Handling**: Updated tests to handle both FormatException and custom exception types:
  - Modified tests to accept RdfSyntaxException, RdfDecoderException in addition to FormatException
  - Fixed encoder comparison to check for runtimeType equality instead of instance identity

## [0.8.1] - 2025-05-13

### Breaking Changes - DO NOT USE 0.8.0 please

- **API Refactoring**: In preparation for RDF 1.1 Dataset support:
  - Renamed `RdfCodec` → `RdfGraphCodec`
  - Renamed `RdfEncoder` → `RdfGraphEncoder`
  - Renamed `RdfDecoder` → `RdfGraphDecoder`


## [0.8.0] - 2025-05-12

### Breaking Changes

- **API Refactoring**: Changed terminology to align with dart:convert standards
  - Renamed `parse` → `decode`
  - Renamed `serialize` → `encode`
  - Renamed `RdfFormat` → `RdfCodec`
  - Renamed `withStandardFormats` → `withStandardCodecs`
  - Renamed `withFormats` → `withCodecs`

### Added

- Added `additionalCodecs` parameter to `withStandardCodecs` factory constructor
- Added global convenience variables (`turtle`, `jsonld`, `ntriples`, `rdf`) for easier API usage
- Improved documentation for registry access through the `registry` property

## [0.7.6] - 2025-05-08

### Added

- RdfNamespaceMappings can now generate a prefix automatically if there was no matching prefix found

### Fixed

- IriTerm used to be case insensitive in equals, but that is actually wrong - for example: `https://schema.org/Datatype != https://schema.org/datatype` !

## [0.7.5] - 2025-05-07

### Changed

- Another turtle tweak: suppress duplicate objects in multivalue predicates

## [0.7.4] - 2025-05-07

### Changed

- Better sorting of turtle output

## [0.7.3] - 2025-05-07

### Changed

- Removed unused code

## [0.7.2] - 2025-05-07

### Added

- Added additional well-known namespaces to standard mappings:
  - Added geo (http://www.w3.org/2003/01/geo/wgs84_pos#)
  - Added contact (http://www.w3.org/2000/10/swap/pim/contact#)
  - Added time (http://www.w3.org/2006/time#)
  - Added vs (http://www.w3.org/2003/06/sw-vocab-status/ns#)
  - Added dcmitype (http://purl.org/dc/dcmitype/)
  - Added void (http://rdfs.org/ns/void#)
  - Added prov (http://www.w3.org/ns/prov#)
  - Added gr (http://purl.org/goodrelations/v1#)

### Changed

- Enhanced Turtle serialization for improved readability:
  - Implemented inline blank node serialization for nodes referenced exactly once
  - Added support for nested inline blank nodes in square bracket notation
  - Added proper whitespace formatting with double line breaks between subject groups
  - Optimized collection serialization to work with inline blank nodes
- Added linting configuration using package:lints/core.yaml
- Improved code quality with lint fixes and optimized Dart idioms

## [0.7.1] - 2025-05-06

### Changed

- `Triple`, `IriTerm`, `BlankNodeTerm` and `LiteralTerm` classes now output in n-triple style in `.toString()` for better readability of debug output.
- Included information about json-ld in README and homepage.

## [0.7.0] - 2025-05-05

### Added

- Added support for N-Triples format, including parser and serializer implementations
  - Implemented N-Triples as per W3C RDF 1.1 N-Triples specification
  - Added proper escaping and validation for N-Triples syntax
  - Integrated N-Triples format into the standard formats registry
  - Available via MIME type 'application/n-triples' and file extension '.nt'

## [0.6.10] - 2025-05-05

### Added

- Added new factory methods `LiteralTerm.integer()`, `LiteralTerm.decimal()`, and `LiteralTerm.boolean()` for more concise and type-safe creation of common literal types.
- Updated TurtleParser to use these specialized factory methods for literal values.
- Enhanced TurtleSerializer to use native syntax for integer, decimal and boolean literals, resulting in more idiomatic and concise Turtle output.
- Enhanced TurtleSerializer to use native syntax for lists (aka rdf collections: `ex:Person1 ex:someProperty ("foo" "bar" "blub");`) and sets (aka multiple triple per subject/predicate pair: `ex:Person1 ex:someProperty "foo", "bar", "blub";`).


## [0.6.9] - 2025-05-02

### Fixed

- Export exceptions

## [0.6.8] - 2025-05-02

### Fixed

- Added back path and yaml to dev dependencies

## [0.6.7] - 2025-05-02

### Fixed

- More dependency cleanups

## [0.6.6] - 2025-05-02

### Fixed

- Fixed imports

## [0.6.5] - 2025-05-02

### Fixed

- TurtleFormat and JsonLdFormat should have been exported
- unused http dependency was removed

## [0.6.4] - 2025-05-02

### Fixed

- Fixed tests to use relative paths instead of absolute paths for better portability
- Improved examples for handling broken Turtle syntax

## [0.6.3] - 2025-05-02

### Added

- Enhanced Turtle parsing flexibility with configurable parsing flags in TurtleTokenizer
  - Added `TurtleParsingFlag` enum with options for handling non-standard Turtle syntax
  - Implemented support for digits in local names (`allowDigitInLocalName`)
  - Added support for missing dots after prefix declarations (`allowMissingDotAfterPrefix`)
  - Implemented auto-addition of common prefixes (`autoAddCommonPrefixes`)
  - Added support for prefix declarations without @ symbol (`allowPrefixWithoutAtSign`)
  - Improved handling of missing final dots (`allowMissingFinalDot`)
  - Implemented support for identifiers without colons (`allowIdentifiersWithoutColon`)
- Improved error reporting with detailed position information and diagnostics
- Added comprehensive logging to help diagnose parsing issues in real-world Turtle files

### Changed

- Refactored TurtleTokenizer for better maintainability and modularity
- Improved documentation with practical examples of non-standard Turtle syntax handling

### Fixed

- Made Turtle parser more robust when processing real-world datasets with syntax variations
- Enhanced error messages to be more informative for debugging parsing issues

## [0.6.2] - 2025-05-01

### Fixed

- Important fix: build.yaml should not have been committed, it breaks the build of user projects

## [0.6.1] - 2025-05-01

### Changed

- Removed a deprecated annotation that was no longer needed after the vocabulary cleanup

## [0.6.0] - 2025-05-01

### Removed

- **BREAKING CHANGE**: Removed all deprecated vocabulary classes from the vocab directory
  - Removed all previously deprecated vocabulary classes (SchemaProperties, SchemaTypes, SchemaPersonProperties, etc.)
  - Users should now use direct IriTerm instances instead of vocabulary classes
  - Example: replace `SchemaProperties.name` with `IriTerm('https://schema.org/name')`
- Updated examples to use direct IriTerm instances rather than vocabulary constants

### Added

- Improved documentation around IriTerm usage patterns
- Added more comprehensive test coverage for core RDF functionality
- Support for multiline strings in turtle files

## [0.5.1] - 2025-04-30

### Fixed

- Fixed release script to correctly parse the changelog format with square brackets
- Added missing development dependencies required for the release tooling

## [0.5.0] - 2025-04-30

- **BREAKING CHANGE**: Marked all vocabulary classes as deprecated
  - Added `@deprecated` annotation to all classes in vocabulary modules (acl, dc, dc_terms, foaf, ldp, etc.)
  - Classes will be removed in a future release due to API design concerns
  - Users should migrate to the upcoming new vocabulary API
- Improved code documentation
- Enhanced developer warnings for approaching breaking changes

## [0.4.0] - 2025-04-29

- **BREAKING CHANGE**: Reorganized API structure for better modularity and usability
- Added `RdfNamespaceMappings` for improved namespace handling
- Enhanced serializers to support custom namespace mappings
- Improved documentation across the codebase
- Updated API documentation to reflect new structure

## 0.3.1

- Extended Schema.org vocabulary with postal address support
  - Added `PostalAddress`, `ContactPoint`, and `Country` classes
  - Added `SchemaAddressProperties` for complete address modeling
  - Added properties for street address, locality, region, postal code, country, etc.
- Added comprehensive tests for new postal address components
- Added example demonstrating postal address usage with Schema.org vocabulary

## 0.3.0

- Enhanced blank node handling in RDF serialization and parsing
- Refactored IriTerm usage with prevalidated constructor and improved validation logic
- Refactored RDF Core Vocabulary: replaced constants with vocabulary modules
- Added RDF vocabularies for RDFS, Schema.org, SKOS, Solid, and vCard
- Improved documentation and consistency across RDF vocabularies
- Added comprehensive tests for RDF exception handling and parsing
- Enhanced test coverage for TurtleTokenizer and JsonLdFormat functionality
- Fixed edge cases in blank node handling
- Improved test assertions and documentation for various RDF vocabularies

## 0.2.0

- Numerous improvements and new features since 0.1.2.
- See commit history for details on all enhancements and fixes.

## 0.1.2

- Cleaned up all library names for consistency (removed rdf_core. prefix, now use simple names like `exceptions.base`).
- Minor formatting and style improvements in core files.
- No breaking changes; all public APIs remain backward compatible.

## 0.1.1

- Example and documentation now consistently use canonical RDF vocabularies (e.g., http://xmlns.com/foaf/0.1/) with http://, not https://.
- Turtle and JSON-LD serializers automatically warn if non-canonical (https) namespaces are used when canonical (http) is available.
- Added documentation and comments on best practices for prefixes and vocabularies.
- Improved prefix handling and static analysis compliance.
- Added and refined tests for prefix usage and serialization correctness.

## 0.1.0

- Initial release of rdf_core: type-safe, extensible Dart library for RDF data manipulation.
- Implements RDF graph, triple, term, and serialization/parsing for Turtle and JSON-LD.
- Plugin architecture for formats and adapters.
- Comprehensive test coverage.
