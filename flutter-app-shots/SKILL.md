---
name: flutter-app-shots
description: Use when a Flutter developer wants App Store / Play Store marketing screenshots generated from their app. Probes the environment, inspects the Flutter project, drafts marketing copy and tone, plans 3-5 shots, captures real app screenshots through golden-mode widget tests by default, then composes polished store images with the Flutter renderer and validates every output size.
---

# Flutter App Shots

Turn a Flutter app into store-ready marketing screenshots through one guided,
interactive workflow. You (the agent) do the reasoning: capability decisions,
screen selection, copy, tone, harness fills, mock data, visual inspection, and
background prompts. The bundled Dart/Flutter engine does deterministic capture,
composition, and validation.

- **Tool package** - `tool/` (Dart). Planning, validation, copy lint, prompt
  specs, capture logs, golden-scaffold, compose-manifest, doctor, and preflight.
  Run: `cd flutter-app-shots/tool && dart run app_shots <cmd>`.
- **Renderer package** - `renderer/` (Flutter). Paints CSS-style backgrounds,
  device frames, marketing layouts, feature graphics, and final exact-size PNGs.
  Run composition with `cd flutter-app-shots/renderer && flutter test test/compose_test.dart`.

## Compliance Invariant

Apple and Google screenshots must show the real app experience. The real app
screenshot, device frame, headline, and subheadline are always rendered
deterministically by Flutter. A model may generate only background image assets
behind the device. It must never draw the app UI, device frame, store text, or
feature claims.

## Interaction Contract (hard rule)

Read [`references/intake.md`](references/intake.md) completely before asking
questions. Every run is staged and user-confirmed:

- Read-only discovery (`doctor`, `list-targets`, and project inspection) may run
  before approval. Do not write app/harness files, boot devices, acquire or
  generate assets, capture, or compose yet.
- Use `request_user_input` when available; otherwise ask concise plain-text
  questions. Ask one to three related questions per round, offer an
  evidence-based recommendation, and wait for the answer.
- Reuse explicit choices the user already made; ask only for missing or
  ambiguous decisions. Never treat a broad request, inferred default, or silence
  as approval.
- Before mutation or generation, present the complete **Confirmed Generation
  Brief** from the intake reference and ask, **“Proceed with this exact brief?”**
- Reconfirm any later change that affects stores, exact device classes, screens,
  copy, backgrounds, assets, capture mode, or app-code patches.

## Setup

Run once per machine or after dependency changes:

```bash
cd flutter-app-shots/tool && dart pub get
cd ../renderer && flutter pub get
```

## Step 0 - Doctor

Probe the pure Dart/Flutter path:

```bash
cd flutter-app-shots/tool
dart run app_shots doctor --app-dir <flutter-app-root> --image-gen true
```

Use `--image-gen false` when no image generation tool is available. Read the
JSON before planning:

- `readyForGolden: true` means the default golden path can proceed.
- `notes[]` lists missing setup such as Flutter, unresolved tool packages,
  unresolved renderer packages, or a missing target app `pubspec.yaml`.
- `imageGeneration: true` means generated background PNGs are the **expressive
  default** for hero/expressive shots (confirm in the Step 4 brief). The
  model paints only the background *behind* the device — never UI, frame, or
  text.
- `imageGeneration: false` means use the CSS background recipes instead.

List the exact targets supported by the installed tool before offering choices:

```bash
dart run app_shots list-targets
```

## Step 0.25 - Initial Intent Gate

Use intake Rounds 1-3 to confirm destination stores and exact capture targets.
Ask Apple and Google branches only when relevant. Include iPad and Android
tablet choices; ask for each supported iPhone/tablet size rather than silently
expanding a broad platform label. Ask whether a Play Store feature graphic is
wanted when Play Store is in scope.

Do not write the plan yet. Record the answers for the final brief in Step 4.

## Step 0.5 - Choose Mode

Golden mode is the recommended starting point unless a screen depends on a
platform view or native plugin surface that cannot be represented in a widget
test. Probe golden capability without changing the app:

```bash
cd flutter-app-shots/tool
dart run app_shots preflight --mode golden --app-dir <flutter-app-root>
```

After project inspection, propose golden, live, or mixed capture per shot and
include that choice in the Step 4 brief. Only after approval may live preflight
boot a device:

```bash
cd flutter-app-shots/tool
dart run app_shots preflight --mode live --app-dir <flutter-app-root> --boot
```

Never select or boot live mode without confirmation.

## Step 1 - Inspect The Project

Read the target app's `pubspec.yaml`, routes, theme/primary color, logo assets,
localization, screen widgets, and any existing `app_shots.yaml`. Infer the core
value proposition and pick screens that show real product value. Visible app text
such as headings, page titles, empty states, and navigation labels is the best
signal for screen selection.

Also scan for native/plugin surfaces that may be blank under `flutter test`
(maps, webviews, camera previews, video players). Mark those shots as live-mode
candidates before promising the golden path.

## Step 1.5 - Asset & Annotation Audit (mandatory)

Read [`references/assets.md`](references/assets.md) completely. During read-only
inspection, inventory every image slot and any annotation needs. In the Step 4
brief, recommend and confirm a source for every slot. Do not acquire or write
assets before that brief is approved.

After approval, every slot must have a real local file, true dimensions, and an
`app_shots/assets/manifest.json` entry before harness code. Add the asset
directory to `flutter.assets`. Harnesses load manifest-backed `Image.asset`
files or a confirmed static wrapper—never production network/storage paths.
Annotations must be authored against the exact locked image and visually
verified on the raw capture.

## Step 2 - Copy And Tone

Propose a tone:

`professional | playful | premium | bold | calm | minimal`

Draft short benefit-focused copy for 3-5 shots. Lint each headline and
subheadline for the destination store:

```bash
cd flutter-app-shots/tool
dart run app_shots lint-copy --store app_store --text "<headline>"
dart run app_shots lint-copy --store play_store --text "<headline>"
```

Fix ranking claims, unsupported superlatives, and Play Store CTAs before
composition.

## Step 3 - Screenshot Plan

Plan 3-5 shots. For each shot capture:

- `id`
- screen description
- real screen widget or route
- required state and mock/seed notes
- required image/test asset slots: thumbnail, hero, grid cell, avatar, logo, or
  annotated image; include the expected subject and whether alignment data is
  needed
- proposed source for each asset slot: user-provided file, generated image,
  licensed stock/download, existing app asset, or marketing wrapper with no
  network-backed real widget
- exact `deviceClasses` to capture, copied from `list-targets`
- status bar style
- headline and optional subheadline
- composition layout — **vary these across the set**. Leave `layout` unset in
  the compose spec to get the automatic rotation (`centered_device` →
  `tilted_device` → `feature_callout` → `text_banner`, keyed by shot); set it
  explicitly only when a specific screen needs a specific frame. Reserve
  `full_bleed` for the feature graphic and `dual_device` for genuine
  two-screen shots.
- background intent — pick per the tone table in Step 6 and **vary the style
  across shots**; prefer a generated `image` background when image generation
  is available.

Draft the capture portion as plan JSON, but do not persist it until the Step 4
brief is approved. It MUST include a top-level `stores` array (`app_store`
and/or `play_store`) and exact `deviceClasses` per shot:

```json
{
  "stores": ["app_store"],
  "shots": [
    {
      "id": "home",
      "description": "Curated notes list",
      "route": "/home",
      "requiredState": {"auth": false, "seeded": true},
      "selectors": [],
      "deviceClasses": ["iphone_6_9", "ipad_13"]
    }
  ]
}
```

`formFactors` is a backward-compatible fallback that expands to every target in
that group (`iphone` means both supported iPhone sizes; `androidTablet` means
both supported tablet sizes). New plans MUST use `deviceClasses` so capture
matches the user's exact choices.

After Step 4 approval, persist the plan:

```bash
cd flutter-app-shots/tool
dart run app_shots save-plan --config <flutter-app-root>/app_shots.yaml --plan <plan.json>
```

## Step 4 - Confirmed Generation Brief (mandatory)

Run intake Rounds 4-5. Propose and confirm:

- stores, exact device classes and pixel sizes, plus Play feature graphic;
- ordered screens, required states, copy, tone, and background kind per shot;
- golden/live capture mode per shot and the representative preview target;
- every image slot's source, local path or acquisition brief, dimensions, and
  annotation needs; and
- every proposed app, `pubspec`, harness, and generated-file change.

For backgrounds, recommend a concrete direction per shot—`image`, `auto`, or
`css:<style>`—and explain why it fits. Do not ask an unassisted open-ended
question or silently choose a default. Keep credentials out of config, source,
flows, and logs; use environment variables or test-only mocks.

Present the exact brief using the template in `references/intake.md`, then ask:

> **Proceed with this exact brief?**

Only an explicit yes permits `save-plan`, asset acquisition/generation, app or
harness writes, device boot, capture, and composition. If the answer changes any
choice, revise affected downstream details and reconfirm.

## Step 4.5 - Post-scaffold Harness Gate (mandatory)

After scaffolding in Step 5 and before running the full capture matrix, from the
target app root:

1. Static analysis (scoped to the generated harness, not the whole app):

   ```bash
   cd <flutter-app-root>
   flutter analyze app_shots/golden/
   ```

   Must be clean (or only documented ignores).

2. Compile and capture the approved representative raw shot to fail fast:

   ```bash
   flutter test app_shots/golden/capture_test.dart --plain-name "capture <first-shot-id> @ <first-device-class>"
   ```

3. Inspect that raw PNG and show it to the user. Ask approval of screen state,
   content, annotations, and responsive layout. Do not capture the rest until the
   representative raw shot is explicitly approved.

4. After approval, capture ONE shot at a time:

   ```bash
   flutter test app_shots/golden/capture_test.dart --plain-name "capture <shot-id>" --fail-fast --timeout 30s
   ```

Rules:

- **Stop the workflow** on any analyze/compile failure or capture timeout — do
  not proceed to compose.
- **Retry a failed shot at most once** after a harness fix. If it fails or hangs
  twice, fall back to a static marketing harness or live mode for THAT shot only.
- If a capture command runs beyond ~2 minutes with no new output, kill it and
  diagnose that shot.
- Never run the remaining N×M matrix until the representative raw preview is
  approved and each shot passes individually.

Use `--plain-name` (literal) rather than `--name` (regex) so shot ids with
special characters match correctly.

## Step 5 - Capture Real Screenshots

### Golden Mode

Scaffold the capture harness:

```bash
cd flutter-app-shots/tool
dart run app_shots golden-scaffold --config <flutter-app-root>/app_shots.yaml --app-dir <flutter-app-root>
```

Follow the offline font rules in `references/assets.md`. Direct
`GoogleFonts.*` calls need their exact font files under
`<flutter-app-root>/google_fonts/`, declared in `flutter.assets`.

Then fill each generated harness under
`<flutter-app-root>/app_shots/golden/harness/` with the real screen widget,
real theme, fixed test data, and mocks for network/plugin dependencies. Harness
files are write-once; rerunning scaffold refreshes the suite files without
overwriting filled harnesses.

Harness assets and annotation data MUST come from `manifest.json`. Use local
`Image.asset` or a confirmed static wrapper, never unresolved network/storage
providers. Do not reuse unrelated photos or annotation constants. The manifest
wins whenever sample data is regenerated.

Capture one shot at a time (see Step 4.5) — never the whole file at once:

```bash
cd <flutter-app-root>
flutter test app_shots/golden/capture_test.dart --plain-name "capture <shot-id>" --fail-fast --timeout 30s
```

Stop on the first failing or timed-out shot; fix its harness and retry that shot
once before falling back to a static harness or live mode for it.

Mandatory visual-acceptance gate — inspect every raw PNG under
`app_shots/screenshots/golden/<shot>/<device>.png` **before composing**. Reject
and fix the harness/assets if any of these fail:

- [ ] Thumbnails/heroes show the real photo — not a broken-image box or spinner.
- [ ] Annotation boxes sit on the subject (car/metal/glass), not on background.
- [ ] Text and labels are readable — fonts loaded, no tofu/blocky glyphs.
- [ ] Status bar present, layout not cropped, no platform-view holes.
- [ ] No unintended empty states or loading spinners.

Do not proceed to compose (Step 6) until every raw PNG passes this checklist.

Validate each raw capture against its native target:

```bash
cd flutter-app-shots/tool
dart run app_shots validate --file <png> --target <WIDTHxHEIGHT>
```

Record accepted captures:

```bash
dart run app_shots record --log <flutter-app-root>/app_shots/capture-log.json \
  --id <id> --file <png> --platform <ios|android> \
  --form-factor <iphone|ipad|androidPhone|androidTablet> --device golden \
  --width <px> --height <px> --provider synthetic_golden --synthetic \
  --tier T1 --status passed --signature <signature> --hash <appBuildHash>
```

### Live Mode

Use live mode only for shots that golden mode cannot represent. After
`preflight --mode live`, drive the running app with Maestro MCP when available
or Maestro CLI as fallback. Save real device screenshots to
`app_shots/screenshots/raw/`, validate them with `validate`, and record them
with provider `maestro_native` or `manual_upload`.

## Step 6 - Compose Store Images

Read [`references/composition.md`](references/composition.md) completely, then
create the approved composition spec, usually at
`<flutter-app-root>/app_shots/compose-spec.json`:

```json
{
  "stores": ["app_store"],
  "tone": "professional",
  "brandColor": "#6750A4",
  "entries": [
    {
      "id": "home",
      "deviceClass": "iphone_6_9",
      "raw": "screenshots/golden/home/iphone_6_9.png",
      "headline": "All your notes, one place",
      "subheadline": "Fast capture. Zero friction.",
      "background": { "kind": "auto" }
    }
  ]
}
```

Every entry MUST declare its approved `background`; there is no default.
`auto` derives a screenshot palette, `css` uses a deterministic recipe, and
`image` uses a local generated/provided PNG. `css` and `image` require
`brandColor`; a deviceless feature graphic cannot use `auto`.

For an approved generated background, obtain its exact prompt spec:

```bash
cd flutter-app-shots/tool
dart run app_shots bg-prompt --device <deviceClass> --tone <tone> --brand-color <hex>
```

Generate only the background at the prompt dimensions, save it under the app's
gitignored `app_shots/assets/bg/`, and reference it as:

```json
{ "kind": "image", "path": "assets/bg/home_iphone_6_9.png" }
```

Before rendering the full set, create a temporary composition spec containing
only the approved representative entry. Normalize it to a temporary manifest,
render it with `APP_SHOTS_MANIFEST`, inspect the output, and show it to the user.
Ask for approval of the copy, hierarchy, frame, background, and overall visual
direction. Do not render the remaining entries until that representative
composition is explicitly approved. Apply requested visual changes, show the
revised preview, and obtain approval again.

Normalize the manifest:

```bash
cd flutter-app-shots/tool
dart run app_shots compose-manifest --spec <flutter-app-root>/app_shots/compose-spec.json --out-dir <flutter-app-root>/app_shots/outputs
```

Render final PNGs:

```bash
cd flutter-app-shots/renderer
flutter test test/compose_test.dart
```

The renderer reads `renderer/.compose/manifest.json` by default. To use a custom
manifest path:

```bash
flutter test --dart-define=APP_SHOTS_MANIFEST=<manifest.json> test/compose_test.dart
```

## Step 7 - Validate Outputs

Validate every composed PNG:

```bash
cd flutter-app-shots/tool
dart run app_shots validate-output --file <png> --device <deviceClass> --overlay <textOverlayFraction>
```

For `feature_graphic`, omit `--overlay`.

Failures are gates. Fix dimensions, alpha, blank-image warnings, or overlay
violations before delivery. Google's first screenshots should stay UI-dominant;
if overlay exceeds the Play cap, shorten copy or choose a more conservative
layout.

## Step 8 - Export The Full Set

Produce the agreed App Store and Play Store targets into:

```text
<flutter-app-root>/app_shots/outputs/app_store/<deviceClass>/<id>.png
<flutter-app-root>/app_shots/outputs/play_store/<deviceClass>/<id>.png
```

Include a Play Store feature graphic at:

```text
<flutter-app-root>/app_shots/outputs/play_store/feature_graphic/<id>.png
```

Summarize every output file, validation result, and any remaining caveat.

## Step 9 - Regenerate After App Changes

Compute the app build hash, then:

```bash
cd flutter-app-shots/tool
dart run app_shots regen-check --config <flutter-app-root>/app_shots.yaml --log <flutter-app-root>/app_shots/capture-log.json --hash <hash>
```

Re-capture only the listed shot ids, then recompose and validate those outputs.

## Guardrails

- Real app screenshot + frame + text are never model-generated.
- Confirm the complete generation brief before any mutation or generation; no
  approval by silence. Use exact `deviceClasses` for new plans and never broaden
  “iPhone,” “iPad,” “Android,” or “tablet” without asking.
- Confirm scope, copy, backgrounds, assets, capture mode, and any app-code patch
  with the user. Obtain separate approval for one representative raw capture and
  one representative final composition before producing the rest.
- Do not store credentials in config, source, flows, screenshots, or logs.
- Do not claim a screenshot is ready until raw capture and final composition have
  both been visually inspected.
- Curate assets and author image-aligned annotations (Step 1.5) before
  writing harness code; the harness renders the manifest, never a network/storage
  path. No compose until raw captures pass the visual-acceptance checklist (real
  thumbnails, boxes on the subject, fonts loaded).
- Do not upscale. Capture at native target dimensions and compose at exact store
  output dimensions.
- If a tool is missing, report the specific gap and move to the next viable path
  rather than fabricating UI.
