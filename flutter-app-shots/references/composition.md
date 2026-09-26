# Composition Rules

Read this before drafting backgrounds or composition specs.

Every entry needs an approved headline and explicit background. The supported
background kinds are:

- `auto`: extracts a palette from the raw screenshot; no brand color required.
- `css`: deterministic tone/brand recipe; top-level `brandColor` required.
- `image`: local generated/provided background PNG; `brandColor` required for
  the text palette.

A deviceless Play feature graphic cannot use `auto`. Use `css` or `image`.

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
      "background": {"kind": "auto"}
    }
  ]
}
```

The CSS recipes are `solid`, `gradient`, `brand_block`, `soft_shapes`, `mesh`,
`spotlight`, `bold_diagonal`, and `dots`. Recommend a coherent but varied set:

| Tone | Suggested CSS | Image mood |
|---|---|---|
| professional | `gradient`, `spotlight` | clean, corporate, soft depth |
| playful | `dots`, `mesh` | friendly, vibrant, energetic |
| premium | `spotlight`, `gradient` | luxurious, dark, refined |
| bold | `bold_diagonal`, `mesh` | saturated and dynamic |
| calm | `soft_shapes`, `mesh` | soft, airy, pastel |
| minimal | `solid`, `dots` | spare, subtle texture |

For image backgrounds, run:

```bash
dart run app_shots bg-prompt \
  --device <deviceClass> \
  --tone <tone> \
  --brand-color <hex> \
  --variant <index>
```

Generate only the background at the emitted dimensions. Save it under the
target app's gitignored `app_shots/assets/bg/`. The image generator must never
draw app UI, device frames, store copy, or product claims. Change `--variant`
across the set.

Omit `layout` for the normal rotation `centered_device → tilted_device →
feature_callout → text_banner`. Use `full_bleed` only for deviceless feature
graphics and `dual_device` only for an intentional two-screen composition.

Before the full set, normalize and render a one-entry representative spec to a
temporary manifest. Show the image to the user and obtain approval for copy,
hierarchy, frame, background, and overall direction. Re-preview visible changes.
