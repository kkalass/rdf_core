import 'package:rdf_core/src/graph/rdf_term.dart';
import 'package:rdf_core/src/vocab/xsd.dart';
import 'package:test/test.dart';

void main() {
  group('Xsd', () {
    test('namespace uses correct XSD namespace URI', () {
      expect(Xsd.namespace, equals('http://www.w3.org/2001/XMLSchema#'));
    });

    test('stringIri has correct value', () {
      expect(
        Xsd.string,
        equals(const IriTerm('http://www.w3.org/2001/XMLSchema#string')),
      );
    });

    test('booleanIri has correct value', () {
      expect(
        Xsd.boolean,
        equals(const IriTerm('http://www.w3.org/2001/XMLSchema#boolean')),
      );
    });

    test('integerIri has correct value', () {
      expect(
        Xsd.integer,
        equals(const IriTerm('http://www.w3.org/2001/XMLSchema#integer')),
      );
    });

    test('decimalIri has correct value', () {
      expect(
        Xsd.decimal,
        equals(const IriTerm('http://www.w3.org/2001/XMLSchema#decimal')),
      );
    });

    test('makeIri creates correct IRI from local name', () {
      expect(
        Xsd.makeIri('double'),
        equals(const IriTerm('http://www.w3.org/2001/XMLSchema#double')),
      );

      expect(
        Xsd.makeIri('float'),
        equals(const IriTerm('http://www.w3.org/2001/XMLSchema#float')),
      );

      // Verify custom types work too
      expect(
        Xsd.makeIri('customType'),
        equals(const IriTerm('http://www.w3.org/2001/XMLSchema#customType')),
      );
    });

    test('predefined constants equal their makeIri equivalents', () {
      expect(Xsd.string, equals(Xsd.makeIri('string')));
      expect(Xsd.integer, equals(Xsd.makeIri('integer')));
      expect(Xsd.boolean, equals(Xsd.makeIri('boolean')));
    });
  });
}
