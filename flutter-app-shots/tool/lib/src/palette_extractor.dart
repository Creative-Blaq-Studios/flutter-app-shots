// Deterministic background-palette extraction from a captured screenshot.
// No RNG and no clock: identical pixels always yield an identical Palette,
// because this output feeds golden composition.
import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

import 'compose_specs.dart';

/// Neutral fallback when a screenshot has no opaque pixels to sample.
const Palette _neutral = Palette(
  bg: '#111827',
  bgAlt: '#1F2937',
  text: '#FFFFFF',
  subtext: '#CBD5E1',
  accent: '#6750A4',
  intensity: 'balanced',
);

/// Extracts a full [Palette] from the screenshot PNG at [pngPath].
Palette extractPaletteFromScreenshot(String pngPath) {
  final decoded = img.decodeImage(File(pngPath).readAsBytesSync());
  if (decoded == null) {
    throw FormatException('Could not decode image: $pngPath');
  }
  return paletteFromImage(decoded);
}

/// Core extraction over an already-decoded [image]. Kept separate so tests
/// can drive it with in-memory images.
Palette paletteFromImage(img.Image image) {
  // Sample a bounded grid for speed + stability.
  const maxSamples = 128;
  final stepX = math.max(1, (image.width / maxSamples).floor());
  final stepY = math.max(1, (image.height / maxSamples).floor());

  // 5-bit-per-channel histogram (32 levels/channel) with running RGB sums.
  final counts = <int, int>{};
  final sumR = <int, int>{};
  final sumG = <int, int>{};
  final sumB = <int, int>{};
  for (var y = 0; y < image.height; y += stepY) {
    for (var x = 0; x < image.width; x += stepX) {
      final p = image.getPixel(x, y);
      if (p.a.toInt() < 128) continue; // skip (near-)transparent pixels
      final r = p.r.toInt();
      final g = p.g.toInt();
      final b = p.b.toInt();
      final key = ((r >> 3) << 10) | ((g >> 3) << 5) | (b >> 3);
      counts[key] = (counts[key] ?? 0) + 1;
      sumR[key] = (sumR[key] ?? 0) + r;
      sumG[key] = (sumG[key] ?? 0) + g;
      sumB[key] = (sumB[key] ?? 0) + b;
    }
  }
  if (counts.isEmpty) return _neutral;

  final keys = counts.keys.toList()..sort(); // deterministic iteration order
  _Swatch avg(int key) {
    final c = counts[key]!;
    return _Swatch(
      (sumR[key]! / c).round(),
      (sumG[key]! / c).round(),
      (sumB[key]! / c).round(),
      c,
    );
  }

  // Dominant = most populous bucket (ties broken by smaller sorted key).
  var dominantKey = keys.first;
  for (final k in keys) {
    if (counts[k]! > counts[dominantKey]!) dominantKey = k;
  }
  // Vibrant maximizes saturation*count; muted minimizes saturation.
  int? vibrantKey;
  int? mutedKey;
  var bestVibrant = -1.0;
  var bestMuted = double.infinity;
  for (final k in keys) {
    final s = avg(k);
    final sat = _saturation(s.r, s.g, s.b);
    final vibrantScore = sat * s.count;
    if (vibrantScore > bestVibrant) {
      bestVibrant = vibrantScore;
      vibrantKey = k;
    }
    if (sat < bestMuted) {
      bestMuted = sat;
      mutedKey = k;
    }
  }

  final dominant = avg(dominantKey);
  final vibrant = avg(vibrantKey!);
  final muted = avg(mutedKey!);

  final bg = _asBackground(dominant);
  final accent = _hex(vibrant.r, vibrant.g, vibrant.b);
  final bgAlt = _distinctAlt(bg, muted);
  final text = _contrastText(bg);
  final subtext = _blendHex(text, bg, 0.35);

  return Palette(
    bg: bg,
    bgAlt: bgAlt,
    text: text,
    subtext: subtext,
    accent: accent,
    intensity: 'balanced',
  );
}

class _Swatch {
  final int r;
  final int g;
  final int b;
  final int count;
  const _Swatch(this.r, this.g, this.b, this.count);
}

double _saturation(int r, int g, int b) {
  final mx = math.max(r, math.max(g, b));
  final mn = math.min(r, math.min(g, b));
  if (mx == 0) return 0;
  return (mx - mn) / mx;
}

String _two(int v) => v.clamp(0, 255).toRadixString(16).padLeft(2, '0');

String _hex(int r, int g, int b) =>
    '#${_two(r)}${_two(g)}${_two(b)}'.toUpperCase();

List<int> _parseHex(String hex) {
  final h = hex.replaceFirst('#', '');
  return [
    int.parse(h.substring(0, 2), radix: 16),
    int.parse(h.substring(2, 4), radix: 16),
    int.parse(h.substring(4, 6), radix: 16),
  ];
}

double _channelLum(int c) {
  final s = c / 255.0;
  return s <= 0.03928
      ? s / 12.92
      : math.pow((s + 0.055) / 1.055, 2.4).toDouble();
}

double _relLum(int r, int g, int b) =>
    0.2126 * _channelLum(r) + 0.7152 * _channelLum(g) + 0.0722 * _channelLum(b);

double _contrast(double l1, double l2) {
  final hi = math.max(l1, l2);
  final lo = math.min(l1, l2);
  return (hi + 0.05) / (lo + 0.05);
}

/// White or near-black (`#111827`), whichever has higher contrast on [bgHex].
String _contrastText(String bgHex) {
  final bg = _parseHex(bgHex);
  final lum = _relLum(bg[0], bg[1], bg[2]);
  final white = _contrast(1.0, lum);
  final black = _contrast(_relLum(17, 24, 39), lum);
  return white >= black ? '#FFFFFF' : '#111827';
}

/// Linear RGB blend of [aHex] toward [bHex] by [t] in [0,1].
String _blendHex(String aHex, String bHex, double t) {
  final a = _parseHex(aHex);
  final b = _parseHex(bHex);
  int mix(int x, int y) => (x + (y - x) * t).round();
  return _hex(mix(a[0], b[0]), mix(a[1], b[1]), mix(a[2], b[2]));
}

/// Keeps hue/sat but clamps lightness away from pure black/white so a
/// gradient recipe (bg -> bgAlt) remains visible.
String _asBackground(_Swatch s) {
  final hsl = _toHsl(s.r, s.g, s.b);
  final l = hsl[2].clamp(0.08, 0.92);
  final rgb = _fromHsl(hsl[0], hsl[1], l);
  return _hex(rgb[0], rgb[1], rgb[2]);
}

/// Uses [muted] as the alt unless it is too close to [bgHex]; then shifts the
/// background lightness to derive a distinct second stop.
String _distinctAlt(String bgHex, _Swatch muted) {
  final mutedHex = _hex(muted.r, muted.g, muted.b);
  final bg = _parseHex(bgHex);
  final m = _parseHex(mutedHex);
  final dist =
      (bg[0] - m[0]).abs() + (bg[1] - m[1]).abs() + (bg[2] - m[2]).abs();
  if (dist >= 24) return mutedHex;
  final hsl = _toHsl(bg[0], bg[1], bg[2]);
  final l = (hsl[2] + (hsl[2] < 0.5 ? 0.12 : -0.12)).clamp(0.0, 1.0);
  final rgb = _fromHsl(hsl[0], hsl[1], l);
  return _hex(rgb[0], rgb[1], rgb[2]);
}

List<double> _toHsl(int r, int g, int b) {
  final rf = r / 255.0;
  final gf = g / 255.0;
  final bf = b / 255.0;
  final mx = math.max(rf, math.max(gf, bf));
  final mn = math.min(rf, math.min(gf, bf));
  final l = (mx + mn) / 2;
  if (mx == mn) return [0, 0, l];
  final d = mx - mn;
  final s = l > 0.5 ? d / (2 - mx - mn) : d / (mx + mn);
  double h;
  if (mx == rf) {
    h = (gf - bf) / d + (gf < bf ? 6 : 0);
  } else if (mx == gf) {
    h = (bf - rf) / d + 2;
  } else {
    h = (rf - gf) / d + 4;
  }
  return [h / 6, s, l];
}

List<int> _fromHsl(double h, double s, double l) {
  if (s == 0) {
    final v = (l * 255).round();
    return [v, v, v];
  }
  double f(double p, double q, double t) {
    if (t < 0) t += 1;
    if (t > 1) t -= 1;
    if (t < 1 / 6) return p + (q - p) * 6 * t;
    if (t < 1 / 2) return q;
    if (t < 2 / 3) return p + (q - p) * (2 / 3 - t) * 6;
    return p;
  }

  final q = l < 0.5 ? l * (1 + s) : l + s - l * s;
  final p = 2 * l - q;
  return [
    (f(p, q, h + 1 / 3) * 255).round(),
    (f(p, q, h) * 255).round(),
    (f(p, q, h - 1 / 3) * 255).round(),
  ];
}
