# Flutter App Shots

Create App Store and Google Play marketing screenshots from **real Flutter screens**. Flutter App Shots is a [Codex skill](flutter-app-shots/SKILL.md) that guides screen selection, capture, copy, composition, and visual review. A bundled Dart CLI handles repeatable checks and scaffolding; a Flutter renderer produces the final PNGs.

The skill is an assisted workflow, not a one-command screenshot generator. You choose the stores, device sizes, screens, copy, and assets before it changes your app or renders images. Generated imagery, when used, is limited to backgrounds behind the captured app UI.

## Quick start

You need Codex, Flutter **3.27+**, Dart **3.5+**, and a Flutter app to capture. Flutter includes a Dart SDK. Golden capture runs as Flutter widget tests; live capture additionally needs a supported device environment. See [installation](flutter-app-shots/INSTALLATION.md) for existing skill links, other machines, and troubleshooting.

```bash
git clone https://github.com/Creative-Blaq-Studios/flutter-app-shots.git fappshots
cd fappshots

mkdir -p "$HOME/.agents/skills"
ln -s "$PWD/flutter-app-shots" "$HOME/.agents/skills/flutter-app-shots"

(cd flutter-app-shots/tool && dart pub get)
(cd flutter-app-shots/renderer && flutter pub get)
```

The link command stops if a skill already exists at that path; check the [installation guide](flutter-app-shots/INSTALLATION.md#step-2-create-the-user-wide-codex-link) before changing an existing installation.

Verify the bundled packages against the sample app:

```bash
cd flutter-app-shots/tool
dart run app_shots doctor --app-dir ../fixture_app --image-gen false
```

Look for `"readyForGolden": true` in the JSON report. The `--image-gen false` setting uses deterministic painted backgrounds. For a real project, start Codex from the Flutter app's root and ask:

```text
$flutter-app-shots Create App Store and Google Play marketing screenshots for this app.
Start with golden capture, and show me the proposed screens, sizes, copy, and assets before generating anything.
```

Codex will inspect the app, propose an exact generation brief, and ask you to confirm it. It then captures the approved screens, shows representative raw and composed previews, and validates the final output set.

## What it produces

| Artifact | Purpose |
| --- | --- |
| Raw screenshots | The target app's real widgets at selected store sizes |
| Composition spec and manifest | Approved copy, layout, background, and file paths for each image |
| Final PNGs | Store-size images under the target app's `app_shots/outputs/` directory |
| Capture log | Records capture metadata for regeneration checks |

The renderer offers device frames, six layouts, and eight painted background recipes. It can also use an approved local background image. The [walkthrough](flutter-app-shots/WALKTHROUGH.md) explains capture modes, asset sourcing, outputs, and the exact validation steps.

## How the repository is organized

| Path | Contents |
| --- | --- |
| [`flutter-app-shots/SKILL.md`](flutter-app-shots/SKILL.md) | Agent workflow and quality gates |
| [`flutter-app-shots/tool/`](flutter-app-shots/tool/) | Pure Dart CLI for doctor, plans, capture scaffolding, manifests, and validation |
| [`flutter-app-shots/renderer/`](flutter-app-shots/renderer/) | Flutter composition engine and golden tests |
| [`flutter-app-shots/fixture_app/`](flutter-app-shots/fixture_app/) | Sample app and capture fixture |
| [`flutter-app-shots/references/`](flutter-app-shots/references/) | Intake, asset, and composition guidance for the skill |

The CLI is also usable manually. Run `dart run app_shots --help` from `flutter-app-shots/tool`, or see the [CLI reference](flutter-app-shots/docs/CLI.md). The CLI does not choose screens, create mock data, or visually approve screenshots by itself.

## Develop and test

```bash
cd flutter-app-shots/tool
dart pub get
dart analyze
dart test

cd ../renderer
flutter pub get
flutter analyze
flutter test --dart-define=APP_SHOTS_MANIFEST=.compose/ci-not-present.json

cd ../fixture_app
flutter pub get
flutter analyze
```

The renderer test override makes the normal test suite independent of any local compose manifest. To render a generated manifest, run `flutter test test/compose_test.dart` from `flutter-app-shots/renderer` without that override. See [contributing](CONTRIBUTING.md) before changing golden images or the capture workflow.

## Distribution

This repository distributes the **whole skill pack** from GitHub. Both bundled `pubspec.yaml` files use `publish_to: none`; a pub.dev release is not required to install the skill. The Dart CLI could be packaged separately later, but the renderer currently depends on the sibling CLI package by a local path.

## Documentation, security, and license

- [Installation and troubleshooting](flutter-app-shots/INSTALLATION.md)
- [End-to-end walkthrough and limitations](flutter-app-shots/WALKTHROUGH.md)
- [CLI reference](flutter-app-shots/docs/CLI.md)
- [Contributing](CONTRIBUTING.md)
- [Security policy](SECURITY.md)

Source code and documentation are [MIT licensed](LICENSE). Bundled fonts retain the licenses stored beside them: Inter and Sora use the SIL Open Font License; the fixture's Roboto font uses Apache 2.0.
