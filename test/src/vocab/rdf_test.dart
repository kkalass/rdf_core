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
        Rdf.type,
        equals(
            const IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#type')),
      );
    });

    test('langStringIri has correct value', () {
      expect(
        Rdf.langString,
        equals(
          const IriTerm(
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
        final typeIri = Rdf.type as dynamic;
        typeIri.iri = 'modified';
      }, throwsNoSuchMethodError);
    });

    test('all RDF terms are correctly constructed from namespace', () {
      // Test a few random RDF vocabulary terms to ensure they're constructed correctly
      expect(Rdf.first, equals(IriTerm('${Rdf.namespace}first')));
      expect(Rdf.rest, equals(IriTerm('${Rdf.namespace}rest')));
      expect(Rdf.nil, equals(IriTerm('${Rdf.namespace}nil')));
    });
  });
}
