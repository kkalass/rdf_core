import 'package:rdf_core/rdf_core.dart';
import 'package:rdf_core/src/jsonld/jsonld_decoder.dart';
import 'package:rdf_core/src/vocab/rdf.dart';
import 'package:test/test.dart';

void main() {
  group('JsonLdParser', () {
    test('parses simple JSON-LD object', () {
      final jsonLd = '''
      {
        "@context": {
          "name": "http://xmlns.com/foaf/0.1/name",
          "homepage": "http://xmlns.com/foaf/0.1/homepage"
        },
        "@id": "http://example.org/person/john",
        "name": "John Smith",
        "homepage": "http://example.org/john/"
      }
      ''';

      final parser = JsonLdParser(jsonLd);
      final triples = parser.parse();

      expect(triples.length, 2);

      // Find the name triple
      expect(
        triples.any(
          (t) =>
              t.subject == IriTerm('http://example.org/person/john') &&
              t.predicate == IriTerm('http://xmlns.com/foaf/0.1/name') &&
              t.object == LiteralTerm.string("John Smith"),
        ),
        isTrue,
      );

      // Find the homepage triple
      expect(
        triples.any(
          (t) =>
              t.subject == IriTerm('http://example.org/person/john') &&
              t.predicate == IriTerm('http://xmlns.com/foaf/0.1/homepage') &&
              t.object == IriTerm('http://example.org/john/'),
        ),
        isTrue,
      );
    });

    test('parses JSON-LD array at root level', () {
      final jsonLd = '''
      [
        {
          "@context": {
            "name": "http://xmlns.com/foaf/0.1/name"
          },
          "@id": "http://example.org/person/john",
          "name": "John Smith"
        },
        {
          "@context": {
            "name": "http://xmlns.com/foaf/0.1/name"
          },
          "@id": "http://example.org/person/jane",
          "name": "Jane Doe"
        }
      ]
      ''';

      final parser = JsonLdParser(jsonLd);
      final triples = parser.parse();

      expect(triples.length, 2);

      // Check that we have triples for both John and Jane
      expect(
        triples.any(
          (t) =>
              t.subject == IriTerm('http://example.org/person/john') &&
              t.predicate == IriTerm('http://xmlns.com/foaf/0.1/name') &&
              t.object == LiteralTerm.string("John Smith"),
        ),
        isTrue,
      );

      expect(
        triples.any(
          (t) =>
              t.subject == IriTerm('http://example.org/person/jane') &&
              t.predicate == IriTerm('http://xmlns.com/foaf/0.1/name') &&
              t.object == LiteralTerm.string('Jane Doe'),
        ),
        isTrue,
      );
    });

    test('handles type via @type keyword', () {
      final jsonLd = '''
      {
        "@context": {
          "Person": "http://xmlns.com/foaf/0.1/Person",
          "name": "http://xmlns.com/foaf/0.1/name"
        },
        "@id": "http://example.org/person/john",
        "@type": "Person",
        "name": "John Smith"
      }
      ''';

      final parser = JsonLdParser(jsonLd);
      final triples = parser.parse();

      expect(triples.length, 2);

      // Check the type triple exists with the fully expanded IRI
      expect(
        triples.any(
          (t) =>
              t.subject == IriTerm('http://example.org/person/john') &&
              t.predicate ==
                  IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#type') &&
              t.object == IriTerm('http://xmlns.com/foaf/0.1/Person'),
        ),
        isTrue,
        reason: 'Type value should be fully expanded using context mapping',
      );
    });

    test('handles @type as a prefixed string', () {
      final jsonLd = '''
      {
        "@context": {
          "foaf": "http://xmlns.com/foaf/0.1/",
          "name": "http://xmlns.com/foaf/0.1/name"
        },
        "@id": "http://example.org/person/john",
        "@type": "foaf:Person",
        "name": "John Smith"
      }
      ''';

      final parser = JsonLdParser(jsonLd);
      final triples = parser.parse();

      expect(triples.length, 2);

      // Check the type triple exists with the fully expanded IRI
      expect(
        triples.any(
          (t) =>
              t.subject == IriTerm('http://example.org/person/john') &&
              t.predicate == Rdf.type &&
              t.object == IriTerm('http://xmlns.com/foaf/0.1/Person'),
        ),
        isTrue,
        reason: 'Prefixed type value should be expanded correctly',
      );
    });

    test('handles @type as a direct URL', () {
      final jsonLd = '''
      {
        "@context": {
          "name": "http://xmlns.com/foaf/0.1/name"
        },
        "@id": "http://example.org/person/john",
        "@type": "http://xmlns.com/foaf/0.1/Person",
        "name": "John Smith"
      }
      ''';

      final parser = JsonLdParser(jsonLd);
      final triples = parser.parse();

      expect(triples.length, 2);

      // Check the type triple exists with the fully expanded IRI
      expect(
        triples.any(
          (t) =>
              t.subject == IriTerm('http://example.org/person/john') &&
              t.predicate == Rdf.type &&
              t.object == IriTerm('http://xmlns.com/foaf/0.1/Person'),
        ),
        isTrue,
        reason: 'Direct URL type should be preserved',
      );
    });

    test('handles @type as an object with @id', () {
      final jsonLd = '''
      {
        "@context": {
          "name": "http://xmlns.com/foaf/0.1/name"
        },
        "@id": "http://example.org/person/john",
        "@type": {"@id": "http://xmlns.com/foaf/0.1/Person"},
        "name": "John Smith"
      }
      ''';

      final parser = JsonLdParser(jsonLd);
      final triples = parser.parse();

      expect(triples.length, 2);

      // Check the type triple exists with the fully expanded IRI
      expect(
        triples.any(
          (t) =>
              t.subject == IriTerm('http://example.org/person/john') &&
              t.predicate == Rdf.type &&
              t.object == IriTerm('http://xmlns.com/foaf/0.1/Person'),
        ),
        isTrue,
        reason: 'Object with @id type should be handled correctly',
      );
    });

    test('handles @type with multiple values', () {
      final jsonLd = '''
      {
        "@context": {
          "foaf": "http://xmlns.com/foaf/0.1/",
          "schema": "http://schema.org/",
          "name": "http://xmlns.com/foaf/0.1/name"
        },
        "@id": "http://example.org/person/john",
        "@type": ["foaf:Person", "schema:Person"],
        "name": "John Smith"
      }
      ''';

      final parser = JsonLdParser(jsonLd);
      final triples = parser.parse();

      expect(triples.length, 3);

      // Check both type triples exist
      expect(
        triples.any(
          (t) =>
              t.subject == IriTerm('http://example.org/person/john') &&
              t.predicate == Rdf.type &&
              t.object == IriTerm('http://xmlns.com/foaf/0.1/Person'),
        ),
        isTrue,
        reason: 'First type in array should be parsed correctly',
      );

      expect(
        triples.any(
          (t) =>
              t.subject == IriTerm('http://example.org/person/john') &&
              t.predicate == Rdf.type &&
              t.object == IriTerm('http://schema.org/Person'),
        ),
        isTrue,
        reason: 'Second type in array should be parsed correctly',
      );
    });

    test('handles nested objects as blank nodes', () {
      final jsonLd = '''
      {
        "@context": {
          "name": "http://xmlns.com/foaf/0.1/name",
          "knows": "http://xmlns.com/foaf/0.1/knows"
        },
        "@id": "http://example.org/person/john",
        "name": "John Smith",
        "knows": {
          "name": "Jane Doe"
        }
      }
      ''';

      final parser = JsonLdParser(jsonLd);
      final triples = parser.parse();

      // Should be 3 triples: name, knows, and the blank node's name
      expect(triples.length, 3);

      // Find the knows triple to get the blank node ID
      final knowsTriple = triples.firstWhere(
        (t) => t.predicate == IriTerm('http://xmlns.com/foaf/0.1/knows'),
      );

      expect(
        knowsTriple.subject,
        equals(IriTerm('http://example.org/person/john')),
      );
      expect(knowsTriple.object is BlankNodeTerm, isTrue);

      final blankNodeId = knowsTriple.object;

      // Verify blank node properties
      expect(
        triples.any(
          (t) =>
              t.subject == blankNodeId &&
              t.predicate == IriTerm('http://xmlns.com/foaf/0.1/name') &&
              t.object == LiteralTerm.string('Jane Doe'),
        ),
        isTrue,
      );
    });

    test('handles array values for properties', () {
      final jsonLd = '''
      {
        "@context": {
          "name": "http://xmlns.com/foaf/0.1/name",
          "interest": "http://xmlns.com/foaf/0.1/interest"
        },
        "@id": "http://example.org/person/john",
        "name": "John Smith",
        "interest": ["Programming", "Reading", "Cycling"]
      }
      ''';

      final parser = JsonLdParser(jsonLd);
      final triples = parser.parse();

      // Should be 4 triples: name + 3 interests
      expect(triples.length, 4);

      // Test name triple
      expect(
        triples.any(
          (t) =>
              t.subject == IriTerm('http://example.org/person/john') &&
              t.predicate == IriTerm('http://xmlns.com/foaf/0.1/name') &&
              t.object == LiteralTerm.string('John Smith'),
        ),
        isTrue,
      );

      // Test interest triples
      expect(
        triples.any(
          (t) =>
              t.subject == IriTerm('http://example.org/person/john') &&
              t.predicate == IriTerm('http://xmlns.com/foaf/0.1/interest') &&
              t.object == LiteralTerm.string('Programming'),
        ),
        isTrue,
      );

      expect(
        triples.any(
          (t) =>
              t.subject == IriTerm('http://example.org/person/john') &&
              t.predicate == IriTerm('http://xmlns.com/foaf/0.1/interest') &&
              t.object == LiteralTerm.string('Reading'),
        ),
        isTrue,
      );

      expect(
        triples.any(
          (t) =>
              t.subject == IriTerm('http://example.org/person/john') &&
              t.predicate == IriTerm('http://xmlns.com/foaf/0.1/interest') &&
              t.object == LiteralTerm.string('Cycling'),
        ),
        isTrue,
      );
    });

    test('handles @graph structure', () {
      final jsonLd = '''
      {
        "@context": {
          "name": "http://xmlns.com/foaf/0.1/name"
        },
        "@graph": [
          {
            "@id": "http://example.org/person/john",
            "name": "John Smith"
          },
          {
            "@id": "http://example.org/person/jane",
            "name": "Jane Doe"
          }
        ]
      }
      ''';

      final parser = JsonLdParser(jsonLd);
      final triples = parser.parse();

      expect(triples.length, 2);

      // Check both triples exist
      expect(
        triples.any(
          (t) =>
              t.subject == IriTerm('http://example.org/person/john') &&
              t.predicate == IriTerm('http://xmlns.com/foaf/0.1/name') &&
              t.object == LiteralTerm.string('John Smith'),
        ),
        isTrue,
      );

      expect(
        triples.any(
          (t) =>
              t.subject == IriTerm('http://example.org/person/jane') &&
              t.predicate == IriTerm('http://xmlns.com/foaf/0.1/name') &&
              t.object == LiteralTerm.string('Jane Doe'),
        ),
        isTrue,
      );
    });

    test('handles typed literals with @value and @type', () {
      final jsonLd = '''
      {
        "@context": {
          "birthDate": "http://xmlns.com/foaf/0.1/birthDate"
        },
        "@id": "http://example.org/person/john",
        "birthDate": {
          "@value": "1990-07-04",
          "@type": "http://www.w3.org/2001/XMLSchema#date"
        }
      }
      ''';

      final parser = JsonLdParser(jsonLd);
      final triples = parser.parse();

      expect(triples.length, 1);

      final triple = triples.first;
      expect(triple.subject, equals(IriTerm('http://example.org/person/john')));
      expect(
        triple.predicate,
        equals(IriTerm('http://xmlns.com/foaf/0.1/birthDate')),
      );
      expect(
        triple.object,
        LiteralTerm(
          '1990-07-04',
          datatype: IriTerm('http://www.w3.org/2001/XMLSchema#date'),
        ),
      );
    });

    test('handles language-tagged literals with @value and @language', () {
      final jsonLd = '''
      {
        "@context": {
          "description": "http://xmlns.com/foaf/0.1/description"
        },
        "@id": "http://example.org/person/john",
        "description": {
          "@value": "Programmierer und Radfahrer",
          "@language": "de"
        }
      }
      ''';

      final parser = JsonLdParser(jsonLd);
      final triples = parser.parse();

      expect(triples.length, 1);

      final triple = triples.first;
      expect(triple.subject, equals(IriTerm('http://example.org/person/john')));
      expect(
        triple.predicate,
        equals(IriTerm('http://xmlns.com/foaf/0.1/description')),
      );
      expect(
        triple.object,
        equals(LiteralTerm.withLanguage('Programmierer und Radfahrer', 'de')),
      );
    });

    test('resolves IRIs against base URI', () {
      final jsonLd = '''
      {
        "@context": {
          "@base": "http://example.org/",
          "name": "http://xmlns.com/foaf/0.1/name"
        },
        "@id": "person/john",
        "name": "John Smith"
      }
      ''';

      final parser = JsonLdParser(jsonLd, baseUri: 'http://example.org/');
      final triples = parser.parse();

      expect(triples.length, 1);

      final triple = triples.first;
      expect(triple.subject, equals(IriTerm('http://example.org/person/john')));
      expect(
        triple.predicate,
        equals(IriTerm('http://xmlns.com/foaf/0.1/name')),
      );
      expect(triple.object, equals(LiteralTerm.string('John Smith')));
    });

    test('throws exception for invalid JSON', () {
      final invalidJson = '{name: "Invalid JSON"}';

      final parser = JsonLdParser(invalidJson);
      expect(() => parser.parse(), throwsA(isA<RdfSyntaxException>()));
    });

    test('throws exception for non-object/array JSON', () {
      final invalidJson = '"Just a string"';

      final parser = JsonLdParser(invalidJson);
      expect(
        () => parser.parse(),
        throwsA(
          isA<RdfSyntaxException>().having(
            (e) => e.message,
            'message',
            contains('must be an object or array'),
          ),
        ),
      );
    });

    test('throws exception for invalid array item', () {
      final invalidJson =
          '[1, 2, 3]'; // Array should contain objects, not primitives

      final parser = JsonLdParser(invalidJson);
      expect(
        () => parser.parse(),
        throwsA(
          isA<RdfSyntaxException>().having(
            (e) => e.message,
            'message',
            contains('Array item must be a JSON object'),
          ),
        ),
      );
    });

    test('throws exception for non-string @id value', () {
      final invalidIdJson = '''
      {
        "@id": 123,
        "name": "John Smith"
      }
      ''';

      final parser = JsonLdParser(invalidIdJson);
      expect(
        () => parser.parse(),
        throwsA(
          isA<RdfSyntaxException>().having(
            (e) => e.message,
            'message',
            contains('@id value must be a string'),
          ),
        ),
      );
    });

    test('handles object value with reference and additional properties', () {
      final jsonLd = '''
      {
        "@context": {
          "knows": "http://xmlns.com/foaf/0.1/knows",
          "name": "http://xmlns.com/foaf/0.1/name"
        },
        "@id": "http://example.org/person/john",
        "knows": {
          "@id": "http://example.org/person/jane",
          "name": "Jane Doe"
        }
      }
      ''';

      final parser = JsonLdParser(jsonLd);
      final triples = parser.parse();

      // Should be 3 triples: the knows relation and name triples for both subjects
      expect(triples.length, 2);

      // Check knows triple between John and Jane
      expect(
        triples.any(
          (t) =>
              t.subject == IriTerm('http://example.org/person/john') &&
              t.predicate == IriTerm('http://xmlns.com/foaf/0.1/knows') &&
              t.object == IriTerm('http://example.org/person/jane'),
        ),
        isTrue,
      );

      // Check Jane's name triple
      expect(
        triples.any(
          (t) =>
              t.subject == IriTerm('http://example.org/person/jane') &&
              t.predicate == IriTerm('http://xmlns.com/foaf/0.1/name') &&
              t.object == LiteralTerm.string('Jane Doe'),
        ),
        isTrue,
      );
    });

    test('handles simple values with different types', () {
      final jsonLd = '''
      {
        "@context": {
          "name": "http://xmlns.com/foaf/0.1/name",
          "age": "http://xmlns.com/foaf/0.1/age",
          "active": "http://xmlns.com/foaf/0.1/active"
        },
        "@id": "http://example.org/person/john",
        "name": "John Smith",
        "age": 42,
        "active": true
      }
      ''';

      final parser = JsonLdParser(jsonLd);
      final triples = parser.parse();

      expect(triples.length, 3);

      // Check string literal
      expect(
        triples.any(
          (t) =>
              t.subject == IriTerm('http://example.org/person/john') &&
              t.predicate == IriTerm('http://xmlns.com/foaf/0.1/name') &&
              t.object == LiteralTerm.string('John Smith'),
        ),
        isTrue,
      );

      // Check numeric literal (integer)
      expect(
        triples.any(
          (t) =>
              t.subject == IriTerm('http://example.org/person/john') &&
              t.predicate == IriTerm('http://xmlns.com/foaf/0.1/age') &&
              t.object == LiteralTerm.typed('42', 'integer'),
        ),
        isTrue,
      );

      // Check boolean literal
      expect(
        triples.any(
          (t) =>
              t.subject == IriTerm('http://example.org/person/john') &&
              t.predicate == IriTerm('http://xmlns.com/foaf/0.1/active') &&
              t.object == LiteralTerm.typed('true', 'boolean'),
        ),
        isTrue,
      );
    });

    test('handles decimal numeric values', () {
      final jsonLd = '''
      {
        "@context": {
          "score": "http://example.org/score"
        },
        "@id": "http://example.org/person/john",
        "score": 97.5
      }
      ''';

      final parser = JsonLdParser(jsonLd);
      final triples = parser.parse();

      expect(triples.length, 1);

      // Check decimal literal
      final triple = triples.first;
      expect(triple.subject, equals(IriTerm('http://example.org/person/john')));
      expect(triple.predicate, equals(IriTerm('http://example.org/score')));
      expect(triple.object, equals(LiteralTerm.typed('97.5', 'decimal')));
    });

    test('handles @value object without type or language', () {
      final jsonLd = '''
      {
        "@context": {
          "comment": "http://xmlns.com/foaf/0.1/comment"
        },
        "@id": "http://example.org/person/john",
        "comment": {
          "@value": "Just a simple comment"
        }
      }
      ''';

      final parser = JsonLdParser(jsonLd);
      final triples = parser.parse();

      expect(triples.length, 1);

      final triple = triples.first;
      expect(triple.subject, equals(IriTerm('http://example.org/person/john')));
      expect(
        triple.predicate,
        equals(IriTerm('http://xmlns.com/foaf/0.1/comment')),
      );
      expect(
        triple.object,
        equals(LiteralTerm.string('Just a simple comment')),
      );
    });

    test('throws exception for invalid IRI resolution', () {
      // Testing exception handling in _expandIri method
      final jsonLd = '''
      {
        "@id": "://invalid-uri",
        "name": "Invalid URI"
      }
      ''';

      final parser = JsonLdParser(jsonLd, baseUri: 'http://example.org/');
      expect(
        () => parser.parse(),
        throwsA(isA<RdfConstraintViolationException>()),
      );
    });

    test('handles context with complex mapping definitions', () {
      final jsonLd = '''
      {
        "@context": {
          "name": {
            "@id": "http://xmlns.com/foaf/0.1/name"
          }
        },
        "@id": "http://example.org/person/john",
        "name": "John Smith"
      }
      ''';

      final parser = JsonLdParser(jsonLd);
      final triples = parser.parse();

      expect(triples.length, 1);

      final triple = triples.first;
      expect(triple.subject, equals(IriTerm('http://example.org/person/john')));
      expect(
        triple.predicate,
        equals(IriTerm('http://xmlns.com/foaf/0.1/name')),
      );
      expect(triple.object, equals(LiteralTerm.string('John Smith')));
    });

    test('preserves blank node identity across document', () {
      final jsonLd = '''
      {
        "@context": {
          "knows": "http://xmlns.com/foaf/0.1/knows",
          "friend": "http://xmlns.com/foaf/0.1/friend"
        },
        "@id": "http://example.org/person/john",
        "knows": {"@id": "_:b1"},
        "friend": {"@id": "_:b1"}
      }
      ''';

      final parser = JsonLdParser(jsonLd);
      final triples = parser.parse();

      expect(triples.length, 2);

      final knowsTriple = triples.firstWhere(
        (t) => t.predicate == IriTerm('http://xmlns.com/foaf/0.1/knows'),
      );
      final friendTriple = triples.firstWhere(
        (t) => t.predicate == IriTerm('http://xmlns.com/foaf/0.1/friend'),
      );

      // The blank node objects should be the same instance
      expect(knowsTriple.object, equals(friendTriple.object));
      expect(identical(knowsTriple.object, friendTriple.object), isTrue);
    });
    group("canParse", () {
      test("Real Life HTML", () {
        final input = '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8"/>
  <meta name="viewport" content="width=device-width, initial-scale=1"/>
  <title>Solid Community AU</title>
  <link rel="stylesheet" href="/.well-known/css/styles/main.css" type="text/css">
</head>
<body>
  <header>
    <a href=".."><img src="https://solidcommunity.au/solid.svg" alt="[Solid logo]" /></a>
    <h1>Solid Community AU</h1>
  </header>
  <main>
    <h1>Welcome to the <a href="https://solidcommunity.au/web" target="_blank">Solid Community AU</a> Server</h1>

    <p>This experimental deployment of a <a
    href="https://github.com/CommunitySolidServer/">Community Solid
    Server</a> supports the <a
    href="https://solid.github.io/specification/protocol"
    target="_blank">Solid protocol</a> allowing users to create their
    own <a href="https://solidproject.org/about" target="_blank">Solid
    Pod</a> and identity. Whether you create a Solid Pod for yourself
    here, or on any Solid Server world wide (or even on your own
    deployed Solid Server), your Solid Pod based apps will just work.
    And for our apps, showcased at <a
    href="https://solidcommunity.au/web" target="_blank">Solid
    Community AU</a>, we take a privacy first approach so that any app
    data is hosted on the Solid Server, encrypted, supporting a Trust
    No One approach.</p>

    <h2 id="users">Getting Started</h2>
    
    <p id="registration-enabled"> If you like, <a
      id="registration-link"
      href="./.account/login/password/register/" target="_blank">Sign
      up for an account</a> here to get started with your own Pod and
      WebID. Once you have an account you can create your own Pod on
      this server or else connect a pre-existing Pod from another
      server through your WebID.  Once you have an Solid Pod you can
      <a id="registration-link" href="./.account/login/password/"
      target="_blank">login to manage it</a>.  </p>
    

    <h2 id="encryption">A Solidly Protected Flutter</h2>

    <p>The ANU's <a href="https://sii.anu.edu.au"
    target="_blank">Software Innovation Institute</a> is developing an
    ecosystem of Solid Pod based apps using <a
    href="https://survivor.togaware.com/gnulinux/flutter.html"
    target="_blank">Flutter</a> with apps that run on any platform
    (Linux, Android, Web, Windows, MacOS, Web, and iOS) with a secure
    and privacy focus. </p>

    <p>All user data is encrypted within the user's Solid Pod so that
    not even the server admins have access to our data and we need not
    be concerned about the server being compromised. SII are
    supporting this through Flutter packages, including the
    app-developer focused <a href="https://pub.dev/packages/solidpod"
    target="_blank">solidpod</a>, which is built on top of <a
    href="https://pub.dev/packages/solid_auth"
    target="_blank">solid_auth</a>, <a
    href="https://pub.dev/packages/solid_encrypt"
    target="_blank">solid_encrypt</a>, and <a
    href="https://pub.dev/packages/rdflib" target="_blank">rdflib</a>.
    </p>

    <h2>Apps to Try</h2>

<p>Our apps are written in <a
href="https://survivor.togaware.com/gnulinux/flutter.html"
target="_blank">Flutter</a> and are open source, and run on any
platform. You can try them out in the browser here or visit their
github homes to learn from and to build your own apps with these as
templates. We are also publishing them on the <a
href="https://play.google.com/store/apps/developer?id=Togaware+Pty+Ltd"
target="_blank">Google Play Store</a>. They are not all there yet, but
keep an eye out for them. Visit the <a
href="https://solidcommunity.au/web">Solid Community AU home page</a>
to view the portfolio of apps.</p>
    
    <h2>A Solid Experience</h2>

    <p>Learn more about Solid at <a href="https://solidproject.org/"
    target="_blank">solidproject.org</a>.</p>

    <p>


    <p>A Tim Berners-Lee reflection published on Medium, 12 Mar 2024:
    <a
    href="https://medium.com/@timberners_lee/marking-the-webs-35th-birthday-an-open-letter-ebb410cc7d42">Marking
    the Web's 35th Birthday</a> was reported on by <a
    href="https://www.livescience.com/technology/communications/35-years-after-first-proposing-the-world-wide-web-what-does-its-creator-tim-berners-lee-have-in-mind-next-inrupt">LiveScience</a>

    <p>A BBC News story on Inrupt, 8 Mar 2024: <a
    href="https://www.bbc.com/news/business-68286395"
    target="_blank">Your personal data all over the web - is there a
    better way?</a>

</main>

<footer>

  <p> Community Solid Server v7.0.2 ©2019–2023 <a
      href="https://inrupt.com/" target="_blank">Inrupt Inc.</a> and <a
      href="https://www.imec-int.com/" target="_blank">imec</a>. Hosted by <a
      href="https://survivor.togaware.com/gnulinux/solid.html" target="_blank">Togaware</a>.
      </p>
    
  </footer>
</body>
<script>
  (async() => {
    // Since this page is in the root of the server, we can determine other URLs relative to the current URL
    const res = await fetch('.account/');
    const registrationUrl = (await res.json())?.controls?.html?.password?.register;
    // We specifically want to check if the HTML page that we link to exists
    const resRegistrationPage = await fetch(registrationUrl, { headers: { accept: 'text/html' } });
    const registrationEnabled = registrationUrl && resRegistrationPage.status === 200;

    document.getElementById('registration-enabled').classList[registrationEnabled ? 'remove' : 'add']('hidden');
    document.getElementById('registration-disabled').classList[registrationEnabled ? 'add' : 'remove']('hidden');
    document.getElementById('registration-link').href = registrationUrl;
  })();
</script>
</html>
''';
        // Act
        final result = jsonldGraph.canParse(input);

        // Assert
        expect(result, isFalse);
      });

      test("Simple JSON-LD object with @context", () {
        final input = '''
        {
          "@context": {
            "name": "http://xmlns.com/foaf/0.1/name"
          },
          "@id": "http://example.org/person/john",
          "name": "John Smith"
        }
        ''';
        expect(jsonldGraph.canParse(input), isTrue);
      });

      test("JSON-LD with @id only", () {
        final input = '''
        {
          "@id": "http://example.org/person/john",
          "name": "John Smith"
        }
        ''';
        expect(jsonldGraph.canParse(input), isTrue);
      });

      test("JSON-LD with @type only", () {
        final input = '''
        {
          "@type": "Person",
          "name": "John Smith"
        }
        ''';
        expect(jsonldGraph.canParse(input), isTrue);
      });

      test("JSON-LD with @graph only", () {
        final input = '''
        {
          "@graph": [
            {
              "name": "John Smith"
            }
          ]
        }
        ''';
        expect(jsonldGraph.canParse(input), isTrue);
      });

      test("JSON-LD array format", () {
        final input = '''
        [
          {
            "@context": {
              "name": "http://xmlns.com/foaf/0.1/name"
            },
            "@id": "http://example.org/person/john",
            "name": "John Smith"
          }
        ]
        ''';
        expect(jsonldGraph.canParse(input), isTrue);
      });

      test("Complex JSON-LD with multiple keywords", () {
        final input = '''
        {
          "@context": "http://schema.org/",
          "@id": "http://example.org/person/john",
          "@type": "Person",
          "name": "John Smith"
        }
        ''';
        expect(jsonldGraph.canParse(input), isTrue);
      });

      test("Plain JSON without JSON-LD keywords", () {
        final input = '''
        {
          "name": "John Smith",
          "age": 30,
          "city": "New York"
        }
        ''';
        expect(jsonldGraph.canParse(input), isFalse);
      });

      test("JSON array without JSON-LD keywords", () {
        final input = '''
        [
          {
            "name": "John Smith",
            "age": 30
          },
          {
            "name": "Jane Doe",
            "age": 25
          }
        ]
        ''';
        expect(jsonldGraph.canParse(input), isFalse);
      });

      test("Not JSON - starts with text", () {
        final input = 'This is just plain text content.';
        expect(jsonldGraph.canParse(input), isFalse);
      });

      test("Not JSON - Turtle content", () {
        final input = '''
        @prefix ex: <http://example.org/> .
        
        ex:subject ex:predicate ex:object .
        ''';
        expect(jsonldGraph.canParse(input), isFalse);
      });

      test("XML content", () {
        final input = '''
        <?xml version="1.0"?>
        <root>
          <item>value</item>
        </root>
        ''';
        expect(jsonldGraph.canParse(input), isFalse);
      });

      test("Empty content", () {
        expect(jsonldGraph.canParse(''), isFalse);
        expect(jsonldGraph.canParse('   '), isFalse);
      });

      test("Invalid JSON structure", () {
        final input = '{name: "Invalid JSON"}';
        expect(jsonldGraph.canParse(input), isFalse);
      });

      test("JSON string literal", () {
        final input = '"Just a string"';
        expect(jsonldGraph.canParse(input), isFalse);
      });

      test("JSON number", () {
        final input = '42';
        expect(jsonldGraph.canParse(input), isFalse);
      });

      test("JSON null", () {
        final input = 'null';
        expect(jsonldGraph.canParse(input), isFalse);
      });

      test("JSON boolean", () {
        final input = 'true';
        expect(jsonldGraph.canParse(input), isFalse);
      });

      test("Schema.org JSON-LD example", () {
        final input = '''
        {
          "@context": "https://schema.org/",
          "@type": "Person",
          "name": "Jane Doe",
          "jobTitle": "Professor",
          "telephone": "(425) 123-4567",
          "url": "http://www.janedoe.com"
        }
        ''';
        expect(jsonldGraph.canParse(input), isTrue);
      });

      test("Complex context definition", () {
        final input = '''
        {
          "@context": {
            "foaf": "http://xmlns.com/foaf/0.1/",
            "schema": "http://schema.org/",
            "name": "foaf:name",
            "jobTitle": "schema:jobTitle"
          },
          "@id": "http://example.org/person/jane",
          "@type": "foaf:Person",
          "name": "Jane Doe",
          "jobTitle": "Professor"
        }
        ''';
        expect(jsonldGraph.canParse(input), isTrue);
      });

      test("Edge case: JSON with @-prefixed but non-JSON-LD keys", () {
        final input = '''
        {
          "@user": "john",
          "@timestamp": "2023-01-01",
          "message": "Hello world"
        }
        ''';
        expect(jsonldGraph.canParse(input), isFalse);
      });

      test("JSON-LD keyword in string value (should not match)", () {
        final input = '''
        {
          "description": "This text contains @context as a word in the description",
          "note": "Also mentions @type here"
        }
        ''';
        expect(jsonldGraph.canParse(input), isFalse);
      });

      test("Minimal valid JSON-LD", () {
        final input = '{"@id":"http://example.org/"}';
        expect(jsonldGraph.canParse(input), isTrue);
      });

      test("Array with mixed JSON-LD and plain objects", () {
        final input = '''
        [
          {
            "@id": "http://example.org/person/john",
            "name": "John"
          },
          {
            "name": "Jane",
            "age": 30
          }
        ]
        ''';
        expect(jsonldGraph.canParse(input), isTrue);
      });
    });
  });
}
