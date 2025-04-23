import 'package:solid_task/ext/rdf/core/graph/rdf_term.dart';
import 'package:solid_task/ext/rdf/core/graph/triple.dart';
import 'package:test/test.dart';

void main() {
  group('Triple', () {
    late IriTerm subject;
    late IriTerm predicate;
    late LiteralTerm object;
    late Triple triple;

    setUp(() {
      subject = const IriTerm('http://example.org/subject');
      predicate = const IriTerm('http://example.org/predicate');
      object = LiteralTerm.string('object');
      triple = Triple(subject, predicate, object);
    });

    test('constructs with valid components', () {
      expect(triple.subject, equals(subject));
      expect(triple.predicate, equals(predicate));
      expect(triple.object, equals(object));
    });

    test('constructs with blank node subject', () {
      final blankSubject = const BlankNodeTerm('b1');
      final t = Triple(blankSubject, predicate, object);
      expect(t.subject, equals(blankSubject));
    });

    test('constructs with IRI object', () {
      final iriObject = const IriTerm('http://example.org/object');
      final t = Triple(subject, predicate, iriObject);
      expect(t.object, equals(iriObject));
    });

    test('constructs with blank node object', () {
      final blankObject = const BlankNodeTerm('b2');
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
      expect(triple.toString(), contains('Triple('));
      expect(triple.toString(), contains(subject.toString()));
      expect(triple.toString(), contains(predicate.toString()));
      expect(triple.toString(), contains(object.toString()));
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