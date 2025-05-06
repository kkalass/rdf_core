import 'package:rdf_core/src/graph/rdf_term.dart';
import 'package:rdf_core/src/graph/triple.dart';
import 'package:test/test.dart';

void main() {
  group('Triple', () {
    late IriTerm subject;
    late IriTerm predicate;
    late LiteralTerm object;
    late Triple triple;

    setUp(() {
      subject = IriTerm('http://example.org/subject');
      predicate = IriTerm('http://example.org/predicate');
      object = LiteralTerm.string('object');
      triple = Triple(subject, predicate, object);
    });

    test('constructs with valid components', () {
      expect(triple.subject, equals(subject));
      expect(triple.predicate, equals(predicate));
      expect(triple.object, equals(object));
    });

    test('constructs with blank node subject', () {
      final blankSubject = BlankNodeTerm();
      final t = Triple(blankSubject, predicate, object);
      expect(t.subject, equals(blankSubject));
    });

    test('constructs with IRI object', () {
      final iriObject = IriTerm('http://example.org/object');
      final t = Triple(subject, predicate, iriObject);
      expect(t.object, equals(iriObject));
    });

    test('constructs with blank node object', () {
      final blankObject = BlankNodeTerm();
      final t = Triple(subject, predicate, blankObject);
      expect(t.object, equals(blankObject));
    });

    test('equals operator compares all components', () {
      final t1 = Triple(subject, predicate, object);
      final t2 = Triple(subject, predicate, object);
      final t3 = Triple(subject, predicate, LiteralTerm.string('different'));

      expect(t1, equals(t2));
      expect(t1, isNot(equals(t3)));
    });

    test('hash codes are equal for equal triples', () {
      final t1 = Triple(subject, predicate, object);
      final t2 = Triple(subject, predicate, object);

      expect(t1.hashCode, equals(t2.hashCode));
    });

    test('toString returns a readable representation', () {
      expect(triple.toString(), contains(subject.toString()));
      expect(triple.toString(), contains(predicate.toString()));
      expect(triple.toString(), contains(object.toString()));
    });

    test('blank node equality respects object identity', () {
      final b1 = BlankNodeTerm();
      final b2 = BlankNodeTerm();
      final same = b1;

      final t1 = Triple(b1, predicate, object);
      final t2 = Triple(b2, predicate, object);
      final t3 = Triple(same, predicate, object);

      expect(
        t1,
        isNot(equals(t2)),
        reason: 'Triples with different blank nodes should not be equal',
      );
      expect(
        t1,
        equals(t3),
        reason: 'Triples with identical blank nodes should be equal',
      );
    });

    /*
    test('throws ArgumentError when subject is invalid', () {
      // Create a dummy class that improperly implements RdfSubject
      // Note: This test uses a local class to verify constraints aren't just type-based
      final invalidSubject = _InvalidSubject();
      
      expect(
        () => Triple(invalidSubject, predicate, object),
        throwsArgumentError,
      );
    });
    */
  });
}

/*
/// Helper class for testing validation logic
class _InvalidSubject implements RdfSubject {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
*/
