import 'package:test/test.dart';
import 'package:rdf_core/src/iri_util.dart';
import 'package:rdf_core/rdf_core.dart';

void main() {
  group('relativizeIri', () {
    group('basic relativization', () {
      test('should relativize simple path', () {
        final result = relativizeIri(
          'http://example.org/path/file.txt',
          'http://example.org/path/',
        );
        expect(result, equals('file.txt'));
      });

      test('path ending on slash, base not ending on slash', () {
        final result = relativizeIri(
          'https://example.com/user/account/',
          'https://example.com/johndoe',
        );
        expect(result, equals('user/account/'));
      });
      test('path and base nearly equal, path ends on slash', () {
        final result = relativizeIri(
          'https://example.com/johndoe/',
          'https://example.com/johndoe',
        );
        expect(result, equals('johndoe/'));
      });
      test('path and base nearly equal, base ends on slash', () {
        final result = relativizeIri(
          'https://example.com/johndoe',
          'https://example.com/johndoe/',
        );
        expect(result, equals('/johndoe'));
      });
      test('path not ending on slash, base not ending on slash', () {
        final result = relativizeIri(
          'https://example.com/user/settings/private-index.ttl',
          'https://example.com/johndoe',
        );
        expect(result, equals('user/settings/private-index.ttl'));
      });

      test('should relativize nested path', () {
        final result = relativizeIri(
          'http://example.org/path/subdir/file.txt',
          'http://example.org/path/',
        );
        expect(result, equals('subdir/file.txt'));
      });

      test('should return empty string for identical IRIs', () {
        final result = relativizeIri(
          'http://example.org/document',
          'http://example.org/document',
        );
        expect(result, equals(''));
      });

      test('should relativize fragment-only differences', () {
        final result = relativizeIri(
          'http://example.org/path#section',
          'http://example.org/path#',
        );
        expect(result, equals('#section'));
      });

      test('should relativize toplevel', () {
        final result = relativizeIri(
          'http://example.org/settings/prefs.ttl',
          'http://example.org/kk/profile/card#me',
        );
        expect(result, equals('/settings/prefs.ttl'));
      });

      test(
          'should relativize TTL file with fragment against same TTL file base',
          () {
        // Test case for potential bug with fragment relativization
        final result = relativizeIri(
          'http://example.org/storage/solidtask/task/task456.ttl#vectorclock-user123',
          'http://example.org/storage/solidtask/task/task456.ttl',
        );
        // Expected: should return '#vectorclock-user123' since only fragment differs
        expect(result, equals('#vectorclock-user123'));
      });

      test('should relativize filename against fragment base', () {
        final result = relativizeIri(
          'http://my.host/foo',
          'http://my.host/path#',
        );
        expect(result, equals('foo'));
      });
    });

    group('dot notation relativization', () {
      test('should generate ../ for sibling directories', () {
        final result = relativizeIri(
          'http://example.org/docs/other/file.txt',
          'http://example.org/docs/current/',
        );
        expect(result, equals('../other/file.txt'));
      });

      test('should generate ../ for parent directory files', () {
        final result = relativizeIri(
          'http://example.org/docs/readme.txt',
          'http://example.org/docs/current/page.html',
        );
        expect(result, equals('../readme.txt'));
      });

      test('should generate ../../ for files two levels up', () {
        final result = relativizeIri(
          'http://example.org/readme.txt',
          'http://example.org/docs/current/',
          options: IriRelativizationOptions.full().copyWith(
            allowAbsolutePath: false,
          ),
        );
        expect(result, equals('../../readme.txt'));
      });

      test('should not generate more than 2 levels of ../..', () {
        final result = relativizeIri(
          'http://example.org/readme.txt',
          'http://example.org/docs/deep/nested/',
          options: IriRelativizationOptions.full().copyWith(
            maxUpLevels: 2,
            allowAbsolutePath: false,
          ),
        );
        // Should not relativize because it would require ../../../
        expect(result, equals('http://example.org/readme.txt'));
      });

      test('should handle query and fragment in dot notation', () {
        final result = relativizeIri(
          'http://example.org/docs/other/file.txt?param=value#section',
          'http://example.org/docs/current/',
        );
        expect(result, equals('../other/file.txt?param=value#section'));
      });

      test('should relativize subdirectory files without dots', () {
        final result = relativizeIri(
          'http://example.org/docs/current/sub/file.txt',
          'http://example.org/docs/current/',
        );
        expect(result, equals('sub/file.txt'));
      });

      test('should maintain roundtrip consistency for dot notation', () {
        const baseIri = 'http://example.org/docs/current/';
        const originalIri = 'http://example.org/docs/other/file.txt';

        final relative = relativizeIri(originalIri, baseIri);
        final resolved = resolveIri(relative, baseIri);

        expect(relative, equals('../other/file.txt'));
        expect(resolved, equals(originalIri));
      });

      test('should not relativize unrelated paths', () {
        final result = relativizeIri(
          'http://example.org/completely/different/path/file.txt',
          'http://example.org/docs/current/',
          options: IriRelativizationOptions.full().copyWith(
              allowSiblingDirectories: false, allowAbsolutePath: false),
        );
        // No common prefix, should not relativize
        expect(result,
            equals('http://example.org/completely/different/path/file.txt'));
      });

      test('should prefer shorter relative paths', () {
        final result = relativizeIri(
          'http://a.org/b',
          'http://a.org/a/very/long/path/name/so/much/longer/',
          options: IriRelativizationOptions.full().copyWith(
            allowAbsolutePath: false,
          ),
        );
        // Absolute iri "http://a.org/b" is shorter than "../../../../../../../b"
        expect(result, equals('http://a.org/b'));
      });
    });

    group('absolute-path relativization', () {
      test('should prefer absolute-path when shorter than dot notation', () {
        final result = relativizeIri(
          'http://example.org/simple.txt',
          'http://example.org/a/very/long/path/file.html',
        );
        // '/simple.txt' is shorter than '../../../../simple.txt'
        expect(result, equals('/simple.txt'));
      });

      test('should use absolute-path for toplevel relativization', () {
        final result = relativizeIri(
          'http://example.org/settings/prefs.ttl',
          'http://example.org/kk/profile/card#me',
        );
        expect(result, equals('/settings/prefs.ttl'));
      });

      test('should use dot notation when shorter than absolute-path', () {
        final result = relativizeIri(
          'http://example.org/docs/other/file.txt',
          'http://example.org/docs/current/',
        );
        // '../other/file.txt' is shorter than '/docs/other/file.txt'
        expect(result, equals('../other/file.txt'));
      });

      test('should disable absolute-path when allowAbsolutePath is false', () {
        final result = relativizeIri(
          'http://example.org/simple.txt',
          'http://example.org/a/very/long/path/file.html',
          options: IriRelativizationOptions.full().copyWith(
            allowAbsolutePath: false,
          ),
        );
        // Should use dot notation or fall back to absolute IRI
        expect(result, equals('../../../../simple.txt'));
      });
      test('should disable absolute-path when allowAbsolutePath is false 2', () {
        final result = relativizeIri(
          'http://my.host/other',
          'http://my.host/path/',
          options: IriRelativizationOptions.full().copyWith(
            allowAbsolutePath: false,
          ),
        );
        // Should use dot notation or fall back to absolute IRI
        expect(result, equals('../other'));
      });
    });

    group('configurable relativization options', () {
      test('conservative mode should limit relativization', () {
        final result = relativizeIri(
          'http://example.org/other/file',
          'http://example.org/path/',
          options: IriRelativizationOptions.local(),
        );
        // Conservative mode doesn't allow cross-directory navigation
        expect(result, equals('http://example.org/other/file'));
      });

      test('aggressive mode should allow sibling directories', () {
        final result = relativizeIri(
          'http://example.org/other/file',
          'http://example.org/path/',
          options: IriRelativizationOptions.full().copyWith(
            allowAbsolutePath: false,
          ),
        );
        // Aggressive mode allows sibling directory navigation
        expect(result, equals('../other/file'));
      });

      test('full mode should follow default behavior', () {
        final resultWithOptions = relativizeIri(
          'http://example.org/docs/other/file.txt',
          'http://example.org/docs/current/',
          options: IriRelativizationOptions.full(),
        );
        final resultDefault = relativizeIri(
          'http://example.org/docs/other/file.txt',
          'http://example.org/docs/current/',
        );
        expect(resultWithOptions, equals(resultDefault));
        expect(resultWithOptions, equals('../other/file.txt'));
      });

      test('custom options should limit max up levels', () {
        final result = relativizeIri(
          'http://example.org/readme.txt',
          'http://example.org/docs/very/deep/',
          options: IriRelativizationOptions.full().copyWith(
            maxUpLevels: 2,
            allowAbsolutePath: false,
          ),
        );
        // Would require 3 "../" levels, but limit is 2
        expect(result, equals('http://example.org/readme.txt'));
      });

      test('custom options should limit additional length', () {
        final result = relativizeIri(
          'http://e.org/f',
          'http://e.org/very/deeply/nested/directory/so/very/deep',
          options:
              IriRelativizationOptions.full().copyWith(maxAdditionalLength: 3),
        );
        // Absolute-path "/f" is much shorter than both the original IRI and dot notation
        expect(result, equals('/f'));
      });

      test('serialization mode should be more aggressive than moderate', () {
        final result = relativizeIri(
          'http://example.org/other/file',
          'http://example.org/path/',
          options: IriRelativizationOptions.full().copyWith(
            allowAbsolutePath: false,
          ),
        );
        // Serialization mode should allow sibling directories
        expect(result, equals('../other/file'));
      });

      test('options should allow roundtrip consistency', () {
        const baseIri = 'http://example.org/docs/current/';
        const originalIri = 'http://example.org/other/file.txt';

        final options = IriRelativizationOptions.full();
        final relative = relativizeIri(originalIri, baseIri, options: options);
        final resolved = resolveIri(relative, baseIri);

        expect(relative, equals('/other/file.txt'));
        expect(resolved, equals(originalIri));
      });
    });

    group('edge cases', () {
      test('should return original IRI when baseIri is null', () {
        final result = relativizeIri('http://example.org/file', null);
        expect(result, equals('http://example.org/file'));
      });

      test('should return original IRI when baseIri is empty', () {
        final result = relativizeIri('http://example.org/file', '');
        expect(result, equals('http://example.org/file'));
      });

      test('should not relativize different schemes', () {
        final result = relativizeIri(
          'https://example.org/file',
          'http://example.org/',
        );
        expect(result, equals('https://example.org/file'));
      });

      test('should not relativize different authorities', () {
        final result = relativizeIri(
          'http://other.org/file',
          'http://example.org/',
        );
        expect(result, equals('http://other.org/file'));
      });

      test('should relativize to empty when path iri equals base', () {
        final cases = [
          'http://example.org/other/file',
          'http://example.org/myFile.txt',
        ];
        final opts = [
          (IriRelativizationOptions.none(), false),
          (IriRelativizationOptions.local(), true),
          (IriRelativizationOptions.full(), true)
        ];
        for (final f in cases) {
          for (final (opt, isRelative) in opts) {
            final result = relativizeIri(
              f,
              f,
              options: opt,
            );

            expect(result, equals(isRelative ? '' : f),
                reason: 'Failed for $f with options $opt');
          }
        }
      });
      test('should not relativize when path does not match', () {
        final result = relativizeIri(
          'http://example.org/other/file',
          'http://example.org/path/',
          options: IriRelativizationOptions.local(),
        );
        expect(result, equals('http://example.org/other/file'));
      });

      test('should not relativize when relativization disabled', () {
        final result = relativizeIri(
          'http://example.org/path/file',
          'http://example.org/path/',
          options: IriRelativizationOptions.none(),
        );
        expect(result, equals('http://example.org/path/file'));
        final localResult = relativizeIri(
          'http://example.org/path/file',
          'http://example.org/path/',
          options: IriRelativizationOptions.local(),
        );
        expect(localResult, equals('file'));
        final defaultResult = relativizeIri(
          'http://example.org/path/file',
          'http://example.org/path/',
        );
        expect(defaultResult, equals('file'));
      });
      test('should handle malformed IRIs gracefully', () {
        final result = relativizeIri('not-a-valid-iri', 'http://example.org/');
        expect(result, equals('not-a-valid-iri'));
      });

      test('should handle malformed base IRI gracefully', () {
        final result = relativizeIri(
          'http://example.org/file',
          'not-a-valid-base',
        );
        expect(result, equals('http://example.org/file'));
      });
    });

    group('complex scenarios', () {
      test('should handle query parameters in target IRI', () {
        final result = relativizeIri(
          'http://example.org/path/file?param=value',
          'http://example.org/path/',
        );
        expect(result, equals('file?param=value'));
      });

      test('should handle fragments in target IRI', () {
        final result = relativizeIri(
          'http://example.org/path/file#section',
          'http://example.org/path/',
        );
        expect(result, equals('file#section'));
      });

      test('should handle query and fragment in target IRI', () {
        final result = relativizeIri(
          'http://example.org/path/file?param=value#section',
          'http://example.org/path/',
        );
        expect(result, equals('file?param=value#section'));
      });

      test('should not relativize when base has query', () {
        // According to RFC 3986, relativization against base with query is unsafe
        // because resolution ignores the base's query component
        final result = relativizeIri(
          'http://example.org/path/file',
          'http://example.org/path/?query=value',
        );
        expect(result, equals('http://example.org/path/file'));
      });

      test('should relativize when base has fragment', () {
        // Per RFC 3986 Section 5.1, fragments in base URI should be stripped
        // before relativization, making this relativization safe and correct
        final result = relativizeIri(
          'http://example.org/path/file',
          'http://example.org/path/#fragment',
        );
        expect(result, equals('file'));
      });
    });

    group('roundtrip consistency', () {
      test('should maintain roundtrip consistency for simple paths', () {
        const baseIri = 'http://example.org/path/';
        const originalIri = 'http://example.org/path/file.txt';

        final relative = relativizeIri(originalIri, baseIri);
        final resolved = resolveIri(relative, baseIri);

        expect(resolved, equals(originalIri));
      });

      test('should maintain roundtrip consistency for fragments', () {
        const baseIri = 'http://example.org/document';
        const originalIri = 'http://example.org/document#section';

        final relative = relativizeIri(originalIri, baseIri);
        final resolved = resolveIri(relative, baseIri);

        expect(resolved, equals(originalIri));
      });

      test(
        'should maintain roundtrip consistency for filename relativization',
        () {
          const baseIri = 'http://my.host/path#';
          const originalIri = 'http://my.host/foo';

          final relative = relativizeIri(originalIri, baseIri);
          final resolved = resolveIri(relative, baseIri);

          expect(resolved, equals(originalIri));
        },
      );

      test('should maintain roundtrip consistency for empty relative IRI', () {
        const baseIri = 'http://example.org/document';
        const originalIri = 'http://example.org/document';

        final relative = relativizeIri(originalIri, baseIri);
        final resolved = resolveIri(relative, baseIri);

        expect(resolved, equals(originalIri));
      });
    });
  });

  group('resolveIri', () {
    group('basic resolution', () {
      test('should resolve relative path', () {
        final result = resolveIri('file.txt', 'http://example.org/path/');
        expect(result, equals('http://example.org/path/file.txt'));
      });

      test('should resolve nested relative path', () {
        final result = resolveIri(
          'subdir/file.txt',
          'http://example.org/path/',
        );
        expect(result, equals('http://example.org/path/subdir/file.txt'));
      });

      test('should resolve fragment reference', () {
        final result = resolveIri('#section', 'http://example.org/document');
        expect(result, equals('http://example.org/document#section'));
      });

      test('should resolve absolute path', () {
        final result = resolveIri('/other/file', 'http://example.org/path/');
        expect(result, equals('http://example.org/other/file'));
      });

      test('should resolve empty relative IRI', () {
        final result = resolveIri('', 'http://example.org/document');
        expect(result, equals('http://example.org/document'));
      });
    });

    group('absolute IRI handling', () {
      test('should return absolute IRI unchanged', () {
        final result = resolveIri(
          'http://other.org/file',
          'http://example.org/base/',
        );
        expect(result, equals('http://other.org/file'));
      });

      test('should handle different schemes', () {
        final result = resolveIri(
          'https://secure.org/file',
          'http://example.org/',
        );
        expect(result, equals('https://secure.org/file'));
      });

      test('should handle file:// scheme', () {
        final result = resolveIri('file:///local/file', 'http://example.org/');
        expect(result, equals('file:///local/file'));
      });

      test('should handle custom schemes', () {
        final result = resolveIri('urn:example:123', 'http://example.org/');
        expect(result, equals('urn:example:123'));
      });
    });

    group('error handling', () {
      test('should throw BaseIriRequiredException when base IRI is null', () {
        expect(
          () => resolveIri('relative/path', null),
          throwsA(isA<BaseIriRequiredException>()),
        );
      });

      test('should throw BaseIriRequiredException when base IRI is empty', () {
        expect(
          () => resolveIri('relative/path', ''),
          throwsA(isA<BaseIriRequiredException>()),
        );
      });

      test('should include relative IRI in exception', () {
        try {
          resolveIri('relative/path', null);
          fail('Expected BaseIriRequiredException');
        } on BaseIriRequiredException catch (e) {
          expect(e.relativeUri, equals('relative/path'));
        }
      });
    });

    group('complex scenarios', () {
      test('should resolve relative path with query', () {
        final result = resolveIri(
          'file?param=value',
          'http://example.org/path/',
        );
        expect(result, equals('http://example.org/path/file?param=value'));
      });

      test('should resolve relative path with fragment', () {
        final result = resolveIri('file#section', 'http://example.org/path/');
        expect(result, equals('http://example.org/path/file#section'));
      });

      test('should resolve with query and fragment', () {
        final result = resolveIri(
          'file?param=value#section',
          'http://example.org/path/',
        );
        expect(
          result,
          equals('http://example.org/path/file?param=value#section'),
        );
      });

      test('should handle base IRI with fragment', () {
        final result = resolveIri('file', 'http://example.org/path#fragment');
        expect(result, equals('http://example.org/file'));
      });

      test('should replace fragment in base', () {
        final result = resolveIri('#new', 'http://example.org/doc#old');
        expect(result, equals('http://example.org/doc#new'));
      });
    });

    group('fallback resolution', () {
      test('should handle malformed base IRI in fragment case', () {
        // When Uri.parse fails, should fall back to manual resolution
        // Dart's Uri class percent-encodes invalid characters like [
        final result = resolveIri('#section', 'malformed[base');
        expect(result, equals('malformed%5Bbase#section'));
      });

      test('should handle malformed base IRI in absolute path case', () {
        // For absolute paths with malformed base, Dart's Uri.resolveUri
        // may not work as expected - this tests the actual behavior
        final result = resolveIri('/path', 'malformed[base');
        expect(result, equals('/path')); // Dart's Uri.resolveUri behavior
      });

      test('should handle malformed base IRI in relative path case', () {
        // When Uri.parse succeeds but creates encoded result
        final result = resolveIri('file', 'malformed[base/path/');
        expect(result, equals('malformed%5Bbase/path/file'));
      });
    });
  });

  group('BaseIriRequiredException', () {
    test('should have correct message format', () {
      const relativeIri = 'relative/path';
      final exception = BaseIriRequiredException(relativeUri: relativeIri);

      expect(
        exception.message,
        equals('Base IRI is required to resolve relative IRI: relative/path'),
      );
    });

    test('should have correct format', () {
      final exception = BaseIriRequiredException(relativeUri: 'test');
      expect(exception.format, equals('iri'));
    });

    test('should store relative IRI', () {
      const relativeIri = 'test/path';
      final exception = BaseIriRequiredException(relativeUri: relativeIri);
      expect(exception.relativeUri, equals(relativeIri));
    });
  });

  group('integration tests', () {
    group('RFC 3986 compliance', () {
      test('should handle RFC 3986 example 1', () {
        // Based on RFC 3986 Section 5.4.1
        const base = 'http://a/b/c/d;p?q';

        expect(resolveIri('g', base), equals('http://a/b/c/g'));
        expect(resolveIri('./g', base), equals('http://a/b/c/g'));
        expect(resolveIri('g/', base), equals('http://a/b/c/g/'));
        expect(resolveIri('/g', base), equals('http://a/g'));
        expect(resolveIri('?y', base), equals('http://a/b/c/d;p?y'));
        expect(resolveIri('#s', base), equals('http://a/b/c/d;p?q#s'));
      });

      test('should handle fragment base URIs correctly', () {
        const base = 'http://my.host/path#';

        // This should resolve to the parent directory of 'path'
        final resolved = resolveIri('foo', base);
        expect(resolved, equals('http://my.host/foo'));

        // And relativization should work in reverse
        final relativized = relativizeIri(resolved, base);
        expect(relativized, equals('foo'));
      });
    });

    group('non-URI IRI support', () {
      test('should handle URN schemes correctly', () {
        // URNs should be recognized as absolute
        expect(
          resolveIri('urn:isbn:0451450523', 'http://example.org/'),
          equals('urn:isbn:0451450523'),
        );
        expect(
          relativizeIri('urn:isbn:0451450523', 'http://example.org/'),
          equals('urn:isbn:0451450523'),
        );
      });

      test('should handle data URIs correctly', () {
        const dataUri = 'data:text/plain;base64,SGVsbG8gV29ybGQ=';
        expect(resolveIri(dataUri, 'http://example.org/'), equals(dataUri));
        expect(relativizeIri(dataUri, 'http://example.org/'), equals(dataUri));
      });

      test('should handle mailto URIs correctly', () {
        const mailtoUri = 'mailto:user@example.org';
        expect(resolveIri(mailtoUri, 'http://example.org/'), equals(mailtoUri));
        expect(
          relativizeIri(mailtoUri, 'http://example.org/'),
          equals(mailtoUri),
        );
      });

      test('should handle custom schemes correctly', () {
        const customUri = 'myscheme:resource123';
        expect(resolveIri(customUri, 'http://example.org/'), equals(customUri));
        expect(
          relativizeIri(customUri, 'http://example.org/'),
          equals(customUri),
        );
      });

      test('should handle international characters in IRIs', () {
        const intlIri = 'http://例え.テスト/ファイル';
        const intlBase = 'http://例え.テスト/';

        // Should not relativize different domains even with international chars
        expect(relativizeIri(intlIri, 'http://example.org/'), equals(intlIri));

        // International chars don't relativize due to different authority handling
        // This is expected behavior - international domains are complex
        expect(relativizeIri(intlIri, intlBase), equals(intlIri));
      });

      test('should handle malformed scheme identifiers', () {
        // Scheme starting with number is actually valid per our implementation
        expect(
          resolveIri('123:invalid', 'http://example.org/'),
          equals('123:invalid'),
        ); // Treated as absolute

        // Scheme with space (invalid) should be treated as relative
        expect(
          resolveIri('a b:test', 'http://example.org/'),
          equals('http://example.org/a b:test'),
        );

        // Critical: relativization must NOT produce scheme-like strings
        // that would be misinterpreted as absolute IRIs
        expect(
          relativizeIri(
            'http://example.org/123:invalid',
            'http://example.org/',
          ),
          equals('http://example.org/123:invalid'),
        ); // Should NOT relativize to '123:invalid'
      });

      test('should handle edge case IRIs gracefully', () {
        // Empty string
        expect(
          resolveIri('', 'http://example.org/'),
          equals('http://example.org/'),
        );

        // Single colon
        expect(
          resolveIri(':', 'http://example.org/'),
          equals('http://example.org/:'),
        );

        // Fragment only
        expect(
          resolveIri('#section', 'http://example.org/doc'),
          equals('http://example.org/doc#section'),
        );

        // Query only
        expect(
          resolveIri('?query=value', 'http://example.org/path/'),
          equals('http://example.org/path/?query=value'),
        );
      });
    });

    group('real-world scenarios', () {
      test('should handle RDF/XML base URI scenarios', () {
        const baseIri = 'http://example.org/ontology/';

        // Common RDF property
        final resolved1 = resolveIri('hasName', baseIri);
        expect(resolved1, equals('http://example.org/ontology/hasName'));

        // External reference
        final resolved2 = resolveIri(
          'http://www.w3.org/2000/01/rdf-schema#label',
          baseIri,
        );
        expect(resolved2, equals('http://www.w3.org/2000/01/rdf-schema#label'));

        // Fragment identifier
        final resolved3 = resolveIri('#Person', baseIri);
        expect(resolved3, equals('http://example.org/ontology/#Person'));
      });

      test('should handle Turtle/N3 base scenarios', () {
        const baseIri = 'http://example.org/data/';

        // Relative resource
        final resolved1 = resolveIri('resource1', baseIri);
        expect(resolved1, equals('http://example.org/data/resource1'));

        // Subdirectory resource
        final resolved2 = resolveIri('people/john', baseIri);
        expect(resolved2, equals('http://example.org/data/people/john'));
      });

      test('should handle document-relative references', () {
        const baseIri = 'http://example.org/docs/guide.html';

        // Same directory
        final resolved1 = resolveIri('intro.html', baseIri);
        expect(resolved1, equals('http://example.org/docs/intro.html'));

        // Fragment in same document
        final resolved2 = resolveIri('#chapter1', baseIri);
        expect(
          resolved2,
          equals('http://example.org/docs/guide.html#chapter1'),
        );

        // Parent directory
        final resolved3 = resolveIri('../index.html', baseIri);
        expect(resolved3, equals('http://example.org/index.html'));
      });
    });

    group('performance edge cases', () {
      test('should handle very long IRIs', () {
        final longPath = 'very/' * 100 + 'long/path';
        final baseIri = 'http://example.org/';
        final longIri = 'http://example.org/$longPath';

        final relativized = relativizeIri(longIri, baseIri);
        final resolved = resolveIri(relativized, baseIri);

        expect(resolved, equals(longIri));
      });

      test('should handle IRIs with special characters', () {
        const baseIri = 'http://example.org/';
        const specialIri = 'http://example.org/file%20with%20spaces.txt';

        final relativized = relativizeIri(specialIri, baseIri);
        final resolved = resolveIri(relativized, baseIri);

        expect(resolved, equals(specialIri));
      });

      test('should handle international characters in IRIs', () {
        const baseIri = 'http://example.org/';
        const intlIri = 'http://example.org/файл.txt';

        final relativized = relativizeIri(intlIri, baseIri);
        final resolved = resolveIri(relativized, baseIri);

        expect(resolved, equals(intlIri));
      });
    });
  });
}
