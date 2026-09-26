// flutter-app-shots/tool/test/prompt_spec_test.dart
//
// Ported verbatim from compositor/src/promptSpec.ts.
import 'package:app_shots/src/compose_specs.dart';
import 'package:app_shots/src/prompt_spec.dart';
import 'package:app_shots/src/store_specs.dart';
import 'package:test/test.dart';

void main() {
  StoreTarget target(String deviceClass) =>
      storeTargets.firstWhere((t) => t.deviceClass == deviceClass);

  group('backgroundPromptSpec — iphone_6_9 + premium + #FF0000', () {
    late ImagePromptSpec spec;

    setUp(() {
      spec =
          backgroundPromptSpec(target('iphone_6_9'), Tone.premium, '#FF0000');
    });

    test('prompt contains the tone-mood sentence fragment verbatim', () {
      expect(
        spec.prompt,
        contains(
          'Abstract marketing background for an app store screenshot, '
          'luxurious, dark, high-contrast, refined gradients mood (premium). ',
        ),
      );
    });

    test('prompt contains the brand-color palette sentence fragment verbatim',
        () {
      expect(
        spec.prompt,
        contains(
          'Color palette anchored on brand color #FF0000 with #0B0B0F and #17171F tones.',
        ),
      );
    });

    test('prompt contains the fixed compositional sentence fragment verbatim',
        () {
      expect(
        spec.prompt,
        contains(
          'Smooth gradients and soft geometric shapes. Leave a clear, uncluttered '
          'central focal area where a phone mockup will be placed on top.',
        ),
      );
    });

    test('prompt contains the exact canvas dimensions sentence', () {
      expect(spec.prompt, contains('Composition for a 1320x2868 canvas.'));
    });

    test('negativePrompt equals the verbatim fixed string', () {
      expect(
        spec.negativePrompt,
        'no text, no words, no typography, no app UI, no screenshots, no user interface, no buttons, '
        'no logos, no watermark, no device frame, no phone, no hands, no people, no clutter in the center',
      );
    });

    test('aspectRatio is "1320:2868"', () {
      expect(spec.aspectRatio, '1320:2868');
    });

    test('width/height mirror the target', () {
      expect(spec.width, 1320);
      expect(spec.height, 2868);
    });
  });

  group('TONE_MOOD coverage in prompt text', () {
    test('every tone produces its verbatim mood string in the prompt', () {
      for (final tone in Tone.values) {
        final spec =
            backgroundPromptSpec(target('android_phone'), tone, '#00FF00');
        expect(spec.prompt, contains('${toneMood[tone]} mood (${tone.name}).'));
      }
    });
  });

  group('per-target dimensions', () {
    test('android_phone yields aspectRatio 1080:1920', () {
      final spec =
          backgroundPromptSpec(target('android_phone'), Tone.bold, '#123456');
      expect(spec.aspectRatio, '1080:1920');
      expect(spec.width, 1080);
      expect(spec.height, 1920);
    });
  });

  group('variant composition sentence', () {
    ImagePromptSpec at(int variant) => backgroundPromptSpec(
        target('iphone_6_9'), Tone.playful, '#00FF00',
        variant: variant);

    test('variant 0 keeps the original composition sentence', () {
      expect(
        at(0).prompt,
        contains('Smooth gradients and soft geometric shapes. Leave a clear, '
            'uncluttered central focal area where a phone mockup will be '
            'placed on top.'),
      );
    });

    test('variant 1 uses the color-orbs composition sentence', () {
      expect(at(1).prompt,
          contains('Bold overlapping color orbs and gentle light bloom.'));
      expect(at(1).prompt, isNot(contains('Smooth gradients and soft')));
    });

    test('variant 2 uses the layered-depth composition sentence', () {
      expect(at(2).prompt,
          contains('Layered depth with diagonal light streaks and subtle grain.'));
    });

    test('variant wraps modulo the sentence count', () {
      expect(at(3).prompt, equals(at(0).prompt));
    });
  });
}
