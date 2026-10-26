import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'helpers/reproductions.dart';
import 'paraguay_id_verifier_test.dart' as v;

void main() {
  final cards = {
    'current front': v.load('paraguay_id_current_specimen.webp'),
    'current back': v.load('paraguay_id_current_back_specimen.webp'),
    'legacy front': v.legacyFront(),
  };

  for (final entry in cards.entries) {
    group(entry.key, () {
      test('a photo of the physical card is not flagged', () async {
        for (final (angle, brightness, blur) in [(-3.0, 0.7, 0), (0.0, 1.1, 0), (2.5, 0.9, 1)]) {
          final check = (await v.cropPhotographed(
            entry.value,
            angle: angle,
            brightness: brightness,
            blur: blur,
          )).reproduction;
          printOnFailure('$angle: ${check.lumaScore} / ${check.chromaScore}');
          expect(check.isReproduction, isFalse);
        }
      });

      test('a photo of a screen is flagged', () async {
        final screen = onScreen(entry.value);
        for (final angle in [-3.0, 0.0, 2.5]) {
          final check = (await v.cropPhotographed(screen, angle: angle)).reproduction;
          printOnFailure('$angle: ${check.lumaScore} / ${check.chromaScore}');
          expect(check.isReproduction, isTrue);
        }
      });

      test('a photo of a colour printout is flagged', () async {
        final copy = printed(entry.value);
        for (final angle in [-3.0, 0.0, 2.5]) {
          final check = (await v.cropPhotographed(copy, angle: angle)).reproduction;
          printOnFailure('$angle: ${check.lumaScore} / ${check.chromaScore}');
          expect(check.isReproduction, isTrue);
        }
      });
    });
  }

  test('screen detection survives a small, far away screen', () async {
    // A phone screen held further away: fewer, finer sub-pixels.
    final screen = onScreen(img.copyResize(cards['current front']!, width: 600), width: 420);
    final check = (await v.cropPhotographed(screen, angle: 1)).reproduction;
    printOnFailure('${check.lumaScore} / ${check.chromaScore}');
    expect(check.isReproduction, isTrue);
  });
}
