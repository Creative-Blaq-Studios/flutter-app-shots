// Device bezel/frame, originally ported from `deviceFrameHtml()` in
// compositor/src/deviceFrames.ts, with Flutter renderer adjustments for Android phone corner
// radius and non-Apple shadow balance.
import 'package:flutter/widgets.dart';

// `tool/` has no public barrel (see B1); `FrameStyle`/`frameStyleFor` are
// consumed straight from their `lib/src` location per the interface contract.
// ignore: implementation_imports
import 'package:app_shots/src/compose_specs.dart';

/// A screenshot wrapped in a device bezel with rounded corners, a two-layer
/// drop shadow, and (for iPhone device classes) a Dynamic Island pill.
///
/// Geometry follows the retired `deviceFrameHtml()` contract, except Android
/// phone radius and non-Apple shadows are adjusted for the Flutter renderer:
/// - inner (screenshot) radius = `widthPx * cornerRadiusPct / 100`
/// - bezel = flat `bezelPx` padding on all sides, colour `#0A0A0A`
/// - outer radius = inner radius + bezel width (concentric ring)
/// - Apple shadow = soft ambient shadow; no heavy bottom slab
/// - non-Apple shadow = symmetric blur so the bottom does not read as a
///   thicker bezel
/// - island (iPhones only) = pill `width 30% × height 7.5%` of `widthPx`,
///   `#000`, fully rounded, centred, `top = widthPx*0.03` from the padding
///   box (i.e. `widthPx*0.03 - bezelPx` relative to the screenshot content box)
class DeviceFrame extends StatelessWidget {
  const DeviceFrame({
    super.key,
    required this.screenshot,
    required this.widthPx,
    required this.deviceClass,
    this.elevated = false,
    this.accentColor = const Color(0xFF72D9A1),
  });

  final ImageProvider screenshot;
  final double widthPx;
  final String deviceClass;
  final bool elevated;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final s = frameStyleFor(deviceClass);
    final innerRadius = widthPx * s.cornerRadiusPct / 100;
    final contentWidth = widthPx - 2 * s.bezelPx;

    return Container(
      width: widthPx,
      padding: EdgeInsets.all(s.bezelPx),
      decoration: BoxDecoration(
        color: elevated ? null : const Color(0xFF0A0A0A),
        gradient: elevated
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF3A403D),
                  Color(0xFF111412),
                  Color(0xFF272D2A),
                ],
                stops: [0, 0.46, 1],
              )
            : null,
        border: elevated
            ? Border.all(
                color: accentColor.withAlpha(0x3D),
                width: widthPx * 0.0024,
              )
            : null,
        borderRadius: BorderRadius.circular(innerRadius + s.bezelPx),
        boxShadow: elevated
            ? _elevatedShadows(accentColor, widthPx)
            : (s.isApple ? _appleShadows : _balancedShadows),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(innerRadius),
            child: Image(
              image: screenshot,
              width: contentWidth,
              fit: BoxFit.fitWidth,
            ),
          ),
          if (s.hasIsland)
            Positioned(
              top: widthPx * 0.03 - s.bezelPx,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: widthPx * 0.3,
                  height: widthPx * 0.075,
                  decoration: BoxDecoration(
                    color: const Color(0xFF000000),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

List<BoxShadow> _elevatedShadows(Color accent, double widthPx) => [
      BoxShadow(
        color: accent.withAlpha(0x1C),
        offset: Offset.zero,
        blurRadius: widthPx * 0.14,
        spreadRadius: widthPx * 0.008,
      ),
      BoxShadow(
        color: const Color(0x4D000000),
        offset: Offset.zero,
        blurRadius: widthPx * 0.085,
        spreadRadius: widthPx * 0.002,
      ),
      BoxShadow(
        color: const Color(0x1AFFFFFF),
        offset: const Offset(-2, -2),
        blurRadius: widthPx * 0.012,
      ),
    ];

const _appleShadows = [
  BoxShadow(
    color: Color(0x2E000000), // rgba(0,0,0,0.18)
    offset: Offset(0, 6),
    blurRadius: 56,
  ),
  BoxShadow(
    color: Color(0x14000000), // rgba(0,0,0,0.08)
    offset: Offset.zero,
    blurRadius: 18,
  ),
];

const _balancedShadows = [
  BoxShadow(
    color: Color(0x59000000),
    offset: Offset.zero,
    blurRadius: 72,
    spreadRadius: 4,
  ),
  BoxShadow(
    color: Color(0x33000000),
    offset: Offset.zero,
    blurRadius: 24,
  ),
];
