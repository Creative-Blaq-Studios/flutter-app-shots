# Dart CLI reference

The CLI supplies repeatable mechanics for the Flutter App Shots skill. Run it from `flutter-app-shots/tool` after `dart pub get`:

```bash
dart run app_shots --help
dart run app_shots help <command>
```

It does not select screens, author app-specific mocks, generate background images, or approve visual quality. For the full order of operations, use the [walkthrough](../WALKTHROUGH.md) and the [skill instructions](../SKILL.md).

## Start with read-only checks

```bash
cd flutter-app-shots/tool
dart run app_shots doctor --app-dir ../fixture_app --image-gen false
dart run app_shots list-targets --store app_store
dart run app_shots preflight --mode golden --app-dir ../fixture_app
```

`doctor` reports capabilities in JSON and always exits successfully; inspect `readyForGolden`. `list-targets` returns the current device classes and exact sizes from this codebase. `preflight` returns a readiness verdict and exits with status 1 when requirements are missing. Golden mode does not boot a device. Live mode is iOS-oriented and can boot a simulator when `--boot` is explicitly passed.

## Commands by stage

| Command | Purpose | Side effect |
| --- | --- | --- |
| `doctor` | Check Flutter, resolved packages, and target pubspec | None |
| `list-targets` | Print supported store targets | None |
| `preflight` | Check golden or live capture readiness | May boot an iOS simulator with `--mode live --boot` |
| `audit` | List detected simulators and Android AVDs | None |
| `lint-copy` | Check store copy for flagged claims and calls to action | None |
| `bg-prompt` | Produce an image-background prompt specification | None; does not generate an image |
| `save-plan` | Validate a plan JSON and persist stores and shots | Updates the target app's `app_shots.yaml` |
| `golden-scaffold` | Generate the capture suite and missing per-shot harnesses | Writes into the target Flutter app |
| `validate` | Check a raw capture's dimensions and blank-image warning | None |
| `record` | Save capture metadata | Updates the capture log |
| `regen-check` | Identify shots needing recapture | None |
| `compose-manifest` | Check a composition spec and prepare renderer inputs | Writes a normalized manifest |
| `validate-output` | Check final store PNG dimensions, format, alpha, and overlay | None |
| `save-devices` | Persist detected device choices | Updates the target app's config |
| `normalize` | Set a clean status bar and disable animations | Changes simulator or emulator state |

Use `dart run app_shots help <command>` for the current options. Invalid command usage normally exits with status 64; validation and readiness failures exit with status 1.

## Capture and composition sequence

After an approved screen plan, the agent writes `app_shots/plan.json` in the target app and runs:

```bash
dart run app_shots save-plan \
  --config /path/to/flutter_app/app_shots/app_shots.yaml \
  --plan /path/to/flutter_app/app_shots/plan.json

dart run app_shots golden-scaffold \
  --config /path/to/flutter_app/app_shots/app_shots.yaml \
  --app-dir /path/to/flutter_app
```

The scaffold preserves an existing per-shot harness. A developer or agent must fill each new harness with the real screen widget, deterministic state, and local assets before running the target app's generated `app_shots/golden/capture_test.dart`. See the [golden capture walkthrough](../WALKTHROUGH.md#phase-5a-golden-capture).

After raw captures are reviewed, the agent writes `app_shots/compose-spec.json` and runs:

```bash
dart run app_shots compose-manifest \
  --spec /path/to/flutter_app/app_shots/compose-spec.json \
  --out-dir /path/to/flutter_app/app_shots/outputs
```

By default the manifest goes to `flutter-app-shots/renderer/.compose/manifest.json`. Render it from `flutter-app-shots/renderer` with `flutter test test/compose_test.dart`, then use `validate-output` on every final PNG. The [walkthrough](../WALKTHROUGH.md#phase-7-normalize-and-render) shows the composition spec shape, preview step, and output checks.

Generated screenshots, outputs, and the normalized manifest may contain app data. Keep them out of source control unless they are intentionally sanitized fixtures.
