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
        XsdTypes.string,
        equals(IriTerm('http://www.w3.org/2001/XMLSchema#string')),
      );
    });

    test('booleanIri has correct value', () {
      expect(
        XsdTypes.boolean,
        equals(IriTerm('http://www.w3.org/2001/XMLSchema#boolean')),
      );
    });

    test('integerIri has correct value', () {
      expect(
        XsdTypes.integer,
        equals(IriTerm('http://www.w3.org/2001/XMLSchema#integer')),
      );
    });

    test('decimalIri has correct value', () {
      expect(
        XsdTypes.decimal,
        equals(IriTerm('http://www.w3.org/2001/XMLSchema#decimal')),
      );
    });

    test('makeIri creates correct IRI from local name', () {
      expect(
        XsdTypes.makeIri('double'),
        equals(IriTerm('http://www.w3.org/2001/XMLSchema#double')),
      );

      expect(
        XsdTypes.makeIri('float'),
        equals(IriTerm('http://www.w3.org/2001/XMLSchema#float')),
      );

      // Verify custom types work too
      expect(
        XsdTypes.makeIri('customType'),
        equals(IriTerm('http://www.w3.org/2001/XMLSchema#customType')),
      );
    });

    test('predefined constants equal their makeIri equivalents', () {
      expect(XsdTypes.string, equals(XsdTypes.makeIri('string')));
      expect(XsdTypes.integer, equals(XsdTypes.makeIri('integer')));
      expect(XsdTypes.boolean, equals(XsdTypes.makeIri('boolean')));
    });
  });
}
