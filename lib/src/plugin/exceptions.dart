/// Exception thrown when an attempt is made to use an unsupported codec
///
/// This exception is thrown when:
/// - A encoder is requested for an unregistered MIME type
/// - No codecs are registered when a serializer is requested
/// - Auto-detection fails to identify a usable codec for parsing
class CodecNotSupportedException implements Exception {
  /// Error message describing the problem
  final String message;

  /// Creates a new format not supported exception
  ///
  /// The [message] parameter contains a description of why the format is not supported.
  CodecNotSupportedException(this.message);

  @override
  String toString() => 'CodecNotSupportedException: $message';
}
