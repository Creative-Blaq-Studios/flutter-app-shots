// flutter-app-shots/tool/lib/src/copy_lint.dart
//
// Copy lint rules ported verbatim from compositor/src/copyLint.ts.
// Every claim string and issue-message
// format below is copied verbatim; do not "clean up" or rephrase them.

/// Ranking/superlative claims flagged on every store. Verbatim
/// `RANKING_CLAIMS` from copyLint.ts.
const List<String> rankingClaims = [
  '#1',
  'number 1',
  'number one',
  'best',
  'top app',
  "world's best",
  'million downloads',
];

/// CTA / time-pressure claims flagged for Google Play only (Apple tolerates
/// these). Verbatim `CTA_CLAIMS` from copyLint.ts.
const List<String> ctaClaims = [
  'download now',
  'install now',
  'play now',
  'try now',
  'buy now',
  'sale',
  'discount',
  'limited time',
];

/// Verbatim `FORBIDDEN_CLAIMS` — the concatenation of both lists, exported
/// for reference/testing, mirroring the TS source.
const List<String> forbiddenClaims = [...rankingClaims, ...ctaClaims];

/// The result of linting a piece of marketing copy against store rules.
class LintResult {
  final bool ok;
  final List<String> issues;

  const LintResult({required this.ok, required this.issues});

  Map<String, dynamic> toJson() => {'ok': ok, 'issues': issues};
}

/// Match a claim only when it is not embedded in a larger alphanumeric word,
/// so "sale" does not flag "wholesale" and "best" does not flag "bestseller".
/// Ported verbatim from `containsClaim` in copyLint.ts — Dart's `RegExp`
/// supports the same lookbehind/lookahead ICU syntax as the TS regex.
bool _containsClaim(String lower, String claim) {
  final pattern = RegExp('(?<![a-z0-9])${RegExp.escape(claim)}(?![a-z0-9])');
  return pattern.hasMatch(lower);
}

/// Lints [text] against [store] ('app_store' | 'play_store'). Ranking/
/// superlative claims are flagged on both stores; CTA/time-pressure claims
/// are flagged only on 'play_store'. Matching is case-insensitive
/// (the input is lowercased first) and word-boundary-safe. Ported verbatim
/// from `lintCopy` in copyLint.ts.
LintResult lintCopy(String text, String store) {
  final lower = text.toLowerCase();
  final issues = <String>[];
  for (final claim in rankingClaims) {
    if (_containsClaim(lower, claim)) {
      issues.add('unsupported ranking/superlative claim: "$claim"');
    }
  }
  if (store == 'play_store') {
    for (final claim in ctaClaims) {
      if (_containsClaim(lower, claim)) {
        issues.add(
            'call-to-action/time-pressure not allowed on Google Play: "$claim"');
      }
    }
  }
  return LintResult(ok: issues.isEmpty, issues: issues);
}
