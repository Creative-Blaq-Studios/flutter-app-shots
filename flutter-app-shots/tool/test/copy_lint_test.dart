// flutter-app-shots/tool/test/copy_lint_test.dart
//
// Ported verbatim from compositor/src/copyLint.ts.
import 'package:app_shots/src/copy_lint.dart';
import 'package:test/test.dart';

void main() {
  group('rankingClaims', () {
    test('has the exact 7 verbatim claims from RANKING_CLAIMS', () {
      expect(rankingClaims, [
        '#1',
        'number 1',
        'number one',
        'best',
        'top app',
        "world's best",
        'million downloads',
      ]);
    });

    test('every claim flags on both stores', () {
      for (final claim in rankingClaims) {
        for (final store in ['app_store', 'play_store']) {
          final r = lintCopy('Check out $claim today', store);
          expect(r.ok, isFalse, reason: '"$claim" should flag on $store');
          expect(
            r.issues,
            contains('unsupported ranking/superlative claim: "$claim"'),
            reason: '"$claim" issue string on $store',
          );
        }
      }
    });
  });

  group('ctaClaims', () {
    test('has the exact 8 verbatim claims from CTA_CLAIMS', () {
      expect(ctaClaims, [
        'download now',
        'install now',
        'play now',
        'try now',
        'buy now',
        'sale',
        'discount',
        'limited time',
      ]);
    });

    test('every claim flags ONLY on play_store, not app_store', () {
      for (final claim in ctaClaims) {
        final appResult = lintCopy('Please $claim for a surprise', 'app_store');
        expect(appResult.ok, isTrue,
            reason: '"$claim" must pass lint on app_store');

        final playResult =
            lintCopy('Please $claim for a surprise', 'play_store');
        expect(playResult.ok, isFalse,
            reason: '"$claim" must fail lint on play_store');
        expect(
          playResult.issues,
          contains(
              'call-to-action/time-pressure not allowed on Google Play: "$claim"'),
        );
      }
    });

    test('"download now" passes lint on app_store, fails on play_store', () {
      expect(lintCopy('download now', 'app_store').ok, isTrue);
      expect(lintCopy('download now', 'play_store').ok, isFalse);
    });
  });

  group('word-boundary safety', () {
    test('"wholesale prices" does not flag "sale" on either store', () {
      expect(lintCopy('wholesale prices', 'app_store').ok, isTrue);
      expect(lintCopy('wholesale prices', 'play_store').ok, isTrue);
    });

    test('"our bestseller list" does not flag "best" on either store', () {
      expect(lintCopy('our bestseller list', 'app_store').ok, isTrue);
      expect(lintCopy('our bestseller list', 'play_store').ok, isTrue);
    });

    test('"#1" still flags as a standalone token', () {
      final r = lintCopy('We are the #1 app', 'app_store');
      expect(r.ok, isFalse);
      expect(r.issues, contains('unsupported ranking/superlative claim: "#1"'));
    });
  });

  group('case-insensitivity', () {
    test('"The BEST app" flags "best"', () {
      final r = lintCopy('The BEST app', 'app_store');
      expect(r.ok, isFalse);
      expect(
          r.issues, contains('unsupported ranking/superlative claim: "best"'));
    });
  });

  group('exact issue-string formats', () {
    test('ranking issue string is verbatim', () {
      final r = lintCopy('This is the best', 'app_store');
      expect(
          r.issues, contains('unsupported ranking/superlative claim: "best"'));
    });

    test('CTA issue string is verbatim', () {
      final r = lintCopy('Enjoy the sale', 'play_store');
      expect(
          r.issues,
          contains(
              'call-to-action/time-pressure not allowed on Google Play: "sale"'));
    });
  });

  group('LintResult shape', () {
    test('ok is true and issues empty for clean copy', () {
      final r = lintCopy('Track every wallet in one place', 'play_store');
      expect(r.ok, isTrue);
      expect(r.issues, isEmpty);
    });

    test('ok is false iff issues is non-empty', () {
      final clean = lintCopy('Track every wallet', 'app_store');
      expect(clean.ok, clean.issues.isEmpty);

      final dirty = lintCopy('Sale! Buy now, we are #1', 'play_store');
      expect(dirty.ok, dirty.issues.isEmpty);
      expect(dirty.ok, isFalse);
    });
  });
}
