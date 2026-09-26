# Asset and Annotation Rules

Read this before proposing asset sources or writing a golden harness.

Golden mode has no production network. Widgets backed by Firebase,
`StorageUrlCache`, `CachedNetworkImage`, `Image.network`, or unresolved
`Image.file` sources can render broken images or hang.

## Audit and confirmation

Inventory every image slot in each proposed shot: thumbnail, hero, grid cell,
avatar, logo, annotated image, and background. During the final intake, propose
and confirm one source for each slot:

- user-provided real file;
- existing app asset;
- generated domain-matched image;
- downloaded licensed stock; or
- static marketing wrapper replacing a network-backed production widget.

Prefer real user/app assets for product UI, the existing logo for branding, and
a locked real image plus aligned annotations for overlay shots. A generated or
stock asset must clearly show the intended subject. Never keep an unpinned stock
URL in the harness.

Do not acquire, copy, generate, download, or wire assets before the user
approves the Confirmed Generation Brief.

## Manifest contract

After approval, store local files under `<app>/app_shots/assets/`, add that
directory to `flutter.assets`, and declare every slot in
`app_shots/assets/manifest.json`:

```json
{
  "assets": [
    {
      "id": "vehicle_front_damage",
      "path": "app_shots/assets/vehicle_front_damage.jpg",
      "source": "provided | generated | stock | existing",
      "width": 900,
      "height": 1200,
      "usedBy": ["home.thumbnail", "results_visual.hero"]
    }
  ],
  "annotations": [
    {
      "assetId": "vehicle_front_damage",
      "coordinateSpace": "normalized_0_1000",
      "items": [
        {
          "id": "ann-001",
          "label": "Front bumper dent",
          "severity": 6,
          "confidence": 0.94,
          "box": {"xmin": 180, "ymin": 620, "xmax": 420, "ymax": 780}
        }
      ]
    }
  ]
}
```

Record the true dimensions of the local file. No harness code is allowed until
every `usedBy` slot has a real local file and manifest entry. Text-only shots
need no asset entry.

Harnesses load through `Image.asset(<manifest path>)` or a thin static marketing
wrapper. They must not contain ad-hoc production URLs or independent annotation
constants. `manifest.json` is the single source of truth; the current tool does
not yet validate it or generate `sample_data.dart`, so the agent wires it
manually.

Golden capture must also load fonts offline. When app widgets call
`GoogleFonts.*` directly, copy the exact family/weight files into
`<app>/google_fonts/` and declare `google_fonts/` in `flutter.assets`. Files under
`app_shots/golden/fonts/<Family>/` support the generated `FontLoader`, but they
are not visible to `google_fonts` package asset lookup.

## Annotation alignment

For boxes, polygons, or pins:

1. Lock one `assetId` and reuse that exact image everywhere the shot appears.
2. Record the app's coordinate space in the manifest.
3. Place each annotation on the described feature of that specific image, not
   on surrounding grass, sky, walls, or other background.
4. Re-open the raw capture and reject it when boxes miss the subject or labels
   are unreadable.

Do not invent annotations by copying coordinates from an unrelated image.
