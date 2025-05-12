/// RDF Exception Framework
///
/// Provides a comprehensive exception hierarchy for RDF processing, enabling detailed error reporting
/// with source location information for debugging and robust error handling.
///
/// Example usage:
/// ```dart
/// import 'package:rdf_core/src/exceptions/rdf_exception.dart';
/// try {
///   // some RDF operation
/// } catch (e) {
///   if (e is RdfException) print(e);
/// }
/// ```
///
/// See also: [Dart Exception Guidelines](https://dart.dev/guides/libraries/library-tour#exceptions)
library exceptions.base;

/// Base exception class for all RDF-related errors.
///
/// This serves as the root of the exception hierarchy for the RDF library,
/// providing common functionality for all specific exceptions. It captures
/// essential error information including error messages, causes, and source
/// locations.
///
/// Specific exception types in the library extend this base class to provide
/// more targeted error handling for different RDF operations (decoding,
/// encoding, validation, etc.).
///
/// Example:
/// ```dart
/// try {
///   // RDF operation that might fail
/// } catch (e) {
///   if (e is RdfException) {
///     // Handle RDF-specific error with access to detailed information
///     print(e.message);
///     print(e.source);
///   } else {
///     // Handle other types of errors
///   }
/// }
/// ```
class RdfException implements Exception {
  /// Human-readable error message describing the issue
  ///
  /// This message should be clear enough to understand the nature of the error
  /// without requiring access to the source code.
  final String message;

  /// The original error that caused this exception, if any
  ///
  /// When an RDF exception is wrapping another exception (e.g., an I/O error
  /// or a format error from a lower-level library), this property contains
  /// the original exception to maintain the full error chain.
  final Object? cause;

  /// Optional source information where the error occurred
  ///
  /// For syntax errors and similar issues, this provides the exact location
  /// in the document where the problem was detected, facilitating debugging.
  final SourceLocation? source;

  /// Creates a new RDF exception
  ///
  /// Parameters:
  /// - [message]: Required description of the error
  /// - [cause]: Optional underlying cause of this exception
  /// - [source]: Optional location information where the error occurred
  const RdfException(this.message, {this.cause, this.source});

  @override
  String toString() {
    final buffer = StringBuffer('RdfException: $message');

    if (source != null) {
      buffer.write(' at ${source!}');
    }

    if (cause != null) {
      buffer.write('\nCaused by: $cause');
    }

    return buffer.toString();
  }
}

/// Contains information about source location where an error occurred
///
/// This class provides detailed location information for errors in RDF documents,
/// similar to how compilers report errors with file, line, and column information.
/// It helps pinpoint exactly where in a document a problem was detected.
///
/// The location uses 0-based line and column indices internally, but displays
/// them as 1-based in string representations to match common editor conventions.
class SourceLocation {
  /// Line number (0-based) in the source where the error was detected
  ///
  /// Note: This is 0-based for internal consistency, but toString() will
  /// display it as 1-based to match editor conventions.
  final int line;

  /// Column number (0-based) in the source where the error was detected
  ///
  /// Note: This is 0-based for internal consistency, but toString() will
  /// display it as 1-based to match editor conventions.
  final int column;

  /// Optional file path or URL where the error occurred
  ///
  /// Identifies the document containing the error, when available.
  final String? source;

  /// Optional context showing the problematic content
  ///
  /// This can contain a snippet of the document around the error location
  /// to provide context without requiring access to the original document.
  final String? context;

  /// Creates a new source location instance
  ///
  /// Parameters:
  /// - [line]: Required 0-based line number
  /// - [column]: Required 0-based column number
  /// - [source]: Optional file path or URL
  /// - [context]: Optional text snippet showing context
  const SourceLocation({
    required this.line,
    required this.column,
    this.source,
    this.context,
  });

  @override
  String toString() {
    final location = source != null ? '$source:' : '';
    return '$location${line + 1}:${column + 1}${context != null ? ' "$context"' : ''}';
  }
}
