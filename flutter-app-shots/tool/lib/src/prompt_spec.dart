// flutter-app-shots/tool/lib/src/prompt_spec.dart
//
// Background image-generation prompt builder. Originally ported from
// compositor/src/promptSpec.ts (§8 of the port surface); the composition
// sentence is now variant-aware and maintained here, not mirrored from the
// retired TS source. The negative prompt stays fixed and verbatim.
import 'compose_specs.dart';
import 'store_specs.dart';

/// The image-generation prompt spec for a background, ported verbatim from
/// `ImagePromptSpec` in promptSpec.ts.
class ImagePromptSpec {
  final String prompt;
  final String negativePrompt;
  final int width;
  final int height;
  final String aspectRatio;

  const ImagePromptSpec({
    required this.prompt,
    required this.negativePrompt,
    required this.width,
    required this.height,
    required this.aspectRatio,
  });

  Map<String, dynamic> toJson() => {
        'prompt': prompt,
        'negativePrompt': negativePrompt,
        'width': width,
        'height': height,
        'aspectRatio': aspectRatio,
      };
}

/// Fixed negative prompt — verbatim from promptSpec.ts. Identical for every
/// tone/device/store; no per-device or per-store variation.
const String _negativePrompt =
    'no text, no words, no typography, no app UI, no screenshots, no user interface, no buttons, '
    'no logos, no watermark, no device frame, no phone, no hands, no people, no clutter in the center';

/// Builds the background image-generation [ImagePromptSpec] for [target] +
/// [tone] + [brandColor]. [variant] selects one of a few composition
/// phrasings so multiple generated backgrounds in one screenshot set differ
/// instead of all reading the same; variant 0 is the original phrasing. The
/// tone mood leads the prompt; the fixed negative prompt keeps all app UI,
/// text, and device chrome out of the generated art.
ImagePromptSpec backgroundPromptSpec(
    StoreTarget target, Tone tone, String brandColor,
    {int variant = 0}) {
  final p = paletteFor(tone, brandColor);
  final prompt =
      'Abstract marketing background for an app store screenshot, ${toneMood[tone]} mood (${tone.name}). '
      'Color palette anchored on brand color $brandColor with ${p.bg} and ${p.bgAlt} tones. '
      '${_variantComposition(variant)} Leave a clear, uncluttered central focal area where a phone '
      'mockup will be placed on top. Composition for a ${target.width}x${target.height} canvas.';
  return ImagePromptSpec(
    prompt: prompt,
    negativePrompt: _negativePrompt,
    width: target.width,
    height: target.height,
    aspectRatio: '${target.width}:${target.height}',
  );
}

/// Composition sentence per [variant] (wraps modulo the list). Variant 0 is
/// verbatim the original single-composition phrasing.
String _variantComposition(int variant) {
  const sentences = [
    'Smooth gradients and soft geometric shapes.',
    'Bold overlapping color orbs and gentle light bloom.',
    'Layered depth with diagonal light streaks and subtle grain.',
  ];
  return sentences[variant % sentences.length];
}
