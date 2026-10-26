import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:id_document_scanner/id_document_scanner.dart';
import 'package:image/image.dart' as img;

import 'helpers/synthetic_scene.dart';

/// Photo of [card] on a dark desk, rotated [angle] degrees around [center].
(img.Image, List<Offset>) photoOf(img.Image card, {required Size size, required Rect rect, double angle = 0}) {
  final photo = img.Image(width: size.width.round(), height: size.height.round());
  img.fill(photo, color: img.ColorRgb8(52, 44, 38));
  final resized = img.copyResize(card, width: rect.width.round(), height: rect.height.round()).convert(numChannels: 4);
  final rotated = angle == 0 ? resized : img.copyRotate(resized, angle: angle, interpolation: .linear);
  img.compositeImage(
    photo,
    rotated,
    dstX: (rect.center.dx - rotated.width / 2).round(),
    dstY: (rect.center.dy - rotated.height / 2).round(),
  );
  final radians = angle * pi / 180;
  Offset corner(double dx, double dy) =>
      rect.center + Offset(dx * cos(radians) - dy * sin(radians), dx * sin(radians) + dy * cos(radians));
  final w = rect.width / 2, h = rect.height / 2;
  return (photo, [corner(-w, -h), corner(w, -h), corner(w, h), corner(-w, h)]);
}

LumaFrame lumaOf(img.Image image) {
  final bytes = Uint8List(image.width * image.height);
  for (var i = 0; i < bytes.length; i++) {
    bytes[i] = img.getLuminance(image.getPixel(i % image.width, i ~/ image.width)).round();
  }
  return LumaFrame(
    width: image.width,
    height: image.height,
    bytesPerRow: image.width,
    bytes: bytes,
    sensorOrientation: 0,
  );
}

/// Flat synthetic card with exact borders: light base, text-like dark
/// blocks close to the edges and a photo block, so the truth is exact.
img.Image syntheticCard() {
  final card = img.Image(width: 856, height: 540);
  img.fill(card, color: img.ColorRgb8(214, 206, 222));
  img.fillRect(card, x1: 30, y1: 120, x2: 250, y2: 420, color: img.ColorRgb8(90, 80, 85));
  for (var row = 0; row < 9; row++) {
    for (var block = 0; block < 6; block++) {
      final x = 290 + block * 90 + (row * 13) % 30;
      final y = 22 + row * 56;
      img.fillRect(card, x1: x, y1: y, x2: x + 60, y2: y + 16, color: img.ColorRgb8(40, 40, 60));
    }
  }
  return card;
}

void main() {
  final specimen = SyntheticScene.loadSpecimen();
  final flatCard = syntheticCard();
  const size = Size(1080, 1920);
  const cardRect = Rect.fromLTWH(90, 700, 900, 900 / ScannerConstants.idCardAspectRatio);

  for (final angle in [0.0, 2.5, -4.0]) {
    test('finds the corners of a card rotated $angle°', () {
      final (photo, truth) = photoOf(flatCard, size: size, rect: cardRect, angle: angle);
      // Live analysis is a few % off: shifted and slightly bigger.
      final expected = cardRect.shift(const Offset(18, -14)).inflate(12);
      final normalized = Rect.fromLTRB(
        expected.left / size.width,
        expected.top / size.height,
        expected.right / size.width,
        expected.bottom / size.height,
      );
      final corners = const CardEdgeRefiner().refine(lumaOf(photo), normalized)!.scaled(size);
      for (final (found, actual) in [
        (corners.topLeft, truth[0]),
        (corners.topRight, truth[1]),
        (corners.bottomRight, truth[2]),
        (corners.bottomLeft, truth[3]),
      ]) {
        expect((found - actual).distance, lessThan(4), reason: 'found $found expected $actual');
      }
    });
  }

  test('nothing to refine when there is no card', () {
    final photo = img.Image(width: 540, height: 960);
    img.fill(photo, color: img.ColorRgb8(52, 44, 38));
    expect(const CardEdgeRefiner().refine(lumaOf(photo), const Rect.fromLTWH(0.1, 0.35, 0.8, 0.3)), isNull);
  });

  test('crops only the card, straightened to ID-1', () async {
    final (photo, _) = photoOf(specimen, size: size, rect: cardRect, angle: 3);
    // The preview is 9:16 like the photo, so preview and photo coordinates match.
    final expected = Rect.fromLTRB(
      (cardRect.left - 20) / size.width,
      (cardRect.top + 10) / size.height,
      (cardRect.right + 15) / size.width,
      (cardRect.bottom - 8) / size.height,
    );
    final cropped = await DocumentCropper.cropCard(img.encodeJpg(photo), expected: expected, preview: size);
    expect(cropped.isPrecise, isTrue);
    final card = img.decodeJpg(cropped.image)!;
    expect(card.width / card.height, closeTo(ScannerConstants.idCardAspectRatio, 0.01));
    expect(card.width, closeTo(cardRect.width, 12));
    // Just inside each edge there is card, not desk.
    for (final (x, y) in [(0.5, 0.012), (0.5, 0.988), (0.008, 0.5), (0.992, 0.5)]) {
      final pixel = card.getPixel((x * card.width).round(), (y * card.height).round());
      expect(img.getLuminance(pixel), greaterThan(120), reason: 'edge sample at ($x, $y)');
    }
  });

  test('maps preview coordinates onto a photo with another aspect ratio', () {
    // 16:9 preview over a 4:3 photo: the preview shows the middle 75 % horizontally.
    final mapped = GuideGeometry.previewToPhoto(
      const Rect.fromLTRB(0, 0.25, 1, 0.75),
      const Size(1080, 1920),
      const Size(1440, 1920),
    );
    expect(mapped.left, closeTo(0.125, 1e-9));
    expect(mapped.right, closeTo(0.875, 1e-9));
    expect(mapped.top, 0.25);
  });
}
