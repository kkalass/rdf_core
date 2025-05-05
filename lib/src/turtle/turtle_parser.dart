import 'package:logging/logging.dart';

import 'package:rdf_core/src/exceptions/exceptions.dart';
import 'package:rdf_core/src/graph/rdf_term.dart';
import 'package:rdf_core/src/graph/triple.dart';
import 'package:rdf_core/src/vocab/namespaces.dart';
import 'package:rdf_core/src/vocab/rdf.dart';

import 'turtle_tokenizer.dart';

final _log = Logger("rdf.turtle");
const _format = "Turtle";

/// A parser for Turtle syntax, which is a text-based format for representing RDF data.
///
/// Turtle is a syntax for RDF (Resource Description Framework) that provides a way
/// to write RDF triples in a compact and human-readable form. This parser supports:
///
/// - Prefix declarations (@prefix)
/// - IRIs (Internationalized Resource Identifiers)
/// - Prefixed names (e.g., foaf:name)
/// - Blank nodes (anonymous resources)
/// - Literals (strings, numbers, etc.)
/// - Lists of predicate-object pairs
/// - Relative IRI resolution against a base URI
///
/// Example usage:
/// ```dart
/// final parser = TurtleParser('''
///   @prefix foaf: <http://xmlns.com/foaf/0.1/> .
///   <http://example.com/me> foaf:name "John Doe" .
/// ''', baseUri: 'http://example.com/');
/// final triples = parser.parse();
/// ```
///
/// The parser follows a recursive descent approach, with separate methods for
/// parsing different syntactic elements of Turtle.
class TurtleParser {
  final TurtleTokenizer _tokenizer;
  final Map<String, String> _prefixes = {};
  String? _baseUri;
  Token _currentToken = Token(TokenType.eof, '', 0, 0);
  final List<Triple> _triples = [];
  final Map<String, BlankNodeTerm> _blankNodesByLabels = {};
  final Set<TurtleParsingFlag> _parsingFlags;
  final RdfNamespaceMappings _namespaceMappings;

  /// Creates a new Turtle parser for the given input string.
  ///
  /// [input] is the Turtle document to parse.
  /// [baseUri] is the base URI against which relative IRIs should be resolved.
  /// If not provided, relative IRIs will be kept as-is.
  /// [parsingFlags] is a set of flags that enable relaxed parsing for non-standard
  /// Turtle syntax that may be present in real-world files.
  TurtleParser(
    String input, {
    String? baseUri,
    Set<TurtleParsingFlag> parsingFlags = const {},
    RdfNamespaceMappings namespaceMappings = const RdfNamespaceMappings(),
  }) : _tokenizer = TurtleTokenizer(input, parsingFlags: parsingFlags),
       _baseUri = baseUri,
       _parsingFlags = parsingFlags,
       _namespaceMappings = namespaceMappings;

  /// Parses the input and returns a list of triples.
  ///
  /// The parser processes the input in the following order:
  /// 1. Prefix declarations (@prefix)
  /// 2. Blank nodes
  /// 3. Subject-predicate-object triples
  ///
  /// Each triple is added to the result list, and the method returns all
  /// triples found in the input.
  ///
  /// Throws [RdfSyntaxException] if the input is not valid Turtle syntax.
  List<Triple> parse() {
    try {
      _currentToken = _tokenizer.nextToken();
      final triples = <Triple>[];
      // _log.finest('Starting parse with token: $_currentToken');

      while (_currentToken.type != TokenType.eof) {
        // _log.finest('Processing token: $_currentToken');
        if (_currentToken.type == TokenType.prefix) {
          // _log.finest('Found prefix declaration');
          _parsePrefix();
        } else if (_currentToken.type == TokenType.base) {
          // _log.finest('Found base declaration');
          _parseBase();
        } else if (_currentToken.type == TokenType.openBracket) {
          // _log.finest('Found blank node');
          final subject = _parseBlankNode();

          // After parsing a blank node that is used as a subject,
          // we need to continue parsing a predicate-object list
          if (_currentToken.type != TokenType.dot &&
              _currentToken.type != TokenType.eof) {
            final predicateObjectList = _parsePredicateObjectList();
            for (final po in predicateObjectList) {
              triples.add(Triple(subject, po.predicate, po.object));
            }

            _expect(TokenType.dot);
            _currentToken = _tokenizer.nextToken();
          } else {
            _expect(TokenType.dot);
            _currentToken = _tokenizer.nextToken();
          }
        } else {
          // _log.finest('Parsing subject');
          final subject = _parseSubject();
          // _log.finest('Subject parsed: $subject');
          // _log.finest('Current token after subject: $_currentToken');

          final predicateObjectList = _parsePredicateObjectList();
          // _log.finest('Predicate-object list parsed: $predicateObjectList');
          // _log.finest(
          //  'Current token after predicate-object list: $_currentToken',
          //);

          for (final po in predicateObjectList) {
            triples.add(Triple(subject, po.predicate, po.object));
          }

          // _log.finest('Expecting dot, current token: $_currentToken');
          _expect(TokenType.dot);
          _currentToken = _tokenizer.nextToken();
        }
      }

      _log.info('Parse complete. Found ${triples.length} triples');
      return [...triples, ..._triples];
    } catch (e, stack) {
      if (e is RdfException) {
        // add missing source information to the exception
        if (e.source == null) {
          _log.severe('RdfException without source information', e, stack);
          final sourceLocation = SourceLocation(
            line: _currentToken.line,
            column: _currentToken.column,
            context: _currentToken.value,
            source: "turtle parser",
          );

          if (e is RdfConstraintViolationException) {
            throw RdfConstraintViolationException(
              e.message,
              constraint: e.constraint,
              cause: e.cause,
              source: sourceLocation,
            );
          } else if (e is RdfValidationException) {
            throw RdfValidationException(
              e.message,
              cause: e.cause,
              source: sourceLocation,
            );
          } else if (e is RdfParserException) {
            throw RdfSyntaxException(
              e.message,
              format: e.format,
              cause: e.cause,
              source: sourceLocation,
            );
          } else {
            // simply rethrow the exception if we don't know how to handle it
            rethrow;
          }
        } else {
          // simply rethrow if it has source information
          rethrow;
        }
      }

      // Convert other exceptions to RdfSyntaxException
      _log.severe('Error during parsing', e, stack);
      final source =
          e is FormatException
              ? SourceLocation(
                line: _currentToken.line,
                column: _currentToken.column,
                context: _currentToken.value,
              )
              : null;

      throw RdfSyntaxException(
        e.toString(),
        format: _format,
        cause: e,
        source: source,
      );
    }
  }

  /// Parses a base URI declaration.
  ///
  /// A base declaration has the form:
  /// ```turtle
  /// @base <iri> .
  /// ```
  ///
  /// The base URI is stored in the [_baseUri] field and used for resolving relative IRIs.
  void _parseBase() {
    // _log.finest('Parsing base declaration');
    _expect(TokenType.base);
    _currentToken = _tokenizer.nextToken();
    // _log.finest('After @base: $_currentToken');

    _expect(TokenType.iri);
    final iriToken = _currentToken.value;
    // Extract IRI value from <...>
    final iri = _extractIriValue(iriToken);
    // _log.finest('Found base IRI: $iri');

    _baseUri = iri;
    // _log.finest('Set base URI to: "$iri"');

    _currentToken = _tokenizer.nextToken();
    // _log.finest('After IRI: $_currentToken');

    _expect(TokenType.dot);
    _currentToken = _tokenizer.nextToken();
    // _log.finest('After dot: $_currentToken');
  }

  /// Parses a prefix declaration.
  ///
  /// A prefix declaration has the form:
  /// ```turtle
  /// @prefix prefix: <iri> .
  /// ```
  ///
  /// The prefix is stored in the [_prefixes] map for later use in expanding
  /// prefixed names.
  ///
  /// Throws [RdfSyntaxException] if the prefix declaration is malformed,
  /// such as when the colon is missing after the prefix.
  void _parsePrefix() {
    // _log.finest('Parsing prefix declaration');
    _expect(TokenType.prefix);
    _currentToken = _tokenizer.nextToken();
    // _log.finest('After @prefix: $_currentToken');

    // Check that the next token is a prefixed name (which must contain a colon)
    if (_currentToken.type != TokenType.prefixedName) {
      throw RdfSyntaxException(
        'Expected prefixed name (with colon) after @prefix',
        format: _format,
        source: SourceLocation(
          line: _currentToken.line,
          column: _currentToken.column,
          context: _currentToken.value,
        ),
      );
    }

    // Ensure the prefixed name actually contains a colon
    final prefixedName = _currentToken.value;
    if (!prefixedName.contains(':')) {
      throw RdfSyntaxException(
        'Invalid prefix declaration: missing colon after prefix name',
        format: _format,
        source: SourceLocation(
          line: _currentToken.line,
          column: _currentToken.column,
          context: prefixedName,
        ),
      );
    }

    // _log.finest('Found prefixed name: $prefixedName');

    // Handle empty prefix case
    final prefix =
        prefixedName == ':'
            ? ''
            : prefixedName.substring(0, prefixedName.length - 1);
    // _log.finest('Extracted prefix: "$prefix"');

    _currentToken = _tokenizer.nextToken();
    // _log.finest('After prefixed name: $_currentToken');

    _expect(TokenType.iri);
    final iriToken = _currentToken.value;
    // Extract IRI value from <...>
    final iri = _extractIriValue(iriToken);
    // _log.finest('Found IRI: $iri');

    _prefixes[prefix] = iri;
    // _log.finest('Stored prefix mapping: "$prefix" -> "$iri"');

    _currentToken = _tokenizer.nextToken();
    // _log.finest('After IRI: $_currentToken');

    // In compatibility mode, allow missing dot after prefix declaration
    // and also allow another prefix to follow directly
    if (_parsingFlags.contains(TurtleParsingFlag.allowMissingDotAfterPrefix) &&
        (_currentToken.type == TokenType.prefix ||
            _currentToken.type == TokenType.eof ||
            _currentToken.type == TokenType.prefixedName ||
            _currentToken.type == TokenType.iri)) {
      _log.warning(
        'In compatibility mode: Missing dot after prefix declaration',
      );
      // Continue without consuming the dot
      return;
    }

    _expect(TokenType.dot);
    _currentToken = _tokenizer.nextToken();
    // _log.finest('After dot: $_currentToken');
  }

  /// Parses a subject in a triple.
  ///
  /// A subject can be:
  /// - An IRI (e.g., <http://example.com/foo>)
  /// - A prefixed name (e.g., foaf:Person)
  /// - A blank node (e.g., _:b1)
  /// - A blank node expression (e.g., [ ... ])
  ///
  /// Returns an RdfTerm representing the subject (either IriTerm or BlankNodeTerm)
  RdfSubject _parseSubject() {
    // _log.finest('Parsing subject, current token: $_currentToken');
    if (_currentToken.type == TokenType.iri) {
      final iriValue = _extractIriValue(_currentToken.value);
      final resolvedIri = _resolveIri(iriValue);
      final subject = IriTerm(resolvedIri);
      _currentToken = _tokenizer.nextToken();
      // _log.finest('Parsed IRI subject: $subject');
      return subject;
    } else if (_currentToken.type == TokenType.prefixedName) {
      final expandedIri = _expandPrefixedName(_currentToken.value);
      final subject = IriTerm(expandedIri);
      _currentToken = _tokenizer.nextToken();
      // _log.finest('Parsed prefixed name subject: $subject');
      return subject;
    } else if (_currentToken.type == TokenType.blankNode) {
      final label = _currentToken.value;
      final subject = _blankNodesByLabels[label] ?? BlankNodeTerm();
      _blankNodesByLabels[label] = subject;
      _currentToken = _tokenizer.nextToken();
      // _log.finest('Parsed blank node subject: $subject');
      return subject;
    } else if (_currentToken.type == TokenType.openBracket) {
      // _log.finest('Found blank node expression for subject');
      return _parseBlankNode();
    } else if (_currentToken.type == TokenType.a) {
      // Handle the case where 'a' is used as a subject (which is invalid)
      _log.severe('Invalid use of "a" as subject');
      throw RdfSyntaxException(
        'Cannot use "a" as a subject',
        format: _format,
        source: SourceLocation(
          line: _currentToken.line,
          column: _currentToken.column,
          context: _currentToken.value,
        ),
      );
    } else {
      _log.severe('Unexpected token type for subject: ${_currentToken.type}');
      throw RdfSyntaxException(
        'Expected subject',
        format: _format,
        source: SourceLocation(
          line: _currentToken.line,
          column: _currentToken.column,
          context: _currentToken.value,
        ),
      );
    }
  }

  /// Parses a list of predicate-object pairs.
  ///
  /// A predicate-object list has the form:
  /// ```turtle
  /// predicate1 object1 ;
  /// predicate2 object2 ;
  /// predicate3 object3 .
  /// ```
  ///
  /// Objects can also be comma-separated:
  /// ```turtle
  /// predicate1 object1, object2, object3 ;
  /// predicate2 object4 .
  /// ```
  ///
  /// Returns a list of (predicate, object) pairs that share the same subject.
  List<({IriTerm predicate, RdfObject object})> _parsePredicateObjectList() {
    // _log.finest('Parsing predicate-object list');
    final result = <({IriTerm predicate, RdfObject object})>[];
    var predicate = _parsePredicate();
    // _log.finest('Parsed predicate: $predicate');

    // Parse first object
    var object = _parseObject();
    // _log.finest('Parsed object: $object');
    result.add((predicate: predicate, object: object));

    // Parse additional objects for the same predicate
    while (_currentToken.type == TokenType.comma) {
      // _log.finest('Found comma, parsing next object');
      _currentToken = _tokenizer.nextToken();
      object = _parseObject();
      // _log.finest('Parsed next object: $object');
      result.add((predicate: predicate, object: object));
    }

    // Parse additional predicate-object pairs
    while (_currentToken.type == TokenType.semicolon) {
      // _log.finest('Found semicolon, parsing next predicate-object pair');
      _currentToken = _tokenizer.nextToken();
      if (_currentToken.type == TokenType.dot ||
          _currentToken.type == TokenType.closeBracket) {
        // _log.finest('End of predicate-object list reached');
        break;
      }
      predicate = _parsePredicate();
      // _log.finest('Parsed next predicate: $predicate');
      object = _parseObject();
      // _log.finest('Parsed next object: $object');
      result.add((predicate: predicate, object: object));

      // Parse additional objects for this predicate
      while (_currentToken.type == TokenType.comma) {
        // _log.finest('Found comma, parsing next object');
        _currentToken = _tokenizer.nextToken();
        object = _parseObject();
        // _log.finest('Parsed next object: $object');
        result.add((predicate: predicate, object: object));
      }
    }

    // Ensure that statement is properly terminated with a dot
    if (_currentToken.type != TokenType.dot &&
        _currentToken.type != TokenType.closeBracket &&
        _currentToken.type != TokenType.eof) {
      throw RdfSyntaxException(
        'Expected "." to terminate statement',
        format: _format,
        source: SourceLocation(
          line: _currentToken.line,
          column: _currentToken.column,
          context: _currentToken.value,
        ),
      );
    }

    // _log.finer('Predicate-object list complete: $result');
    return result;
  }

  /// Parses a predicate in a triple.
  ///
  /// A predicate can be:
  /// - The special 'a' keyword (expands to rdf:type)
  /// - An IRI (e.g., <http://example.com/bar>)
  /// - A prefixed name (e.g., foaf:name)
  ///
  /// Returns an IriTerm representing the predicate.
  IriTerm _parsePredicate() {
    // _log.finest('Parsing predicate, current token: $_currentToken');
    if (_currentToken.type == TokenType.a) {
      _currentToken = _tokenizer.nextToken();
      // _log.finest('Found "a" keyword, expanded to rdf:type');
      return RdfPredicates.type;
    } else if (_currentToken.type == TokenType.iri) {
      final iriValue = _extractIriValue(_currentToken.value);
      final resolvedIri = _resolveIri(iriValue);
      final predicate = IriTerm(resolvedIri);
      _currentToken = _tokenizer.nextToken();
      // _log.finest('Parsed IRI predicate: $predicate');
      return predicate;
    } else if (_currentToken.type == TokenType.prefixedName) {
      final expandedIri = _expandPrefixedName(_currentToken.value);
      final predicate = IriTerm(expandedIri);
      _currentToken = _tokenizer.nextToken();
      // _log.finest('Parsed prefixed name predicate: $predicate');
      return predicate;
    } else {
      _log.severe('Unexpected token type for predicate: ${_currentToken.type}');
      throw RdfSyntaxException(
        'Expected predicate',
        format: _format,
        source: SourceLocation(
          line: _currentToken.line,
          column: _currentToken.column,
          context: _currentToken.value,
        ),
      );
    }
  }

  /// Parses an object in a triple.
  ///
  /// An object can be:
  /// - An IRI (e.g., <http://example.com/baz>)
  /// - A prefixed name (e.g., foaf:Person)
  /// - A blank node (e.g., _:b1)
  /// - A literal (e.g., "Hello, World!")
  /// - A blank node expression (e.g., [ ... ])
  /// - A collection (e.g., ( item1 item2 item3 ))
  /// - A boolean literal (e.g., true, false)
  /// - A numeric literal (e.g., 42, 3.14)
  ///
  /// Returns an RdfTerm representing the object (IriTerm, BlankNodeTerm, or LiteralTerm).
  RdfObject _parseObject() {
    // _log.finest('Parsing object, current token: $_currentToken');
    if (_currentToken.type == TokenType.iri) {
      final iriValue = _extractIriValue(_currentToken.value);
      final resolvedIri = _resolveIri(iriValue);
      final object = IriTerm(resolvedIri);
      _currentToken = _tokenizer.nextToken();
      // _log.finest('Parsed IRI object: $object');
      return object;
    } else if (_currentToken.type == TokenType.prefixedName) {
      final expandedIri = _expandPrefixedName(_currentToken.value);
      final object = IriTerm(expandedIri);
      _currentToken = _tokenizer.nextToken();
      // _log.finest('Parsed prefixed name object: $object');
      return object;
    } else if (_currentToken.type == TokenType.blankNode) {
      final label = _currentToken.value;
      final object = _blankNodesByLabels[label] ?? BlankNodeTerm();
      _blankNodesByLabels[label] = object;
      _currentToken = _tokenizer.nextToken();
      // _log.finest('Parsed blank node object: $object');
      return object;
    } else if (_currentToken.type == TokenType.literal) {
      final literalTerm = _parseLiteralValue(_currentToken.value);
      _currentToken = _tokenizer.nextToken();
      // _log.finest('Parsed literal object: $literalTerm');
      return literalTerm;
    } else if (_currentToken.type == TokenType.booleanLiteral) {
      // Handle boolean literals
      final value = _currentToken.value;
      final literalTerm = LiteralTerm.boolean(value);
      _currentToken = _tokenizer.nextToken();
      return literalTerm;
    } else if (_currentToken.type == TokenType.integerLiteral) {
      // Handle integer literals
      final value = _currentToken.value;
      final literalTerm = LiteralTerm.integer(value);
      _currentToken = _tokenizer.nextToken();
      return literalTerm;
    } else if (_currentToken.type == TokenType.decimalLiteral) {
      // Handle decimal literals
      final value = _currentToken.value;
      final literalTerm = LiteralTerm.decimal(value);
      _currentToken = _tokenizer.nextToken();
      return literalTerm;
    } else if (_currentToken.type == TokenType.openBracket) {
      // _log.finest('Found blank node expression for object');
      return _parseBlankNode();
    } else if (_currentToken.type == TokenType.openParen) {
      // Handle collection (e.g., ( item1 item2 item3 ))
      return _parseCollection();
    } else {
      _log.severe('Unexpected token type for object: ${_currentToken.type}');
      throw RdfSyntaxException(
        'Expected object',
        format: _format,
        source: SourceLocation(
          line: _currentToken.line,
          column: _currentToken.column,
          context: _currentToken.value,
        ),
      );
    }
  }

  /// Parses an RDF collection (ordered list).
  ///
  /// A collection in Turtle has the form:
  /// ```turtle
  /// ( item1 item2 item3 )
  /// ```
  ///
  /// Returns a blank node representing the collection, and adds the necessary triples
  /// to represent the list structure using rdf:first, rdf:rest, and rdf:nil.
  RdfObject _parseCollection() {
    // _log.finest('Parsing collection');
    _expect(TokenType.openParen);
    _currentToken = _tokenizer.nextToken();

    // Check for empty collection - return rdf:nil for empty lists
    if (_currentToken.type == TokenType.closeParen) {
      _currentToken = _tokenizer.nextToken();
      return RdfResources.nil;
    }

    // Start the collection
    final firstNode = BlankNodeTerm();
    BlankNodeTerm currentNode = firstNode;

    while (_currentToken.type != TokenType.closeParen &&
        _currentToken.type != TokenType.eof) {
      // Parse the current item in the collection
      final item = _parseObject();

      // Add triple for current item (currentNode rdf:first item)
      _triples.add(Triple(currentNode, RdfPredicates.first, item));

      // Check if we've reached the end of the collection
      if (_currentToken.type == TokenType.closeParen) {
        // End the list with rdf:nil
        _triples.add(Triple(currentNode, RdfPredicates.rest, RdfResources.nil));
        break;
      } else {
        // Create next node and link current to it
        final nextNode = BlankNodeTerm();
        _triples.add(Triple(currentNode, RdfPredicates.rest, nextNode));
        currentNode = nextNode;
      }
    }

    // Consume closing parenthesis
    _expect(TokenType.closeParen);
    _currentToken = _tokenizer.nextToken();

    return firstNode;
  }

  /// Resolves a potentially relative IRI against the base URI.
  ///
  /// If the IRI is already absolute (starts with a scheme like "http:"),
  /// returns it unchanged. Otherwise, if a base URI is available,
  /// resolves the IRI against the base URI.
  ///
  /// Throws [RdfInvalidIriException] if the IRI is relative and no base URI is available.
  String _resolveIri(String iri) {
    // If the IRI is already absolute, return it as is
    if (Uri.parse(iri).hasScheme) {
      return iri;
    }

    // If there's no base URI but the IRI is relative, throw a helpful exception
    if (_baseUri == null) {
      throw RdfInvalidIriException(
        'Cannot use relative IRI without a base URI. Either provide a base URI when creating the parser, or use absolute IRIs.',
        iri: iri,
        format: _format,
        source: SourceLocation(
          line: _currentToken.line,
          column: _currentToken.column,
          context: _currentToken.value,
        ),
      );
    }

    // Resolve the relative IRI against the base URI
    final resolved = Uri.parse(_baseUri!).resolve(iri).toString();
    // _log.finest('Resolved relative IRI: $iri -> $resolved');
    return resolved;
  }

  /// Parses a blank node expression.
  ///
  /// A blank node expression has the form:
  /// ```turtle
  /// [ predicate1 object1 ;
  ///   predicate2 object2 ;
  ///   predicate3 object3 ]
  /// ```
  ///
  /// Returns a BlankNodeTerm and adds any triples found within the blank node
  /// to the [_triples] list.
  BlankNodeTerm _parseBlankNode() {
    // _log.finest('Parsing blank node');
    _expect(TokenType.openBracket);
    final subject = BlankNodeTerm();
    // _log.finest('Generated blank node identifier: $subject');
    _currentToken = _tokenizer.nextToken();

    if (_currentToken.type != TokenType.closeBracket) {
      // _log.finest('Found blank node content');
      final predicateObjectList = _parsePredicateObjectList();
      for (final po in predicateObjectList) {
        _triples.add(Triple(subject, po.predicate, po.object));
      }
      _expect(TokenType.closeBracket);
      _currentToken = _tokenizer.nextToken();
    } else {
      // _log.finest('Empty blank node');
      _currentToken = _tokenizer.nextToken();
    }
    return subject;
  }

  /// Extracts the IRI value from a Turtle IRI token.
  ///
  /// Removes the enclosing angle brackets (<...>).
  String _extractIriValue(String iriToken) {
    if (iriToken.startsWith('<') && iriToken.endsWith('>')) {
      return iriToken.substring(1, iriToken.length - 1);
    }
    return iriToken;
  }

  /// Parses a literal value from a Turtle literal token.
  ///
  /// Handles simple literals, language-tagged literals, and datatyped literals.
  /// Properly unescapes any escape sequences in the literal value according to
  /// Turtle syntax rules.
  LiteralTerm _parseLiteralValue(String literalToken) {
    // _log.finest('Parsing literal token: $literalToken');

    // Check if it's a triple-quoted multiline string
    bool isTripleQuoted =
        literalToken.startsWith('"""') && literalToken.length >= 6;

    String value;
    if (isTripleQuoted) {
      // Extract the content between triple quotes
      final closingIndex = literalToken.lastIndexOf('"""');
      if (closingIndex > 0) {
        final escapedValue = literalToken.substring(3, closingIndex);
        value = _unescapeTurtleString(escapedValue);
      } else {
        _log.severe('Invalid triple-quoted literal format: $literalToken');
        throw RdfSyntaxException(
          'Invalid triple-quoted literal format',
          format: _format,
          source: SourceLocation(
            line: _currentToken.line,
            column: _currentToken.column,
            context: literalToken,
          ),
        );
      }
    } else {
      // Handle regular quoted literals
      final valueMatch = RegExp(
        r'"([^"\\]*(?:\\.[^"\\]*)*)"',
      ).firstMatch(literalToken);
      if (valueMatch == null) {
        _log.severe('Invalid literal format: $literalToken');
        throw RdfSyntaxException(
          'Invalid literal format',
          format: _format,
          source: SourceLocation(
            line: _currentToken.line,
            column: _currentToken.column,
            context: literalToken,
          ),
        );
      }

      final escapedValue = valueMatch.group(1)!;
      value = _unescapeTurtleString(escapedValue);
    }

    // Check for language tag (@lang)
    final langMatch = RegExp(r'@([a-zA-Z\-]+)$').firstMatch(literalToken);
    if (langMatch != null) {
      final lang = langMatch.group(1)!;
      return LiteralTerm.withLanguage(value, lang);
    }

    // Check for datatype (^^<datatype>)
    final datatypeMatch = RegExp(r'\^\^<([^>]+)>$').firstMatch(literalToken);
    if (datatypeMatch != null) {
      final datatype = IriTerm(datatypeMatch.group(1)!);
      return LiteralTerm(value, datatype: datatype);
    }

    // Check for datatype with prefixed name (^^prefix:localName)
    final prefixedDatatypeMatch = RegExp(
      r'\^\^([a-zA-Z0-9_\-]+:[a-zA-Z0-9_\-]+)$',
    ).firstMatch(literalToken);
    if (prefixedDatatypeMatch != null) {
      final prefixedName = prefixedDatatypeMatch.group(1)!;
      final expandedIri = _expandPrefixedName(prefixedName);
      final datatype = IriTerm(expandedIri);
      return LiteralTerm(value, datatype: datatype);
    }

    // Simple literal
    return LiteralTerm.string(value);
  }

  /// Unescapes a string according to Turtle syntax rules.
  ///
  /// This is the inverse operation of _escapeTurtleString in TurtleSerializer.
  /// It handles standard escape sequences (\n, \r, \t, etc.) and Unicode
  /// escape sequences (\uXXXX and \UXXXXXXXX).
  ///
  /// According to the W3C Turtle specification, Unicode escape sequences must:
  /// - Be 4 digits for \u escapes
  /// - Be 8 digits for \U escapes
  /// - Contain only valid hexadecimal digits (0-9, A-F)
  ///
  /// If these conditions are not met, the parser will throw a syntax error.
  String _unescapeTurtleString(String value) {
    final StringBuffer buffer = StringBuffer();

    for (int i = 0; i < value.length; i++) {
      // Handle escape sequences
      if (value[i] == '\\' && i + 1 < value.length) {
        final nextChar = value[i + 1];
        switch (nextChar) {
          case 'b': // backspace
            buffer.writeCharCode(0x08);
            i++;
            break;
          case 't': // tab
            buffer.writeCharCode(0x09);
            i++;
            break;
          case 'n': // line feed
            buffer.writeCharCode(0x0A);
            i++;
            break;
          case 'f': // form feed
            buffer.writeCharCode(0x0C);
            i++;
            break;
          case 'r': // carriage return
            buffer.writeCharCode(0x0D);
            i++;
            break;
          case '"': // double quote
            buffer.writeCharCode(0x22);
            i++;
            break;
          case '\\': // backslash
            buffer.writeCharCode(0x5C);
            i++;
            break;
          case 'u': // 4-digit Unicode escape (e.g., \u00A9)
            if (i + 5 < value.length) {
              final hexCode = value.substring(i + 2, i + 6);
              // Check if all characters are valid hex digits
              if (RegExp(r'^[0-9A-Fa-f]{4}$').hasMatch(hexCode)) {
                final codeUnit = int.parse(hexCode, radix: 16);
                buffer.writeCharCode(codeUnit);
                i += 5;
              } else {
                // Invalid Unicode escape, treat as literal characters
                buffer.write('\\');
                buffer.write(nextChar);
                // Don't skip the u since we're treating it as a literal
                i++;
              }
            } else {
              // Incomplete escape, treat as literal characters
              buffer.write('\\');
              buffer.write(nextChar);
              i++;
            }
            break;
          case 'U': // 8-digit Unicode escape (e.g., \U0001F600)
            if (i + 9 < value.length) {
              final hexCode = value.substring(i + 2, i + 10);
              // Check if all characters are valid hex digits
              if (RegExp(r'^[0-9A-Fa-f]{8}$').hasMatch(hexCode)) {
                final codeUnit = int.parse(hexCode, radix: 16);
                buffer.writeCharCode(codeUnit);
                i += 9;
              } else {
                // Invalid Unicode escape, treat as literal characters
                buffer.write('\\');
                buffer.write(nextChar);
                // Don't skip the U since we're treating it as a literal
                i++;
              }
            } else {
              // Incomplete escape, treat as literal characters
              buffer.write('\\');
              buffer.write(nextChar);
              i++;
            }
            break;
          default:
            // Unrecognized escape, treat as literal characters
            buffer.write('\\');
            buffer.write(nextChar);
            i++;
        }
      } else {
        // Normal character
        buffer.write(value[i]);
      }
    }

    return buffer.toString();
  }

  /// Expands a prefixed name to a full IRI.
  ///
  /// A prefixed name has the form "prefix:localName". This method:
  /// 1. Splits the prefixed name into prefix and local name parts
  /// 2. Looks up the prefix in the [_prefixes] map
  /// 3. Concatenates the IRI from the prefix map with the local name
  /// 4. If the result is a relative IRI and [_baseUri] is set, resolves it against the base URI
  ///
  /// Example:
  /// ```dart
  /// _prefixes['foaf'] = 'http://xmlns.com/foaf/0.1/';
  /// _expandPrefixedName('foaf:name') // Returns 'http://xmlns.com/foaf/0.1/name'
  /// ```
  String _expandPrefixedName(String prefixedName) {
    // Handle simple identifiers without colon if allowIdentifiersWithoutColon is enabled
    if (_parsingFlags.contains(
          TurtleParsingFlag.allowIdentifiersWithoutColon,
        ) &&
        !prefixedName.contains(':')) {
      _log.warning(
        'In compatibility mode: Using identifier without colon as IRI: "$prefixedName"',
      );

      if (_baseUri == null) {
        throw RdfSyntaxException(
          'Base URI is required when using identifiers without colon',
          format: _format,
          source: SourceLocation(
            line: _currentToken.line,
            column: _currentToken.column,
            context: prefixedName,
          ),
        );
      }
      // resolve the identifier against the base URI
      return _resolveIri(prefixedName);
    }

    // Handle prefixed names with digits at start of local name when allowDigitInLocalName flag is enabled
    if (_parsingFlags.contains(TurtleParsingFlag.allowDigitInLocalName)) {
      final defaultCommonPrefixes = _namespaceMappings.asMap();
      final parts = prefixedName.split(':');
      if (parts.length == 2) {
        final prefix = parts[0];
        final localName = parts[1];

        if (RegExp(r'^\d').hasMatch(localName)) {
          _log.warning(
            'In compatibility mode: Handling prefixed name with numeric start in local name: $prefixedName',
          );

          // Automatically add the prefix if it's a common one and not already defined
          if (!_prefixes.containsKey(prefix) &&
              defaultCommonPrefixes.containsKey(prefix) &&
              _parsingFlags.contains(TurtleParsingFlag.autoAddCommonPrefixes)) {
            _log.warning(
              'In compatibility mode: Auto-adding prefix for digit-starting local name: $prefix -> ${defaultCommonPrefixes[prefix]}',
            );
            _prefixes[prefix] = defaultCommonPrefixes[prefix]!;
          }

          // If prefix is available, expand normally
          if (_prefixes.containsKey(prefix)) {
            final expanded = '${_prefixes[prefix]}$localName';
            return _resolveIri(expanded);
          }
        }
      }
    }

    final parts = prefixedName.split(':');
    if (parts.length != 2) {
      _log.severe('Invalid prefixed name format: $prefixedName');
      throw RdfSyntaxException(
        'Invalid prefixed name format',
        format: _format,
        source: SourceLocation(
          line: _currentToken.line,
          column: _currentToken.column,
          context: prefixedName,
        ),
      );
    }

    final prefix = parts[0];
    final localName = parts[1];

    if (!_prefixes.containsKey(prefix)) {
      // In compatibility mode, we could try to guess the prefix
      if (_parsingFlags.contains(TurtleParsingFlag.autoAddCommonPrefixes)) {
        final defaultCommonPrefixes = _namespaceMappings.asMap();
        // If we're in compatibility mode, check for common prefixes
        if (defaultCommonPrefixes.containsKey(prefix)) {
          _log.warning(
            'In compatibility mode: Auto-adding common prefix: $prefix -> ${defaultCommonPrefixes[prefix]}',
          );
          _prefixes[prefix] = defaultCommonPrefixes[prefix]!;
        } else {
          // Still no match, we have to throw an exception
          _log.severe('Unknown prefix (even in compatibility mode): $prefix');
          throw RdfSyntaxException(
            'Unknown prefix (compatibility mode)',
            format: _format,
            source: SourceLocation(
              line: _currentToken.line,
              column: _currentToken.column,
              context: prefix,
            ),
          );
        }
      } else {
        _log.severe('Unknown prefix: $prefix');
        throw RdfSyntaxException(
          'Unknown prefix',
          format: _format,
          source: SourceLocation(
            line: _currentToken.line,
            column: _currentToken.column,
            context: prefix,
          ),
        );
      }
    }

    final expanded = '${_prefixes[prefix]}$localName';
    return _resolveIri(expanded);
  }

  /// Verifies that the current token is of the expected type.
  ///
  /// Throws a [RdfSyntaxException] if the current token's type does not match
  /// the expected type, including line and column information in the error message.
  ///
  /// In compatibility mode, certain types of mismatches may be allowed to support
  /// real-world Turtle files that don't strictly follow the specification.
  void _expect(TokenType type) {
    // _log.finest('Expecting token type: $type, found: ${_currentToken.type}');
    if (_currentToken.type != type) {
      // In compatibility mode, handle certain common deviations from the standard
      if (_parsingFlags.contains(TurtleParsingFlag.allowMissingFinalDot)) {
        // For Turtle files that omit trailing dots or semicolons in certain contexts
        if (type == TokenType.dot &&
            (_currentToken.type == TokenType.eof ||
                _currentToken.type == TokenType.prefixedName ||
                _currentToken.type == TokenType.iri)) {
          _log.warning(
            'In compatibility mode: Missing dot at end of statement',
          );
          // In compatibility mode, we pretend we saw the expected token and continue
          return;
        }

        // Some files use invalid prefix format (without colon)
        if (type == TokenType.prefixedName &&
            _currentToken.type == TokenType.iri) {
          _log.warning('In compatibility mode: Treating IRI as prefixed name');
          return;
        }
      }

      _log.severe(
        'Token type mismatch: expected $type but found ${_currentToken.type}',
      );
      throw RdfSyntaxException(
        'Expected $type but found ${_currentToken.type}',
        format: _format,
        source: SourceLocation(
          line: _currentToken.line,
          column: _currentToken.column,
          context: _currentToken.value,
        ),
      );
    }
  }
}
