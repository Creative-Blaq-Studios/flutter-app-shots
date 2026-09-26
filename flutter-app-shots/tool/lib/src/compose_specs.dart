// flutter-app-shots/tool/lib/src/compose_specs.dart
//
// Composition specs originally ported from the retired TS compositor:
//   - compositor/src/palette.ts       (Tone -> Palette hex table)
//   - compositor/src/promptSpec.ts    (TONE_MOOD strings)
//   - compositor/src/deviceFrames.ts  (frameStyleFor geometry)
//   - compositor/src/templates.ts     (per-layout textOverlayFraction table)
//   - compositor/src/types.ts         (Tone, Layout, BackgroundSpec, RenderRequest shapes)
//
// Every hex, fraction,
// and string below is copied verbatim; do not "clean up" or recompute them.

/// Marketing tone — drives palette + background mood. Wire form is the
/// enum's own [name] (e.g. `Tone.premium.name == 'premium'`).
enum Tone { professional, playful, premium, bold, calm, minimal }

/// Composition layout. Wire strings ported verbatim from `Layout` in types.ts.
enum ComposeLayout {
  centeredDevice('centered_device'),
  tiltedDevice('tilted_device'),
  dualDevice('dual_device'),
  featureCallout('feature_callout'),
  textBanner('text_banner'),
  fullBleed('full_bleed');

  final String wire;
  const ComposeLayout(this.wire);
  static ComposeLayout fromWire(String w) =>
      ComposeLayout.values.firstWhere((e) => e.wire == w);
}

/// Tone -> color palette, ported verbatim from palette.ts's `BASE` table.
///
/// [intensity] ('safe' | 'balanced' | 'expressive') is carried through as
/// part of the public palette contract but — as in the TS source — is not
/// currently consumed by any layout/render logic; it's forward-looking
/// metadata only.
class Palette {
  final String bg;
  final String bgAlt;
  final String text;
  final String subtext;
  final String accent;
  final String intensity;

  const Palette({
    required this.bg,
    required this.bgAlt,
    required this.text,
    required this.subtext,
    required this.accent,
    required this.intensity,
  });

  Map<String, dynamic> toJson() => {
        'bg': bg,
        'bgAlt': bgAlt,
        'text': text,
        'subtext': subtext,
        'accent': accent,
        'intensity': intensity,
      };

  static Palette fromJson(Map json) => Palette(
        bg: json['bg'] as String,
        bgAlt: json['bgAlt'] as String,
        text: json['text'] as String,
        subtext: json['subtext'] as String,
        accent: json['accent'] as String,
        intensity: json['intensity'] as String,
      );
}

class _PaletteBase {
  final String bg, bgAlt, text, subtext, intensity;
  const _PaletteBase(
      this.bg, this.bgAlt, this.text, this.subtext, this.intensity);
}

// Verbatim from palette.ts's BASE table. Do not reformat/reorder the hexes —
// they are pinned exactly by compose_specs_test.dart.
const Map<Tone, _PaletteBase> _paletteBase = {
  Tone.professional:
      _PaletteBase('#0F172A', '#1E293B', '#FFFFFF', '#CBD5E1', 'balanced'),
  Tone.playful:
      _PaletteBase('#FFF7ED', '#FFEDD5', '#1F2937', '#4B5563', 'expressive'),
  Tone.premium:
      _PaletteBase('#0B0B0F', '#17171F', '#FFFFFF', '#A1A1AA', 'expressive'),
  Tone.bold:
      _PaletteBase('#111827', '#312E81', '#FFFFFF', '#E5E7EB', 'expressive'),
  Tone.calm: _PaletteBase('#F0FDFA', '#CCFBF1', '#134E4A', '#0F766E', 'safe'),
  Tone.minimal:
      _PaletteBase('#FFFFFF', '#F4F4F5', '#18181B', '#52525B', 'safe'),
};

/// Resolves the [Palette] for [tone], with [brandPrimaryColor] passed
/// straight through as `accent` — unprocessed, exactly like
/// `paletteFor(tone, brand)` in palette.ts (`accent: brand.primaryColor`).
Palette paletteFor(Tone tone, String brandPrimaryColor) {
  final base = _paletteBase[tone]!;
  return Palette(
    bg: base.bg,
    bgAlt: base.bgAlt,
    text: base.text,
    subtext: base.subtext,
    accent: brandPrimaryColor,
    intensity: base.intensity,
  );
}

/// Verbatim `TONE_MOOD` table from promptSpec.ts.
const Map<Tone, String> toneMood = {
  Tone.professional: 'clean, corporate, trustworthy, soft depth',
  Tone.playful: 'friendly, vibrant, rounded, energetic',
  Tone.premium: 'luxurious, dark, high-contrast, refined gradients',
  Tone.bold: 'high-energy, saturated, dynamic shapes',
  Tone.calm: 'soft, airy, pastel, soothing',
  Tone.minimal: 'spare, lots of negative space, subtle texture',
};

/// Device frame geometry, originally ported from deviceFrames.ts's
/// `FrameStyle`/`frameStyleFor` and then adjusted post-parity where the
/// Flutter renderer exposed visual issues in the retired HTML frame.
class FrameStyle {
  final bool isApple;
  final double cornerRadiusPct;
  final double bezelPx;
  final bool hasIsland;

  const FrameStyle({
    required this.isApple,
    required this.cornerRadiusPct,
    required this.bezelPx,
    required this.hasIsland,
  });
}

/// Based on `frameStyleFor` in deviceFrames.ts:
/// - `isApple` = deviceClass starts with `iphone` OR equals `ipad_13`.
/// - `isTablet` = `ipad_13` OR starts with `android_tablet`.
/// - `cornerRadiusPct`: 4% (tablets) / 12% (iPhones) / 5% (Android phones).
/// - `bezelPx`: 14px (tablets) / 12px (phones) — flat, not scaled.
/// - `hasIsland`: true only for deviceClass starting with `iphone`.
FrameStyle frameStyleFor(String deviceClass) {
  final isApple = deviceClass.startsWith('iphone') || deviceClass == 'ipad_13';
  final isTablet =
      deviceClass == 'ipad_13' || deviceClass.startsWith('android_tablet');
  final isAndroidPhone = deviceClass.startsWith('android_phone');
  return FrameStyle(
    isApple: isApple,
    cornerRadiusPct: isTablet ? 4 : (isAndroidPhone ? 5 : 12),
    bezelPx: isTablet ? 14 : 12,
    hasIsland: deviceClass.startsWith('iphone'),
  );
}

// Verbatim per-layout overlay fractions from templates.ts's switch statement.
// These are literal constants in the TS source (not derived by addition in
// the port either — 0.2 + 0.04 is not exactly 0.24 in binary floating
// point, so each (layout, hasSubheadline) pair is hardcoded here exactly as
// the TS source hardcodes it per case).
const Map<ComposeLayout, (double noSub, double withSub)> _overlayFractions = {
  ComposeLayout.centeredDevice: (0.2, 0.24),
  ComposeLayout.tiltedDevice: (0.2, 0.24),
  ComposeLayout.dualDevice: (0.2, 0.24),
  ComposeLayout.textBanner: (0.22, 0.26),
  ComposeLayout.featureCallout: (0.26, 0.30),
  ComposeLayout.fullBleed: (1.0, 1.0),
};

/// Hardcoded lookup-table estimate of how much of the canvas the text block
/// occupies for [layout], per templates.ts. `full_bleed` is always `1.0`
/// regardless of [hasSubheadline] (device is omitted; text is bled full).
double textOverlayFraction(ComposeLayout layout,
    {required bool hasSubheadline}) {
  final pair = _overlayFractions[layout]!;
  return hasSubheadline ? pair.$2 : pair.$1;
}

/// Background spec for a composition entry — `css` (a named style recipe)
/// or `image` (a generated/provided background PNG referenced by path).
/// Ported from `BackgroundSpec` (`CssBackground` | `ImageBackground`) in
/// types.ts.
class ComposeBackground {
  final String kind; // 'css' | 'image'
  final String?
      style; // css only: solid | gradient | brand_block | soft_shapes |
  //         mesh | spotlight | bold_diagonal | dots
  final String? path; // image only

  const ComposeBackground({required this.kind, this.style, this.path});

  Map<String, dynamic> toJson() => {
        'kind': kind,
        if (style != null) 'style': style,
        if (path != null) 'path': path,
      };

  static ComposeBackground fromJson(Map json) => ComposeBackground(
        kind: json['kind'] as String,
        style: json['style'] as String?,
        path: json['path'] as String?,
      );
}

/// A single composition request — the Dart-side analog of `RenderRequest`
/// in types.ts, minus the fields that only matter once actual pixels are
/// being painted (those live in `renderer/`).
///
/// [raw] (the source screenshot path) is nullable only when [deviceless] is
/// true (e.g. the Play Store feature graphic, which never composites a
/// device frame). [ComposeEntry.fromJson] enforces this invariant and
/// throws a [FormatException] if a non-deviceless entry has no `raw`.
class ComposeEntry {
  final String id;
  final String deviceClass;
  final String headline;
  final String out;
  final String? subheadline;
  final String? raw;
  final String? logo;
  final Tone tone;
  final ComposeLayout layout;
  final String? brandColor;
  final ComposeBackground background;
  final bool deviceless;
  final Palette palette;

  const ComposeEntry({
    required this.id,
    required this.deviceClass,
    required this.headline,
    required this.out,
    this.subheadline,
    this.raw,
    this.logo,
    required this.tone,
    required this.layout,
    this.brandColor,
    required this.background,
    required this.deviceless,
    required this.palette,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'deviceClass': deviceClass,
        'headline': headline,
        'out': out,
        if (subheadline != null) 'subheadline': subheadline,
        if (raw != null) 'raw': raw,
        if (logo != null) 'logo': logo,
        'tone': tone.name,
        'layout': layout.wire,
        if (brandColor != null) 'brandColor': brandColor,
        'background': background.toJson(),
        'deviceless': deviceless,
        'palette': palette.toJson(),
      };

  static ComposeEntry fromJson(Map json) {
    final id = json['id'] as String;
    final deviceless = (json['deviceless'] as bool?) ?? false;
    final raw = json['raw'] as String?;
    if (raw == null && !deviceless) {
      throw FormatException(
          'ComposeEntry.raw is required unless deviceless is true (id=$id)');
    }
    return ComposeEntry(
      id: id,
      deviceClass: json['deviceClass'] as String,
      headline: json['headline'] as String,
      out: json['out'] as String,
      subheadline: json['subheadline'] as String?,
      raw: raw,
      logo: json['logo'] as String?,
      tone: Tone.values.byName(json['tone'] as String),
      layout: ComposeLayout.fromWire(json['layout'] as String),
      brandColor: json['brandColor'] as String?,
      background:
          ComposeBackground.fromJson((json['background'] as Map?) ?? const {}),
      deviceless: deviceless,
      palette: Palette.fromJson(json['palette'] as Map),
    );
  }
}

/// A full composition manifest — an ordered list of [ComposeEntry].
class ComposeManifest {
  final List<ComposeEntry> entries;

  const ComposeManifest({required this.entries});

  Map<String, dynamic> toJson() =>
      {'entries': entries.map((e) => e.toJson()).toList()};

  static ComposeManifest fromJson(Map json) => ComposeManifest(
        entries: ((json['entries'] as List?) ?? const [])
            .map((e) => ComposeEntry.fromJson(e as Map))
            .toList(),
      );
}
