/// Turtle Tokenizer Implementation
///
/// Implements the [TurtleTokenizer] class for lexical analysis of Turtle syntax.
///
/// Example usage:
/// ```dart
/// import 'package:rdf_core/src/turtle/turtle_tokenizer.dart';
/// final tokenizer = TurtleTokenizer(input);
/// final token = tokenizer.nextToken();
/// ```
/// The tokenizer is responsible for:
/// 1. Identifying the basic lexical elements of Turtle (IRIs, literals, etc.)
/// 2. Handling whitespace, comments, and line breaks
/// 3. Providing position information for error reporting
/// 4. Managing escape sequences in strings and IRIs
///
/// See: https://www.w3.org/TR/turtle/ for the Turtle specification.
library turtle_tokenizer;

import 'package:logging/logging.dart';

final _log = Logger("rdf.turtle");

/// Flags for non-standard Turtle parsing behavior.
///
/// These flags allow for more granular control over how relaxed the parser should be
/// when encountering various non-standard Turtle syntax patterns. Each flag represents
/// a specific deviation from the standard Turtle specification.
///
/// Use these flags when parsing real-world Turtle files that don't strictly follow
/// the W3C Turtle specification but are still semantically meaningful.
enum TurtleParsingFlag {
  /// Allows prefixed names to have local names that start with digits.
  /// E.g., allows `schema:3DModel` which is not valid in standard Turtle.
  allowDigitInLocalName,

  /// Allows prefix declarations without a trailing dot.
  /// E.g., allows `@prefix ex: <http://example.com/>`
  allowMissingDotAfterPrefix,

  /// Auto-adds common prefixes (rdf, rdfs, xsd, etc.) when not explicitly defined.
  /// This can help parse documents that use standard prefixes without declaring them.
  autoAddCommonPrefixes,

  /// Allows prefix declarations without the @ symbol.
  /// E.g., allows `prefix ex: <http://example.com/>`
  allowPrefixWithoutAtSign,

  /// Handles missing dots at the end of triple statements more gracefully.
  allowMissingFinalDot,

  /// Allows simple identifiers without colons to be treated as prefixed names.
  /// E.g., allows `abc` to be treated as an IRI that is resolved against the base URI.
  ///
  /// Note: This requires that a base URI is set, either through an @base directive
  /// in the document or provided as the documentUrl parameter when decoding.
  ///
  /// Example:
  /// ```
  /// @base <http://example.org/> .
  /// <http://example.org/subject> a Type .
  /// ```
  /// Here "Type" will be resolved to <http://example.org/Type>
  allowIdentifiersWithoutColon,
}

/// Token types in Turtle syntax.
///
/// Turtle syntax consists of several types of tokens representing the lexical
/// elements of the language. Each value in this enum represents a specific kind
/// of token that can appear in valid Turtle documents.
///
/// Basic structure tokens:
/// - [prefix]: The '@prefix' keyword for namespace prefix declarations
/// - [base]: The '@base' keyword for base IRI declarations
/// - [dot]: The '.' character that terminates statements
/// - [semicolon]: The ';' character for predicates sharing the same subject
/// - [comma]: The ',' character for objects sharing the same subject and predicate
///
/// Term tokens:
/// - [iri]: IRIs enclosed in angle brackets (e.g., <http://example.org/>)
/// - [prefixedName]: Prefixed names (e.g., foaf:name)
/// - [blankNode]: Blank nodes with explicit labels (e.g., _:b1)
/// - [literal]: String literals, possibly with language tags or datatypes
/// - [a]: The 'a' keyword, shorthand for the rdf:type predicate
///
/// Collection tokens:
/// - [openBracket]/[closeBracket]: The `[` and `]` for blank node property lists
/// - [openParen]/[closeParen]: The `(` and `)` for RDF collections (ordered lists)
///
/// Other:
/// - [booleanLiteral]: Boolean literals (e.g., true, false)
/// - [integerLiteral]: Integer literals (e.g., 42, -123)
/// - [decimalLiteral]: Decimal literals (e.g., 3.14, -0.5)
/// - [eof]: End of file marker, indicating the input has been fully consumed
enum TokenType {
  prefix,
  base,
  iri,
  blankNode,
  literal,
  dot,
  semicolon,
  comma,
  openBracket,
  closeBracket,
  openParen,
  closeParen,
  a,
  prefixedName,
  booleanLiteral,
  integerLiteral,
  decimalLiteral,
  eof,
}

/// A token in Turtle syntax.
///
/// Each token represents a distinct lexical element in the Turtle syntax and
/// includes both the token's content and its position in the source document,
/// which is essential for meaningful error reporting.
///
/// Position information is 1-based (the first line and column are numbered 1,
/// not 0) to match standard text editor conventions.
///
/// Examples:
/// ```
/// Token(TokenType.iri, "<http://example.org/foo>", 1, 1)
/// Token(TokenType.prefixedName, "foaf:name", 2, 5)
/// Token(TokenType.literal, "\"Hello\"", 3, 10)
/// ```
class Token {
  /// The type of this token.
  final TokenType type;

  /// The text content of this token.
  final String value;

  /// The line number where this token starts (1-based).
  final int line;

  /// The column number where this token starts (1-based).
  final int column;

  /// Creates a new token with the specified type, value, and position
  ///
  /// Position information should be 1-based (first character is at line 1, column 1).
  Token(this.type, this.value, this.line, this.column);

  @override
  String toString() => 'Token($type, "$value", $line:$column)';
}

/// Tokenizer for Turtle syntax.
///
/// This class breaks down a Turtle document into a sequence of tokens according to
/// the Turtle grammar rules. It implements a lexical analyzer that processes the input
/// character by character and builds meaningful tokens.
///
/// The tokenizer handles:
///
/// - IRIs: `<http://example.org/resource>`
/// - Prefixed names: `ex:resource`
/// - Literals: `"string"`, `"string"@en`, `"3.14"^^xsd:decimal`
/// - Blank nodes: `_:blank1`
/// - Keywords: `a` (shorthand for rdf:type), `@prefix`, `@base`
/// - Punctuation: `.`, `;`, `,`, `[`, `]`, `(`, `)`
/// - Comments: `# This is a comment`
/// - Whitespace and line breaks
///
/// The tokenizer skips whitespace and comments between tokens and provides
/// detailed position information for error reporting.
///
/// Example:
/// ```dart
/// final tokenizer = TurtleTokenizer('''
///   @prefix ex: <http://example.org/> .
///   ex:subject a ex:Type ;
///     ex:predicate "object" .
/// ''');
///
/// Token token;
/// while ((token = tokenizer.nextToken()).type != TokenType.eof) {
///   print(token);
/// }
/// ```
class TurtleTokenizer {
  static final _isDigitRegExp = RegExp(r'[0-9]');
  final String _input;
  int _position = 0;
  int _line = 1;
  int _column = 1;
  final Set<TurtleParsingFlag> _parsingFlags;

  /// Creates a new tokenizer for the given input string.
  ///
  /// The input should be a valid Turtle document or fragment.
  /// All tokens returned by [nextToken] will be derived from this input.
  ///
  /// [parsingFlags] enables a more flexible tokenization for real-world
  /// Turtle files that may not strictly adhere to the specification.
  TurtleTokenizer(this._input, {Set<TurtleParsingFlag> parsingFlags = const {}})
      : _parsingFlags = parsingFlags;

  /// Checks if a specific parsing flag is enabled.
  bool _hasFlag(TurtleParsingFlag flag) => _parsingFlags.contains(flag);

  /// Gets the next token from the input.
  ///
  /// This method is the main entry point for token extraction. It:
  /// 1. Skips any whitespace and comments
  /// 2. Identifies the type of the next token based on the current character
  /// 3. Delegates to specialized parsing methods for complex tokens
  /// 4. Advances the input position past the token
  /// 5. Returns the complete Token with its type, value, and position
  ///
  /// When the end of the input is reached, it returns a token with type
  /// [TokenType.eof]. This makes it convenient to use in a loop that
  /// continues until EOF is encountered.
  ///
  /// Throws [FormatException] if unexpected characters are encountered
  /// or if tokens are malformed (e.g., unclosed string literals).
  ///
  /// Example:
  /// ```dart
  /// Token token;
  /// while ((token = tokenizer.nextToken()).type != TokenType.eof) {
  ///   // Process the token
  /// }
  /// ```
  Token nextToken() {
    _skipWhitespace();

    if (_position >= _input.length) {
      return Token(TokenType.eof, '', _line, _column);
    }

    final char = _input[_position];

    // Handle single character tokens
    switch (char) {
      case '.':
        // Check if this is a decimal point in a number
        if (_position > 0 &&
            _position + 1 < _input.length &&
            _isDigitRegExp.hasMatch(_input[_position - 1]) &&
            _isDigitRegExp.hasMatch(_input[_position + 1])) {
          return _parseDecimalLiteral();
        }
        _position++;
        _column++;
        return Token(TokenType.dot, '.', _line, _column - 1);
      case ';':
        _position++;
        _column++;
        return Token(TokenType.semicolon, ';', _line, _column - 1);
      case ',':
        _position++;
        _column++;
        return Token(TokenType.comma, ',', _line, _column - 1);
      case '[':
        _position++;
        _column++;
        return Token(TokenType.openBracket, '[', _line, _column - 1);
      case ']':
        _position++;
        _column++;
        return Token(TokenType.closeBracket, ']', _line, _column - 1);
      case '(':
        _position++;
        _column++;
        return Token(TokenType.openParen, '(', _line, _column - 1);
      case ')':
        _position++;
        _column++;
        return Token(TokenType.closeParen, ')', _line, _column - 1);
    }

    // Handle @prefix
    if (_startsWith('@prefix')) {
      _position += 7;
      _column += 7;
      return Token(TokenType.prefix, '@prefix', _line, _column - 7);
    }

    // Handle 'prefix' without @ when allowPrefixWithoutAtSign flag is enabled
    if (_hasFlag(TurtleParsingFlag.allowPrefixWithoutAtSign) &&
        _startsWith('prefix ')) {
      _position += 6;
      _column += 6;
      _log.warning(
        'With allowPrefixWithoutAtSign: Found "prefix" without @ at $_line:$_column-6',
      );
      return Token(TokenType.prefix, '@prefix', _line, _column - 6);
    }

    // Handle @base
    if (_startsWith('@base')) {
      _position += 5;
      _column += 5;
      return Token(TokenType.base, '@base', _line, _column - 5);
    }

    // Handle 'base' without @ when allowPrefixWithoutAtSign flag is enabled
    if (_hasFlag(TurtleParsingFlag.allowPrefixWithoutAtSign) &&
        _startsWith('base ')) {
      _position += 4;
      _column += 4;
      _log.warning(
        'With allowPrefixWithoutAtSign: Found "base" without @ at $_line:$_column-4',
      );
      return Token(TokenType.base, '@base', _line, _column - 4);
    }

    // Handle 'a' (shorthand for rdf:type)
    if (_startsWith('a ') ||
        _startsWith('a\n') ||
        _startsWith('a\t') ||
        _startsWith('a;') ||
        _startsWith('a.') ||
        (_position + 1 == _input.length && _input[_position] == 'a')) {
      _position++;
      _column++;
      return Token(TokenType.a, 'a', _line, _column - 1);
    }

    // Handle boolean literals
    if (_startsWith('true ') ||
        _startsWith('true\n') ||
        _startsWith('true\t') ||
        _startsWith('true;') ||
        _startsWith('true.') ||
        (_position + 4 == _input.length &&
            _input.substring(_position, _position + 4) == 'true')) {
      _position += 4; // Skip "true"
      _column += 4;
      return Token(TokenType.booleanLiteral, 'true', _line, _column - 4);
    }

    if (_startsWith('false ') ||
        _startsWith('false\n') ||
        _startsWith('false\t') ||
        _startsWith('false;') ||
        _startsWith('false.') ||
        (_position + 5 == _input.length &&
            _input.substring(_position, _position + 5) == 'false')) {
      _position += 5; // Skip "false"
      _column += 5;
      return Token(TokenType.booleanLiteral, 'false', _line, _column - 5);
    }

    // Handle negative numeric literals
    if (char == '-' &&
        _position + 1 < _input.length &&
        _isDigitRegExp.hasMatch(_input[_position + 1])) {
      // Look ahead to determine if this is a decimal or integer
      int lookAhead = _position + 1; // Skip the minus sign
      bool isDecimal = false;

      while (lookAhead < _input.length &&
          _isDigitRegExp.hasMatch(_input[lookAhead])) {
        lookAhead++;
      }

      if (lookAhead < _input.length && _input[lookAhead] == '.') {
        lookAhead++;
        // Check if there's at least one digit after the decimal point
        if (lookAhead < _input.length &&
            _isDigitRegExp.hasMatch(_input[lookAhead])) {
          isDecimal = true;
        }
      }

      if (isDecimal) {
        return _parseDecimalLiteral();
      } else {
        return _parseIntegerLiteral();
      }
    }

    // Handle numeric literals
    if (_isDigitRegExp.hasMatch(char)) {
      // Look ahead to determine if this is a decimal or integer
      int lookAhead = _position;
      bool isDecimal = false;

      while (lookAhead < _input.length &&
          _isDigitRegExp.hasMatch(_input[lookAhead])) {
        lookAhead++;
      }

      if (lookAhead < _input.length && _input[lookAhead] == '.') {
        lookAhead++;
        // Check if there's at least one digit after the decimal point
        if (lookAhead < _input.length &&
            _isDigitRegExp.hasMatch(_input[lookAhead])) {
          isDecimal = true;
        }
      }

      if (isDecimal) {
        return _parseDecimalLiteral();
      } else {
        return _parseIntegerLiteral();
      }
    }

    // Handle IRIs
    if (char == '<') {
      return _parseIri();
    }

    // Handle blank nodes
    if (char == '_' &&
        _position + 1 < _input.length &&
        _input[_position + 1] == ':') {
      return _parseBlankNode();
    }

    // Handle literals
    if (char == '"') {
      return _parseLiteral();
    }

    // Handle prefixed names
    if (_isNameStartChar(char)) {
      return _parsePrefixedName();
    }

    // In relaxed mode with allowDigitInLocalName, also handle digits at the start as potential prefixed names
    // This is particularly useful for files that mistakenly start prefixed names with digits
    if (_hasFlag(TurtleParsingFlag.allowDigitInLocalName) &&
        _isDigitRegExp.hasMatch(char)) {
      _log.warning(
        'With allowDigitInLocalName: Found digit as first character at $_line:$_column',
      );
      return _parsePrefixedName();
    }

    _log.severe('Unexpected character: $char at $_line:$_column');
    throw FormatException('Unexpected character: $char at $_line:$_column');
  }

  /// Parses an integer literal token.
  ///
  /// Integer literals in Turtle are numbers without a decimal point or exponent.
  /// This method handles parsing integers like "42", "-123", etc.
  ///
  /// Returns a token of type [TokenType.integerLiteral] containing the integer value.
  Token _parseIntegerLiteral() {
    final startLine = _line;
    final startColumn = _column;
    final buffer = StringBuffer();

    // Check for optional minus sign
    if (_position < _input.length && _input[_position] == '-') {
      buffer.write('-');
      _position++;
      _column++;
    }

    // Parse digits
    while (_position < _input.length &&
        _isDigitRegExp.hasMatch(_input[_position])) {
      buffer.write(_input[_position]);
      _position++;
      _column++;
    }

    return Token(
      TokenType.integerLiteral,
      buffer.toString(),
      startLine,
      startColumn,
    );
  }

  /// Parses a decimal literal token.
  ///
  /// Decimal literals in Turtle are numbers with a decimal point.
  /// This method handles parsing decimals like "3.14", "-0.5", etc.
  ///
  /// Returns a token of type [TokenType.decimalLiteral] containing the decimal value.
  Token _parseDecimalLiteral() {
    final startLine = _line;
    final startColumn = _column;
    final buffer = StringBuffer();

    // Check for optional minus sign
    if (_position < _input.length && _input[_position] == '-') {
      buffer.write('-');
      _position++;
      _column++;
    }

    // Parse digits before decimal point
    while (_position < _input.length &&
        _isDigitRegExp.hasMatch(_input[_position])) {
      buffer.write(_input[_position]);
      _position++;
      _column++;
    }

    // Parse decimal point and digits after
    if (_position < _input.length && _input[_position] == '.') {
      buffer.write('.');
      _position++;
      _column++;

      // Parse digits after decimal point
      while (_position < _input.length &&
          _isDigitRegExp.hasMatch(_input[_position])) {
        buffer.write(_input[_position]);
        _position++;
        _column++;
      }
    }

    return Token(
      TokenType.decimalLiteral,
      buffer.toString(),
      startLine,
      startColumn,
    );
  }

  /// Skips whitespace and comments in the input.
  ///
  /// This method advances the current position past:
  /// - Whitespace characters (spaces, tabs, carriage returns)
  /// - Line breaks (adjusting line and column counters)
  /// - Comments (from # to the end of the line)
  ///
  /// After calling this method, the current position will either:
  /// - Be at the start of a meaningful token
  /// - Be at the end of the input (position >= length)
  void _skipWhitespace() {
    while (_position < _input.length) {
      final char = _input[_position];
      if (char == '\n') {
        _line++;
        _column = 1;
        _position++;
      } else if (char == ' ' || char == '\t' || char == '\r') {
        _column++;
        _position++;
      } else if (char == '#') {
        _skipComment();
      } else {
        break;
      }
    }
  }

  /// Skips a comment in the input.
  ///
  /// Comments in Turtle start with # and continue until the end of the line.
  /// This method advances the position to the end of the current line.
  /// Line break handling is left to _skipWhitespace.
  void _skipComment() {
    while (_position < _input.length && _input[_position] != '\n') {
      _position++;
    }
  }

  /// Parses an IRI token.
  ///
  /// IRIs in Turtle are enclosed in angle brackets (<...>).
  /// This method handles:
  /// - The opening and closing angle brackets
  /// - The content between the brackets
  /// - Escape sequences in the IRI (e.g., \u00A9 for ©)
  ///
  /// Example in Turtle:
  /// ```turtle
  /// <http://example.org/resource>
  /// <http://example.org/with\#fragment>
  /// ```
  ///
  /// Returns a token of type [TokenType.iri] containing the complete IRI
  /// including the angle brackets.
  ///
  /// Throws [FormatException] if the IRI is not properly closed.
  Token _parseIri() {
    final startLine = _line;
    final startColumn = _column;

    // Save start position to capture entire IRI including brackets
    final startPos = _position;

    _position++; // Skip opening <
    _column++;

    while (_position < _input.length && _input[_position] != '>') {
      if (_input[_position] == '\\') {
        _position++;
        _column++;
        if (_position < _input.length) {
          _position++;
          _column++;
        }
      } else {
        _position++;
        _column++;
      }
    }

    if (_position >= _input.length) {
      throw FormatException('Unclosed IRI at $startLine:$startColumn');
    }

    _position++; // Skip closing >
    _column++;

    // Extract the entire IRI with angle brackets
    final iri = _input.substring(startPos, _position);

    return Token(TokenType.iri, iri, startLine, startColumn);
  }

  /// Parses a blank node token.
  ///
  /// Blank nodes in Turtle start with _: followed by a name.
  /// They represent anonymous resources that don't need global identifiers.
  ///
  /// Example in Turtle:
  /// ```turtle
  /// _:b1
  /// _:blank123
  /// ```
  ///
  /// Returns a token of type [TokenType.blankNode] containing the complete
  /// blank node identifier.
  Token _parseBlankNode() {
    final startLine = _line;
    final startColumn = _column;
    final buffer = StringBuffer();

    // Skip the _: prefix
    _position += 2;
    _column += 2;
    buffer.write('_:');

    while (_position < _input.length && _isNameChar(_input[_position])) {
      buffer.write(_input[_position]);
      _position++;
      _column++;
    }

    return Token(
      TokenType.blankNode,
      buffer.toString(),
      startLine,
      startColumn,
    );
  }

  /// Parses a literal token.
  ///
  /// Literals in Turtle represent string values and can have several forms:
  /// - Simple strings: "Hello"
  /// - Multi-line strings: """Hello
  ///   World"""
  /// - Language-tagged strings: "Hello"@en
  /// - Typed literals with datatype IRI: "123"^^<http://www.w3.org/2001/XMLSchema#integer>
  /// - Typed literals with prefixed names: "123"^^xsd:integer
  ///
  /// This method handles:
  /// - The opening and closing quotes (both single and triple quotes)
  /// - Escape sequences within the string
  /// - Optional language tags (@lang)
  /// - Optional datatype annotations (^^datatype)
  ///
  /// Returns a token of type [TokenType.literal] containing the complete literal
  /// including quotes, language tag or datatype annotation.
  ///
  /// Throws [FormatException] if the literal is not properly closed.
  Token _parseLiteral() {
    final startLine = _line;
    final startColumn = _column;

    // Save the starting position to capture the entire literal
    final startPos = _position;

    // Check for triple quotes (multi-line literal)
    final isTripleQuoted = _position + 2 < _input.length &&
        _input[_position] == '"' &&
        _input[_position + 1] == '"' &&
        _input[_position + 2] == '"';

    if (isTripleQuoted) {
      // Skip the opening triple quotes
      _position += 3;
      _column += 3;

      // Find the closing triple quotes
      bool foundClosing = false;
      while (_position + 2 <= _input.length) {
        if (_position + 2 < _input.length &&
            _input[_position] == '"' &&
            _input[_position + 1] == '"' &&
            _input[_position + 2] == '"') {
          // Found closing triple quotes
          _position += 3;
          _column += 3;
          foundClosing = true;
          break;
        }

        if (_input[_position] == '\n') {
          _line++;
          _column = 1;
          _position++;
        } else if (_input[_position] == '\\') {
          // Handle escape sequence
          _position++;
          _column++;
          if (_position < _input.length) {
            _position++;
            _column++;
          }
        } else {
          _position++;
          _column++;
        }
      }

      // Check if we reached the end of the input without finding closing quotes
      if (!foundClosing) {
        throw FormatException(
          'Unclosed multi-line literal at $startLine:$startColumn',
        );
      }
    } else {
      // Regular single-line literal with single quotes
      // Skip opening quote and scan to find the closing quote
      _position++; // Skip opening "
      _column++;

      while (_position < _input.length && _input[_position] != '"') {
        if (_input[_position] == '\\') {
          _position++;
          _column++;
          if (_position < _input.length) {
            _position++;
            _column++;
          }
        } else {
          _position++;
          _column++;
        }
      }

      if (_position >= _input.length) {
        throw FormatException('Unclosed literal at $startLine:$startColumn');
      }

      _position++; // Skip closing "
      _column++;
    }

    // Check for language tag or datatype annotation
    if (_position < _input.length) {
      // Language tag
      if (_input[_position] == '@') {
        _position++;
        _column++;
        while (_position < _input.length && _isNameChar(_input[_position])) {
          _position++;
          _column++;
        }
      }
      // Datatype annotation
      else if (_position + 1 < _input.length &&
          _input[_position] == '^' &&
          _input[_position + 1] == '^') {
        _position += 2;
        _column += 2;
        if (_position < _input.length && _input[_position] == '<') {
          // Parse until closing '>'
          while (_position < _input.length && _input[_position] != '>') {
            _position++;
            _column++;
          }
          if (_position < _input.length) {
            _position++; // Skip closing '>'
            _column++;
          }
        }
        // Handle prefixed name datatype (e.g., xsd:integer)
        else if (_position < _input.length &&
            _isNameStartChar(_input[_position])) {
          // Parse prefix and local name
          while (_position < _input.length) {
            if (_isNameChar(_input[_position]) || _input[_position] == ':') {
              _position++;
              _column++;
            } else {
              break;
            }
          }
        }
      }
    }

    // Extract the entire literal with its annotations
    final literal = _input.substring(startPos, _position);

    return Token(TokenType.literal, literal, startLine, startColumn);
  }

  /// Parses a prefixed name token.
  ///
  /// Prefixed names in Turtle consist of:
  /// - An optional prefix (namespace alias)
  /// - A colon separator (:)
  /// - A local name (the part after the colon)
  ///
  /// Examples in Turtle:
  /// ```turtle
  /// foaf:name       # With prefix 'foaf'
  /// :localName      # With default prefix (empty)
  /// ```
  ///
  /// The prefix must have been declared earlier in the document with @prefix.
  /// This method doesn't validate that requirement; it just tokenizes the syntax.
  ///
  /// Returns a token of type [TokenType.prefixedName] containing the
  /// complete prefixed name.
  ///
  /// Throws [FormatException] if the input doesn't contain a colon where required,
  /// particularly in prefix declarations.
  Token _parsePrefixedName() {
    final startLine = _line;
    final startColumn = _column;
    final buffer = StringBuffer();

    // Check for a digit at the start when allowDigitInLocalName is enabled
    final isStartingWithDigit = _position < _input.length &&
        _isDigitRegExp.hasMatch(_input[_position]) &&
        _hasFlag(TurtleParsingFlag.allowDigitInLocalName);

    // Handle empty prefix case (just a colon)
    if (_position < _input.length && _input[_position] == ':') {
      buffer.write(':');
      _position++;
      _column++;
      // If there's a local name after the colon, parse it
      // When allowDigitInLocalName is enabled, also allow local names that start with a digit
      if (_position < _input.length &&
          (_isNameStartChar(_input[_position]) ||
              (_hasFlag(TurtleParsingFlag.allowDigitInLocalName) &&
                  _isDigitRegExp.hasMatch(_input[_position])))) {
        // Parse the local name according to PN_LOCAL grammar
        while (_position < _input.length) {
          final char = _input[_position];
          if (_isLocalNameChar(char) ||
              (_hasFlag(TurtleParsingFlag.allowDigitInLocalName) &&
                  _isDigitRegExp.hasMatch(char))) {
            buffer.write(char);
            _position++;
            _column++;
          } else {
            break;
          }
        }

        // Check if the local name ends with a dot, which is invalid per PN_LOCAL rule
        if (buffer.isNotEmpty && buffer.toString().endsWith('.')) {
          // Remove the trailing dot and backtrack
          final content = buffer.toString();
          buffer.clear();
          buffer.write(content.substring(0, content.length - 1));
          _position--;
          _column--;
        }
      }
      return Token(
        TokenType.prefixedName,
        buffer.toString(),
        startLine,
        startColumn,
      );
    }

    // Save the prefix part to check if we're in a prefix declaration context
    final prefixStart = _position;
    bool foundColon = false;

    // Special handling for names starting with a digit when allowDigitInLocalName is enabled
    if (isStartingWithDigit) {
      // If starting with a digit, add it to the buffer and continue parsing as a name
      buffer.write(_input[_position]);
      _position++;
      _column++;
    }

    while (_position < _input.length) {
      final char = _input[_position];

      if (_isNameChar(char) ||
          (isStartingWithDigit && _isDigitRegExp.hasMatch(char))) {
        buffer.write(char);
        _position++;
        _column++;
      } else if (char == ':') {
        foundColon = true;
        buffer.write(char);
        _position++;
        _column++;
        // Check if there's a local name after the colon
        // When allowDigitInLocalName is enabled, also allow local names that start with a digit
        if (_position < _input.length &&
            (_isNameStartChar(_input[_position]) ||
                (_hasFlag(TurtleParsingFlag.allowDigitInLocalName) &&
                    _isDigitRegExp.hasMatch(_input[_position])))) {
          // Parse the local name according to PN_LOCAL grammar:
          // PN_LOCAL ::= (PN_CHARS_U | ':' | [0-9] | PLX) ((PN_CHARS | '.' | ':' | PLX)* (PN_CHARS | ':' | PLX))?
          while (_position < _input.length) {
            final char = _input[_position];
            if (_isLocalNameChar(char) ||
                (_hasFlag(TurtleParsingFlag.allowDigitInLocalName) &&
                    _isDigitRegExp.hasMatch(char))) {
              buffer.write(char);
              _position++;
              _column++;
            } else {
              break;
            }
          }

          // Check if the local name ends with a dot, which is invalid per PN_LOCAL rule
          if (buffer.isNotEmpty && buffer.toString().endsWith('.')) {
            // Remove the trailing dot and backtrack
            final content = buffer.toString();
            buffer.clear();
            buffer.write(content.substring(0, content.length - 1));
            _position--;
            _column--;
          }
        }
        return Token(
          TokenType.prefixedName,
          buffer.toString(),
          startLine,
          startColumn,
        );
      } else {
        break;
      }
    }

    // Check the context - if we're parsing what appears to be a prefix declaration
    // but didn't find a colon, it's an error
    if (!foundColon) {
      final prefixPart = _input.substring(prefixStart, _position).trim();

      // Look back in the input to see if '@prefix' appears before this token
      int lookBack = prefixStart - 1;
      while (lookBack >= 0 &&
          (_input[lookBack] == ' ' || _input[lookBack] == '\t')) {
        lookBack--;
      }

      // Check if we might be in a prefix declaration context
      if (lookBack >= 7 &&
          (_input.substring(lookBack - 7, lookBack + 1) == '@prefix ' ||
              (_hasFlag(TurtleParsingFlag.allowPrefixWithoutAtSign) &&
                  _input.substring(lookBack - 6, lookBack + 1) == 'prefix '))) {
        _log.severe(
          'Invalid prefix declaration: missing colon after prefix name',
        );
        throw FormatException(
          'Invalid prefix declaration: missing colon after "$prefixPart" at $startLine:$startColumn',
        );
      }

      // In relaxed mode, handle standalone identifiers that might be mistaken for prefixes
      if ((_hasFlag(TurtleParsingFlag.allowIdentifiersWithoutColon))) {
        _log.warning(
          'In relaxed mode: Found identifier without colon: "$prefixPart" at $startLine:$startColumn',
        );
        // Try to convert to a proper prefixed name if possible, or use as is
        return Token(
          TokenType.prefixedName,
          buffer.toString(),
          startLine,
          startColumn,
        );
      } else {
        _log.severe(
          'Invalid prefixed name format without colon: "$prefixPart"',
        );
        throw FormatException(
          'Invalid prefixed name format without colon: "$prefixPart" at $startLine:$startColumn',
        );
      }
    }

    return Token(
      TokenType.prefixedName,
      buffer.toString(),
      startLine,
      startColumn,
    );
  }

  /// Checks if the input at the current position starts with the given prefix.
  ///
  /// This helper method is used to identify multi-character tokens like
  /// '@prefix' and '@base' without advancing the position.
  ///
  /// Returns true if the input string at the current position starts with
  /// the specified prefix, false otherwise.
  bool _startsWith(String prefix) {
    if (_position + prefix.length > _input.length) return false;
    return _input.substring(_position, _position + prefix.length) == prefix;
  }

  /// Checks if a character is valid as the start of a name.
  ///
  /// In Turtle, name start characters are defined by the specification as:
  /// - Letters (a-z, A-Z)
  /// - Underscore (_)
  /// - Colon (:) in some contexts
  ///
  /// This is used for prefixed names and local names.
  ///
  /// Returns true if the character is valid as a name start character,
  /// false otherwise.
  static final _isNameStartCharRegExp = RegExp(r'[a-zA-Z_:]');
  bool _isNameStartChar(String char) => _isNameStartCharRegExp.hasMatch(char);

  // According to Turtle specification PN_CHARS rule:
  // PN_CHARS ::= PN_CHARS_U | '-' | [0-9] | #x00B7 | [#x0300-#x036F] | [#x203F-#x2040]
  // This includes basic alphanumeric plus underscore, hyphen
  static final _isNameCharRegExp = RegExp(r'[a-zA-Z0-9_\-]');

  /// Checks if a character is valid within a name.
  ///
  /// In Turtle, name characters (after the first character) can be:
  /// - Letters (a-z, A-Z)
  /// - Digits (0-9)
  /// - Underscore (_)
  /// - Hyphen (-)
  ///
  /// This is used for the body of prefixed names and local names.
  ///
  /// Returns true if the character is valid within a name, false otherwise.
  bool _isNameChar(String char) => _isNameCharRegExp.hasMatch(char);

  // PN_CHARS | '.' | ':' | PLX
  // For now, we implement basic case: PN_CHARS + '.' + ':'
  static final _isLocalNameCharRegExp = RegExp(r'[a-zA-Z0-9_\-\.\:]');

  /// Checks if a character is valid in a local name part of a prefixed name.
  ///
  /// According to PN_LOCAL rule in Turtle grammar:
  /// PN_LOCAL ::= (PN_CHARS_U | ':' | [0-9] | PLX) ((PN_CHARS | '.' | ':' | PLX)* (PN_CHARS | ':' | PLX))?
  /// This means local names can include dots and colons in the middle.
  bool _isLocalNameChar(String char) => _isLocalNameCharRegExp.hasMatch(char);
}
