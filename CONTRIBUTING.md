# Contributing

Thanks for helping improve Flutter App Shots. The repository contains a Codex skill, a Dart CLI, a Flutter renderer, and a fixture app. Start with the [README](README.md), then read the [walkthrough](flutter-app-shots/WALKTHROUGH.md) for the artifact flow and current limitations.

## Set up

Use Flutter 3.27 or later and Dart 3.5 or later. Resolve the packages independently:

```bash
(cd flutter-app-shots/tool && dart pub get)
(cd flutter-app-shots/renderer && flutter pub get)
(cd flutter-app-shots/fixture_app && flutter pub get)
```

## Check a change

```bash
(cd flutter-app-shots/tool && dart analyze && dart test)
(cd flutter-app-shots/renderer && flutter analyze && flutter test --dart-define=APP_SHOTS_MANIFEST=.compose/ci-not-present.json)
(cd flutter-app-shots/fixture_app && flutter analyze)
```

Format Dart files you change with `dart format` before opening a pull request.

The renderer uses checked-in golden images. If a visual change is intentional, update goldens with `flutter test --update-goldens` in `flutter-app-shots/renderer`, inspect the image diffs, and run the ordinary test command again. The default `compose_test.dart` reads a local manifest when one exists; the test override above keeps package checks independent of that local file.

Add a monthly entry under `flutter-app-shots/docs/` for notable behavior or documentation changes, following the existing changelog format. Keep package imports absolute and keep app-specific capture logic in the target app's generated harnesses.

## Keep examples safe

Use synthetic data in fixtures and documentation. Do not commit credentials, local planning links, customer screenshots, private project paths, or generated output folders. The [security policy](SECURITY.md) explains how to report a vulnerability or exposed credential privately.

Pull requests should explain the behavior changed, how it was tested, and any effect on generated captures or store output. Do not include AI attribution trailers in commits or PR descriptions.
