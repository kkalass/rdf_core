import 'package:rdf_core/src/graph/rdf_term.dart';
import 'package:rdf_core/src/vocab/rdf.dart';
import 'package:test/test.dart';

void main() {
  group('Rdf', () {
    test('namespace uses correct RDF namespace URI', () {
      expect(
        Rdf.namespace,
        equals('http://www.w3.org/1999/02/22-rdf-syntax-ns#'),
      );
    });

    test('typeIri has correct value', () {
      expect(
        RdfPredicates.type,
        equals(IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#type')),
      );
    });

    test('langStringIri has correct value', () {
      expect(
        RdfTypes.langString,
        equals(
          const IriTerm.prevalidated(
            'http://www.w3.org/1999/02/22-rdf-syntax-ns#langString',
          ),
        ),
      );
    });

    test('prefix has correct value', () {
      expect(Rdf.prefix, equals('rdf'));
    });

    test('constant IRIs are immutable', () {
      expect(() {
        // This should not compile, but we'll check it at runtime too
        // Dynamic cast is used to bypass compile-time check for demonstration
        final typeIri = RdfPredicates.type as dynamic;
        typeIri.iri = 'modified';
      }, throwsNoSuchMethodError);
    });
  });
}
