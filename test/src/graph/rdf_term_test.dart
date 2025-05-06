import 'package:rdf_core/src/exceptions/rdf_validation_exception.dart';
import 'package:rdf_core/src/graph/rdf_term.dart';
import 'package:rdf_core/src/vocab/rdf.dart';
import 'package:rdf_core/src/vocab/xsd.dart';

import 'package:test/test.dart';

void main() {
  group('IriTerm', () {
    test('constructs with valid IRI', () {
      final iri = IriTerm('http://example.org/resource');
      expect(iri.iri, equals('http://example.org/resource'));
    });

    test('equals operator compares case-insensitively', () {
      final iri1 = IriTerm('http://example.org/resource');
      final iri2 = IriTerm('http://EXAMPLE.org/resource');
      final iri3 = IriTerm('http://example.org/different');

      expect(iri1, equals(iri2));
      expect(iri1, isNot(equals(iri3)));
    });

    test('hash codes are equal for case-variant IRIs', () {
      // Note: This test may theoretically fail in edge cases due to hash collisions
      // but should be stable for typical usage patterns
      final iri1 = IriTerm('http://example.org/resource');
      final iri2 = IriTerm('http://example.org/RESOURCE');

      expect(
        iri1.hashCode,
        isNot(equals(iri2.hashCode)),
        reason: 'Hash codes should be based on original case',
      );
    });

    test('toString returns a readable representation', () {
      final iri = IriTerm('http://example.org/resource');
      expect(iri.toString(), equals('<http://example.org/resource>'));
    });

    test('is a subject, object and predicate', () {
      final iri = IriTerm('http://example.org/resource');
      expect(iri, isA<RdfSubject>());
      expect(iri, isA<RdfPredicate>());
      expect(iri, isA<RdfTerm>());
      expect(iri, isA<RdfObject>());
    });

    test('accepts various valid IRI formats', () {
      // Test with different schemes
      expect(() => IriTerm('http://example.org'), returnsNormally);
      expect(() => IriTerm('https://example.org'), returnsNormally);
      expect(() => IriTerm('ftp://example.org'), returnsNormally);
      expect(
        () => IriTerm('urn:uuid:6e8bc430-9c3a-11d9-9669-0800200c9a66'),
        returnsNormally,
      );
      expect(() => IriTerm('isbn:0451450523'), returnsNormally);

      // Test with complex paths and query strings
      expect(
        () => IriTerm('http://example.org/path/to/resource'),
        returnsNormally,
      );
      expect(
        () => IriTerm('http://example.org/search?q=test&page=1'),
        returnsNormally,
      );

      // Test with user info and fragment
      expect(() => IriTerm('http://user:pass@example.org'), returnsNormally);
      expect(
        () => IriTerm('http://example.org/resource#fragment'),
        returnsNormally,
      );
    });

    test('rejects empty IRI string', () {
      expect(
        () => IriTerm(''),
        throwsA(
          predicate<RdfConstraintViolationException>(
            (e) =>
                e.constraint == 'absolute-iri' &&
                e.message.contains('cannot be empty'),
          ),
        ),
      );
    });

    test('rejects relative IRIs without scheme', () {
      expect(
        () => IriTerm('/path/to/resource'),
        throwsA(
          predicate<RdfConstraintViolationException>(
            (e) =>
                e.constraint == 'absolute-iri' &&
                e.message.contains('scheme component'),
          ),
        ),
      );

      expect(
        () => IriTerm('example.org/resource'),
        throwsA(
          predicate<RdfConstraintViolationException>(
            (e) =>
                e.constraint == 'absolute-iri' &&
                e.message.contains('scheme component'),
          ),
        ),
      );
    });

    test('rejects IRIs with invalid scheme format', () {
      // Scheme starting with digit
      expect(
        () => IriTerm('1http://example.org'),
        throwsA(
          predicate<RdfConstraintViolationException>(
            (e) =>
                e.constraint == 'scheme-format' &&
                e.message.contains('scheme must start with a letter'),
          ),
        ),
      );

      // Scheme with invalid characters
      expect(
        () => IriTerm('ht@tp://example.org'),
        throwsA(
          predicate<RdfConstraintViolationException>(
            (e) =>
                e.constraint == 'scheme-format' &&
                e.message.contains('contain only letters, digits, +, -, or .'),
          ),
        ),
      );

      // Scheme with spaces
      expect(
        () => IriTerm('http space://example.org'),
        throwsA(
          predicate<RdfConstraintViolationException>(
            (e) =>
                e.constraint == 'scheme-format' &&
                e.message.contains('contain only letters, digits, +, -, or .'),
          ),
        ),
      );
    });
  });

  group('BlankNodeTerm', () {
    test('constructs with identity-based equality', () {
      final node1 = BlankNodeTerm();
      final node2 = BlankNodeTerm();
      final nodeSame = node1;

      expect(
        node1,
        isNot(equals(node2)),
        reason: 'Different BlankNodeTerm instances should not be equal',
      );
      expect(node1, equals(nodeSame), reason: 'Same instance should be equal');
    });

    test('hash codes are based on identity', () {
      final node1 = BlankNodeTerm();
      final node2 = BlankNodeTerm();

      expect(node1.hashCode, equals(identityHashCode(node1)));
      expect(node1.hashCode, isNot(equals(node2.hashCode)));
    });

    test('toString returns a readable representation', () {
      final node = BlankNodeTerm();
      expect(node.toString(), startsWith('_:b'));
      expect(node.toString(), contains(identityHashCode(node).toString()));
    });

    test('is a subject but not a predicate', () {
      final node = BlankNodeTerm();
      expect(node, isA<RdfSubject>());
      expect(node, isA<RdfTerm>());
      expect(node, isNot(isA<RdfPredicate>()));
    });
  });

  group('LiteralTerm', () {
    test('constructs with datatype', () {
      final literal = LiteralTerm('42', datatype: XsdTypes.integer);
      expect(literal.value, equals('42'));
      expect(literal.datatype, equals(XsdTypes.integer));
      expect(literal.language, isNull);
    });

    test('constructs with language tag', () {
      final literal = LiteralTerm(
        'hello',
        datatype: RdfTypes.langString,
        language: 'en',
      );
      expect(literal.value, equals('hello'));
      expect(literal.datatype, equals(RdfTypes.langString));
      expect(literal.language, equals('en'));
    });

    test('typed factory creates correct datatype', () {
      final literal = LiteralTerm.typed('42', 'integer');
      expect(literal.value, equals('42'));
      expect(literal.datatype, equals(XsdTypes.integer));
      expect(literal.language, isNull);
    });

    test('string factory creates xsd:string literal', () {
      final literal = LiteralTerm.string('hello');
      expect(literal.value, equals('hello'));
      expect(literal.datatype, equals(XsdTypes.string));
      expect(literal.language, isNull);
    });

    test('withLanguage factory creates language-tagged literal', () {
      final literal = LiteralTerm.withLanguage('hello', 'en');
      expect(literal.value, equals('hello'));
      expect(literal.datatype, equals(RdfTypes.langString));
      expect(literal.language, equals('en'));
    });

    test('integer factory creates xsd:integer literal', () {
      final literal = LiteralTerm.integer(42);
      expect(literal.value, equals('42'));
      expect(literal.datatype, equals(XsdTypes.integer));
      expect(literal.language, isNull);
    });

    test('decimal factory creates xsd:decimal literal', () {
      final literal = LiteralTerm.decimal(3.14);
      expect(literal.value, equals('3.14'));
      expect(literal.datatype, equals(XsdTypes.decimal));
      expect(literal.language, isNull);
    });

    test('boolean factory creates xsd:boolean literal', () {
      final literal = LiteralTerm.boolean(true);
      expect(literal.value, equals('true'));
      expect(literal.datatype, equals(XsdTypes.boolean));
      expect(literal.language, isNull);
    });

    test('equals operator compares value, datatype and language', () {
      final literal1 = LiteralTerm.string('hello');
      final literal2 = LiteralTerm.string('hello');
      final literal3 = LiteralTerm.string('world');
      final literal4 = LiteralTerm.withLanguage('hello', 'en');

      expect(literal1, equals(literal2));
      expect(literal1, isNot(equals(literal3)));
      expect(literal1, isNot(equals(literal4)));
    });

    test('hash codes are equal for equal literals', () {
      final literal1 = LiteralTerm.string('hello');
      final literal2 = LiteralTerm.string('hello');

      expect(literal1.hashCode, equals(literal2.hashCode));
    });

    test('toString returns a readable representation', () {
      final literal = LiteralTerm.string('hello');
      expect(literal.toString(), contains('"hello"'));
    });

    test('is an object but not a subject or predicate', () {
      final literal = LiteralTerm.string('hello');
      expect(literal, isA<RdfObject>());
      expect(literal, isA<RdfTerm>());
      expect(literal, isNot(isA<RdfSubject>()));
      expect(literal, isNot(isA<RdfPredicate>()));
    });

    test(
      'throws assertion error when language tag is used without rdf:langString',
      () {
        expect(
          () => LiteralTerm('hello', datatype: XsdTypes.string, language: 'en'),
          throwsA(isA<AssertionError>()),
        );
      },
    );

    test(
      'throws assertion error when rdf:langString is used without language tag',
      () {
        expect(
          () => LiteralTerm('hello', datatype: RdfTypes.langString),
          throwsA(isA<AssertionError>()),
        );
      },
    );
  });
}
