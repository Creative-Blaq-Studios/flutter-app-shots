# Mandatory Intake and Confirmation

Use this guide for every Flutter App Shots run. It defines the questions that
must be answered before the workflow writes app or harness code, acquires
assets, captures screens, generates backgrounds, or composes final images.

## Contents

- [Interaction contract](#interaction-contract)
- [Live target catalogue](#live-target-catalogue)
- [Question rounds](#question-rounds)
- [Recommendations](#recommendations)
- [Confirmed generation brief](#confirmed-generation-brief)
- [Preview approvals](#preview-approvals)
- [Change control](#change-control)

## Interaction contract

1. Run only read-only discovery first: `doctor`, `list-targets`, and project
   inspection. Do not boot a device or write/download/generate anything yet.
2. Reuse decisions the user already supplied. Summarize them and ask only for
   missing or ambiguous decisions.
3. Ask in short rounds of one to three related questions. When
   `request_user_input` is available, use it. Otherwise ask concise plain-text
   questions and wait for answers.
4. Lead with a recommendation based on the app and explain its tradeoff in one
   sentence. A recommendation is not consent.
5. Do not treat silence, an earlier broad request such as “make screenshots,”
   or an inferred default as approval.
6. Before mutation or generation, present the full Confirmed Generation Brief
   and ask: **“Proceed with this exact brief?”** Continue only after an explicit
   yes or a user-authored correction.

`request_user_input` choices are mutually exclusive. For combinations, offer
clear bundles such as “iPhone + iPad,” then use a follow-up round for exact
sizes. If the available tool cannot express a needed multi-select, ask a short
plain-text question instead.

## Live target catalogue

Run this before offering target choices:

```bash
cd flutter-app-shots/tool
dart run app_shots list-targets
```

The command is the implementation source of truth. At the time this guide was
written, the capture choices are:

| Store | Surface | Exact `deviceClass` | Output |
|---|---|---|---|
| App Store | iPhone 6.9-inch | `iphone_6_9` | 1320×2868 portrait |
| App Store | iPhone 6.5-inch | `iphone_6_5` | 1284×2778 portrait |
| App Store | iPad 13-inch | `ipad_13` | 2064×2752 portrait |
| Play Store | Android phone | `android_phone` | 1080×1920 portrait |
| Play Store | Android 7-inch tablet | `android_tablet_7` | 1440×2560 portrait |
| Play Store | Android 10-inch tablet | `android_tablet_10` | 2560×1440 landscape |

`feature_graphic` is a Play Store composition target (1024×500), not a capture
target. Ask whether it is wanted, but never put it in a shot's
`deviceClasses`.

Store rules change. Do not describe this table as the latest official store
requirement unless those requirements have been separately verified. It is the
set supported by the installed tool.

## Question rounds

### Round 1 — destination

Ask which storefronts are in scope:

- App Store and Play Store
- App Store only
- Play Store only

Then branch. Never ask Android questions for an App-Store-only run or Apple
questions for a Play-Store-only run.

### Round 2 — Apple coverage

If App Store is selected, ask:

1. iPhone + iPad, iPhone only, or iPad only?
2. If iPhone is included: 6.9-inch + 6.5-inch, 6.9-inch only, or 6.5-inch only?
3. Confirm `ipad_13` when iPad is included.

Record exact `deviceClasses`; do not record only `iphone`, because that legacy
form factor silently expands to both supported iPhone sizes.

### Round 3 — Google Play coverage

If Play Store is selected, ask:

1. Android phone + tablet, phone only, or tablet only?
2. If tablet is included: 7-inch + 10-inch, 7-inch only, or 10-inch only?
3. Include or omit the Play Store feature graphic?

Record `android_phone`, `android_tablet_7`, and/or
`android_tablet_10` exactly as approved.

### Round 4 — story and creative direction

After inspecting the app, propose three to five high-value screens and ask the
user to approve or revise:

- screen order and required state;
- benefit-focused headline and optional subheadline for each screen;
- tone: `professional`, `playful`, `premium`, `bold`, `calm`, or `minimal`;
- background approach: generated image, screenshot-derived `auto`, CSS recipe,
  or a deliberate mixture across the set;
- any must-use brand color, logo, campaign line, or visual reference.

Do not ask “What backgrounds do you want?” without help. Offer a concrete
direction per shot, explain why it fits the app, and let the user accept or
change it.

### Round 5 — production choices

After the screen and asset audit, ask the remaining implementation questions:

- capture mode per shot: golden, live, or mixed;
- source for every image slot: user-provided, existing app asset, generated,
  licensed download, or static marketing wrapper;
- whether the proposed app/harness changes are acceptable;
- which representative raw shot and composed shot should be used for previews.

If user-provided assets are required, stop before harness work until the files
are available or the user chooses another source.

## Recommendations

Recommendations must reflect evidence found in the app:

- Start with phone surfaces when the product is phone-first. Add iPad/tablet
  only when the UI genuinely adapts; a stretched phone layout is poor marketing.
- Recommend both supported sizes for a selected surface when the user wants
  broad coverage and the extra capture/render time is acceptable.
- Recommend a mixed background set for most campaigns: expressive hero,
  quieter product-detail shots, and consistent brand color. Prefer deterministic
  `auto`/CSS when image generation is unavailable or strict repeatability matters.
- Recommend golden capture for deterministic Flutter widgets. Recommend live
  only for platform views or native/plugin surfaces that golden tests cannot
  represent.
- Explain additional cost plainly: more device classes multiply captures and
  outputs; tablets often need distinct layout fixes and a 10-inch landscape
  composition.

## Confirmed generation brief

Present a compact brief before any mutation or generation:

```text
Confirmed generation brief
- Stores: <app_store / play_store>
- Exact capture targets: <deviceClasses with pixel sizes>
- Play feature graphic: <include / omit / not applicable>
- Shots: <ordered ids, screens, and required states>
- Copy: <headline and subheadline per shot>
- Tone and backgrounds: <tone plus kind/style/path intent per shot>
- Capture mode: <golden/live per shot>
- Assets: <slot → confirmed source and local path/brief>
- Changes: <app, pubspec, harness, and generated-file changes>
- Preview gates: <representative raw target and representative composition>
```

End with **“Proceed with this exact brief?”** Do not continue until the user
explicitly approves it.

After approval, save plans with exact device classes:

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

`formFactors` remains supported for older plans, but it expands to every device
class in that form factor. New plans must prefer `deviceClasses` so the saved
matrix exactly matches the user's selection.

## Preview approvals

Approval of the generation brief does not approve unseen visuals:

1. Capture and inspect the chosen representative raw screenshot. Show it to the
   user and ask whether the screen state, content, and responsive layout are
   approved before capturing the remaining matrix.
2. Compose one representative final image. Show it and ask whether the copy,
   hierarchy, frame, background, and overall direction are approved before
   rendering the remaining set.
3. Analysis, tests, size validation, and fixes that preserve the approved brief
   do not need separate permission. Any visible creative change does.

## Change control

If the user changes a store, device class, screen, copy direction, background,
asset source, capture mode, or code-patch boundary:

1. update the draft plan and affected downstream choices;
2. show the revised brief or the revised affected section;
3. obtain explicit approval again before continuing affected work.

Never quietly broaden a target such as “iPhone” into multiple sizes or
“Android” into phone plus tablets.
