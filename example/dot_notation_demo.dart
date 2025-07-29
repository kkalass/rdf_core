import 'package:rdf_core/src/iri_util.dart';
import 'package:rdf_core/rdf_core.dart';

/// Demonstrates the enhanced relativizeIri function with configurable options.
void main() {
  print('Enhanced relativizeIri with configurable dot notation support\n');

  // Test cases showing different types of relativization
  final testCases = [
    // Basic same-directory cases
    TestCase(
      'http://example.org/docs/file.txt',
      'http://example.org/docs/',
      'Same directory',
    ),

    // Sibling directory navigation
    TestCase(
      'http://example.org/docs/other/file.txt',
      'http://example.org/docs/current/',
      'Sibling directory',
    ),

    // Parent directory navigation
    TestCase(
      'http://example.org/docs/readme.txt',
      'http://example.org/docs/current/page.html',
      'Parent directory',
    ),

    // Root file from nested directory
    TestCase(
      'http://example.org/readme.txt',
      'http://example.org/docs/current/',
      'Root file from nested directory',
    ),

    // Fragment-only differences
    TestCase(
      'http://example.org/document#section',
      'http://example.org/document',
      'Fragment only',
    ),

    // Cases that should behave differently based on options
    TestCase(
      'http://example.org/other/file',
      'http://example.org/path/',
      'Sibling paths (options-dependent)',
    ),

    // Complex case with many levels
    TestCase(
      'http://example.org/readme.txt',
      'http://example.org/docs/very/deep/nested/',
      'Many levels up (options-dependent)',
    ),

    // Different domains (should never relativize)
    TestCase(
      'https://other.org/file',
      'http://example.org/',
      'Different domains',
    ),
  ];

  // Test different relativization modes
  final modes = {
    'None': IriRelativizationOptions.none(),
    'Local': IriRelativizationOptions.local(),
    'Full (default)': IriRelativizationOptions.full(),
  };

  for (final testCase in testCases) {
    print('${testCase.description}:');
    print('  Target: ${testCase.target}');
    print('  Base:   ${testCase.base}');

    for (final mode in modes.entries) {
      final result =
          relativizeIri(testCase.target, testCase.base, options: mode.value);
      final isRelativized = result != testCase.target;
      final symbol = isRelativized ? "✓" : "✗";

      print('  ${mode.key.padRight(20)}: $result ($symbol)');

      // Verify roundtrip consistency for relativized results
      if (isRelativized) {
        final resolved = resolveIri(result, testCase.base);
        final consistent = resolved == testCase.target;
        if (!consistent) {
          print('    ⚠️  Roundtrip failed: $resolved');
        }
      }
    }
    print('');
  }

  // Demonstrate custom options
  print('Custom Configuration Examples:\n');

  final customCases = [
    CustomOptionsDemo(
      'Limited up-levels',
      'http://example.org/file',
      'http://example.org/a/b/c/',
      IriRelativizationOptions.full().copyWith(maxUpLevels: 2),
    ),
    CustomOptionsDemo(
      'No sibling directories',
      'http://example.org/other/file',
      'http://example.org/path/',
      IriRelativizationOptions.full().copyWith(allowSiblingDirectories: false),
    ),
    CustomOptionsDemo(
      'Length-limited',
      'http://example.org/file',
      'http://example.org/very/deeply/nested/path/',
      IriRelativizationOptions.full().copyWith(maxAdditionalLength: 5),
    ),
  ];

  for (final demo in customCases) {
    final result = relativizeIri(demo.target, demo.base, options: demo.options);
    final isRelativized = result != demo.target;

    print('${demo.description}:');
    print('  Target: ${demo.target}');
    print('  Base:   ${demo.base}');
    print('  Options: ${demo.options}');
    print(
        '  Result: $result ${isRelativized ? "(✓ relativized)" : "(unchanged)"}');
    print('');
  }
}

class TestCase {
  final String target;
  final String base;
  final String description;

  const TestCase(this.target, this.base, this.description);
}

class CustomOptionsDemo {
  final String description;
  final String target;
  final String base;
  final IriRelativizationOptions options;

  const CustomOptionsDemo(
      this.description, this.target, this.base, this.options);
}
