// flutter-app-shots/tool/test/compose_specs_test.dart
import 'package:app_shots/src/compose_specs.dart';
import 'package:test/test.dart';

void main() {
  group('Palette', () {
    test('carries the verbatim tone hex table from palette.ts', () {
      final professional = paletteFor(Tone.professional, '#FF0000');
      expect(professional.bg, '#0F172A');
      expect(professional.bgAlt, '#1E293B');
      expect(professional.text, '#FFFFFF');
      expect(professional.subtext, '#CBD5E1');
      expect(professional.intensity, 'balanced');

      final playful = paletteFor(Tone.playful, '#FF0000');
      expect(playful.bg, '#FFF7ED');
      expect(playful.bgAlt, '#FFEDD5');
      expect(playful.text, '#1F2937');
      expect(playful.subtext, '#4B5563');
      expect(playful.intensity, 'expressive');

      final premium = paletteFor(Tone.premium, '#FF0000');
      expect(premium.bg, '#0B0B0F');
      expect(premium.bgAlt, '#17171F');
      expect(premium.text, '#FFFFFF');
      expect(premium.subtext, '#A1A1AA');
      expect(premium.intensity, 'expressive');

      final bold = paletteFor(Tone.bold, '#FF0000');
      expect(bold.bg, '#111827');
      expect(bold.bgAlt, '#312E81');
      expect(bold.text, '#FFFFFF');
      expect(bold.subtext, '#E5E7EB');
      expect(bold.intensity, 'expressive');

      final calm = paletteFor(Tone.calm, '#FF0000');
      expect(calm.bg, '#F0FDFA');
      expect(calm.bgAlt, '#CCFBF1');
      expect(calm.text, '#134E4A');
      expect(calm.subtext, '#0F766E');
      expect(calm.intensity, 'safe');

      final minimal = paletteFor(Tone.minimal, '#FF0000');
      expect(minimal.bg, '#FFFFFF');
      expect(minimal.bgAlt, '#F4F4F5');
      expect(minimal.text, '#18181B');
      expect(minimal.subtext, '#52525B');
      expect(minimal.intensity, 'safe');
    });

    test('accent is the brand color passed in, unprocessed', () {
      expect(paletteFor(Tone.professional, '#ABCDEF').accent, '#ABCDEF');
      expect(paletteFor(Tone.minimal, '#123456').accent, '#123456');
    });
  });

  group('toneMood', () {
    test('carries the verbatim TONE_MOOD strings from promptSpec.ts', () {
      expect(toneMood[Tone.premium],
          'luxurious, dark, high-contrast, refined gradients');
      expect(toneMood[Tone.professional],
          'clean, corporate, trustworthy, soft depth');
      expect(toneMood[Tone.playful], 'friendly, vibrant, rounded, energetic');
      expect(toneMood[Tone.bold], 'high-energy, saturated, dynamic shapes');
      expect(toneMood[Tone.calm], 'soft, airy, pastel, soothing');
      expect(toneMood[Tone.minimal],
          'spare, lots of negative space, subtle texture');
    });
  });

  group('frameStyleFor', () {
    test(
        'matches the frame geometry table with Android phone radius adjustment',
        () {
      final iphone69 = frameStyleFor('iphone_6_9');
      expect(iphone69.cornerRadiusPct, 12);
      expect(iphone69.bezelPx, 12);
      expect(iphone69.hasIsland, isTrue);
      expect(iphone69.isApple, isTrue);

      final ipad13 = frameStyleFor('ipad_13');
      expect(ipad13.cornerRadiusPct, 4);
      expect(ipad13.bezelPx, 14);
      expect(ipad13.hasIsland, isFalse);
      expect(ipad13.isApple, isTrue);

      final androidTablet10 = frameStyleFor('android_tablet_10');
      expect(androidTablet10.cornerRadiusPct, 4);
      expect(androidTablet10.bezelPx, 14);
      expect(androidTablet10.hasIsland, isFalse);
      expect(androidTablet10.isApple, isFalse);

      final androidPhone = frameStyleFor('android_phone');
      expect(androidPhone.cornerRadiusPct, 5);
      expect(androidPhone.bezelPx, 12);
      expect(androidPhone.hasIsland, isFalse);
      expect(androidPhone.isApple, isFalse);
    });
  });

  group('textOverlayFraction', () {
    test('matches the verbatim templates.ts overlay-fraction table', () {
      expect(
          textOverlayFraction(ComposeLayout.centeredDevice,
              hasSubheadline: false),
          0.2);
      expect(
          textOverlayFraction(ComposeLayout.centeredDevice,
              hasSubheadline: true),
          0.24);
      expect(
          textOverlayFraction(ComposeLayout.tiltedDevice,
              hasSubheadline: false),
          0.2);
      expect(
          textOverlayFraction(ComposeLayout.tiltedDevice, hasSubheadline: true),
          0.24);
      expect(
          textOverlayFraction(ComposeLayout.dualDevice, hasSubheadline: false),
          0.2);
      expect(
          textOverlayFraction(ComposeLayout.dualDevice, hasSubheadline: true),
          0.24);
      expect(
          textOverlayFraction(ComposeLayout.textBanner, hasSubheadline: false),
          0.22);
      expect(
          textOverlayFraction(ComposeLayout.textBanner, hasSubheadline: true),
          0.26);
      expect(
          textOverlayFraction(ComposeLayout.featureCallout,
              hasSubheadline: false),
          0.26);
      expect(
          textOverlayFraction(ComposeLayout.featureCallout,
              hasSubheadline: true),
          0.30);
      expect(
          textOverlayFraction(ComposeLayout.fullBleed, hasSubheadline: false),
          1.0);
      expect(textOverlayFraction(ComposeLayout.fullBleed, hasSubheadline: true),
          1.0);
    });
  });

  group('ComposeLayout wire strings', () {
    test('round-trip through fromWire', () {
      for (final l in ComposeLayout.values) {
        expect(ComposeLayout.fromWire(l.wire), l);
      }
      expect(ComposeLayout.centeredDevice.wire, 'centered_device');
      expect(ComposeLayout.tiltedDevice.wire, 'tilted_device');
      expect(ComposeLayout.dualDevice.wire, 'dual_device');
      expect(ComposeLayout.featureCallout.wire, 'feature_callout');
      expect(ComposeLayout.textBanner.wire, 'text_banner');
      expect(ComposeLayout.fullBleed.wire, 'full_bleed');
    });
  });

  group('ComposeManifest JSON round-trip', () {
    test('round-trips an image-background entry and a deviceless entry', () {
      const manifest = ComposeManifest(entries: [
        ComposeEntry(
          id: 'hero_iphone',
          deviceClass: 'iphone_6_9',
          headline: 'Track every wallet',
          subheadline: 'One dashboard for all your chains',
          raw: 'raw/hero_iphone_raw.png',
          logo: 'assets/logo.png',
          tone: Tone.professional,
          layout: ComposeLayout.centeredDevice,
          brandColor: '#4F46E5',
          palette: Palette(
            bg: '#0F172A',
            bgAlt: '#1E293B',
            text: '#FFFFFF',
            subtext: '#CBD5E1',
            accent: '#4F46E5',
            intensity: 'balanced',
          ),
          background: ComposeBackground(kind: 'image', path: 'bg/hero.png'),
          deviceless: false,
          out: 'outputs/app_store/iphone_6_9/hero_iphone.png',
        ),
        ComposeEntry(
          id: 'feature_graphic',
          deviceClass: 'feature_graphic',
          headline: 'The only wallet you need',
          raw: null,
          tone: Tone.premium,
          layout: ComposeLayout.fullBleed,
          brandColor: '#4F46E5',
          palette: Palette(
            bg: '#0B0B0F',
            bgAlt: '#17171F',
            text: '#FFFFFF',
            subtext: '#A1A1AA',
            accent: '#4F46E5',
            intensity: 'expressive',
          ),
          background: ComposeBackground(kind: 'css', style: 'gradient'),
          deviceless: true,
          out: 'outputs/play_store/feature_graphic/feature_graphic.png',
        ),
      ]);

      final roundTripped = ComposeManifest.fromJson(manifest.toJson());
      expect(roundTripped.toJson(), manifest.toJson());
    });

    test('fromJson throws FormatException when raw is null and not deviceless',
        () {
      final json = {
        'entries': [
          {
            'id': 'hero_iphone',
            'deviceClass': 'iphone_6_9',
            'headline': 'Track every wallet',
            'tone': 'professional',
            'layout': 'centered_device',
            'brandColor': '#4F46E5',
            'background': {'kind': 'css', 'style': 'gradient'},
            'deviceless': false,
            'out': 'outputs/app_store/iphone_6_9/hero_iphone.png',
            // raw intentionally omitted / null
          },
        ],
      };
      expect(() => ComposeManifest.fromJson(json),
          throwsA(isA<FormatException>()));
    });
  });
}
