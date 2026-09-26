// Marketing composition layouts, ported verbatim from `renderTemplate()` in
// compositor/src/templates.ts. Every fraction, font weight, rotation, and scale below is copied from
// that source — do not "clean up" or recompute them.
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

// ignore: implementation_imports
import 'package:app_shots/src/compose_specs.dart';

import 'backgrounds.dart';
import 'css_geometry.dart';
import 'device_frame.dart';

/// A full store-marketing image: a background layer (a generated image or one
/// of the CSS recipes) with headline/subheadline copy and a framed screenshot
/// arranged per the entry's [ComposeLayout], rendered at exactly [targetSize].
///
/// Requires an ancestor `MaterialApp` + `Material(type: transparency)` for
/// text — the compose harness / tests provide it, not this widget.
///
/// Geometry verbatim from `renderTemplate()` (`W`/`H` = target px):
/// - headline font-size `round(W*0.072)` (`round(W*0.09)` for full_bleed),
///   Sora w700, line-height 1.08, letter-spacing `-0.02em`, colour `text`
/// - subheadline font-size `0.42*headline`, Inter w400, line-height 1.3,
///   colour `subtext`, max-width 80% of the copy block, top gap `0.3*headline`
/// - copy block horizontal padding 8% of W
/// - device (framed screenshot) width `round(W*0.74)`
class MarketingCanvas extends StatelessWidget {
  const MarketingCanvas({
    super.key,
    required this.entry,
    required this.palette,
    required this.targetSize,
    this.backgroundImage,
    this.screenshot,
    this.logo,
    this.elevatedDevice = false,
    this.deviceWidthFraction = 0.74,
    this.centeredCopyFraction = 0.2,
  });

  final ComposeEntry entry;
  final Palette palette;
  final Size targetSize;
  final ImageProvider? backgroundImage;
  final ImageProvider? screenshot;
  final ImageProvider? logo;
  final bool elevatedDevice;
  final double deviceWidthFraction;
  final double centeredCopyFraction;

  double get _w => targetSize.width;
  double get _h => targetSize.height;

  ComposeLayout get _layout =>
      entry.deviceless ? ComposeLayout.fullBleed : entry.layout;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _w,
      height: _h,
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            _background(),
            _layoutBody(),
          ],
        ),
      ),
    );
  }

  Widget _background() {
    if (backgroundImage != null) {
      return Image(image: backgroundImage!, fit: BoxFit.cover);
    }
    return ComposeBackgroundWidget(
      style: entry.background.style ?? gradient,
      palette: palette,
    );
  }

  // ── copy block ────────────────────────────────────────────────────────────

  Widget _copy({required bool left, required double headlinePx}) {
    final align = left ? TextAlign.left : TextAlign.center;
    final cross = left ? CrossAxisAlignment.start : CrossAxisAlignment.center;
    final copyBlockWidth = _w * 0.84; // W minus 8% padding each side
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: _w * 0.08),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: cross,
        children: [
          Text(
            entry.headline,
            textAlign: align,
            style: TextStyle(
              fontFamily: 'Sora',
              fontWeight: FontWeight.w700,
              fontSize: headlinePx,
              height: 1.08,
              letterSpacing: -0.02 * headlinePx,
              color: colorFromHex(palette.text),
            ),
          ),
          if (entry.subheadline != null)
            Padding(
              padding: EdgeInsets.only(top: headlinePx * 0.3),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: copyBlockWidth * 0.8),
                child: Text(
                  entry.subheadline!,
                  textAlign: align,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w400,
                    fontSize: headlinePx * 0.42,
                    height: 1.3,
                    color: colorFromHex(palette.subtext),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── device ────────────────────────────────────────────────────────────────

  Widget _device() {
    if (screenshot == null) return const SizedBox.shrink();
    return DeviceFrame(
      screenshot: screenshot!,
      widthPx: (_w * deviceWidthFraction).roundToDouble(),
      deviceClass: entry.deviceClass,
      elevated: elevatedDevice,
      accentColor: colorFromHex(palette.accent),
    );
  }

  // ── layouts ───────────────────────────────────────────────────────────────

  Widget _layoutBody() {
    final headlinePx = (_w * 0.072).roundToDouble();
    switch (_layout) {
      case ComposeLayout.textBanner:
        return Column(
          children: [
            SizedBox(
              height: _h * 0.22,
              child: Center(child: _copy(left: false, headlinePx: headlinePx)),
            ),
            Expanded(
              child: Align(alignment: Alignment.topCenter, child: _device()),
            ),
          ],
        );

      case ComposeLayout.featureCallout:
        return Column(
          children: [
            SizedBox(
              height: _h * 0.26,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _copy(left: true, headlinePx: headlinePx),
              ),
            ),
            Expanded(child: Center(child: _device())),
          ],
        );

      case ComposeLayout.dualDevice:
        return Column(
          children: [
            SizedBox(
              height: _h * centeredCopyFraction,
              child: Center(child: _copy(left: false, headlinePx: headlinePx)),
            ),
            Expanded(
              // Two devices at 74% canvas width each overflow the canvas and
              // are clipped at the edges by MarketingCanvas's ClipRect — the
              // intended dual-device look (TS uses `overflow:hidden` here).
              // OverflowBox lets the Row lay out at its natural width, centred,
              // without a RenderFlex overflow indicator.
              child: OverflowBox(
                maxWidth: double.infinity,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Transform.translate(
                      offset: Offset(0, _h * 0.04),
                      child: Transform.scale(scale: 0.92, child: _device()),
                    ),
                    SizedBox(width: _w * 0.04),
                    Transform.translate(
                      offset: Offset(0, -_h * 0.02),
                      child: Transform.scale(scale: 0.92, child: _device()),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );

      case ComposeLayout.tiltedDevice:
        return Column(
          children: [
            SizedBox(
              height: _h * 0.2,
              child: Center(child: _copy(left: false, headlinePx: headlinePx)),
            ),
            Expanded(
              child: Center(
                child: Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, -0.0005) // perspective: 2000px
                    ..rotateY(-14 * math.pi / 180)
                    ..rotateX(4 * math.pi / 180)
                    ..rotateZ(-3 * math.pi / 180),
                  child: _device(),
                ),
              ),
            ),
          ],
        );

      case ComposeLayout.fullBleed:
        final fbHeadline = (_w * 0.09).roundToDouble();
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (logo != null)
                Padding(
                  padding: EdgeInsets.only(bottom: (_w * 0.03).roundToDouble()),
                  child:
                      Image(image: logo!, height: (_w * 0.06).roundToDouble()),
                ),
              _copy(left: false, headlinePx: fbHeadline),
            ],
          ),
        );

      case ComposeLayout.centeredDevice:
        return Column(
          children: [
            SizedBox(
              height: _h * 0.2,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: EdgeInsets.only(bottom: _h * 0.02),
                  child: _copy(left: false, headlinePx: headlinePx),
                ),
              ),
            ),
            Expanded(
              child: Align(alignment: Alignment.topCenter, child: _device()),
            ),
          ],
        );
    }
  }
}
