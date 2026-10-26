import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:id_document_scanner/id_document_scanner.dart';
import 'package:id_document_scanner/src/ocr/gray_image.dart';
import 'package:image/image.dart' as img;

import 'helpers/legacy_back_card.dart';

img.Image load(String name) => img.decodeWebP(File('test/fixtures/$name').readAsBytesSync())!;

/// Photographs [card] (rotated, on a desk, darker, JPEG) and crops it back
/// with the SDK, like a real capture; in grayscale.
Future<GrayImage> capture(
  img.Image card, {
  double angle = 3,
  double brightness = 0.8,
  int blur = 0,
  int quality = 85,
}) async =>
    GrayImage.fromImage(await captureCard(card, angle: angle, brightness: brightness, blur: blur, quality: quality));

/// Same as [capture], returning the colour card crop.
Future<img.Image> captureCard(
  img.Image card, {
  double angle = 3,
  double brightness = 0.8,
  int blur = 0,
  int quality = 85,
}) async {
  final cropped = await cropPhotographed(card, angle: angle, brightness: brightness, blur: blur, quality: quality);
  expect(cropped.isPrecise, isTrue);
  return img.decodeJpg(cropped.image)!;
}

/// Photographs [card] on a desk (rotated, darker, blurred, JPEG) and runs the
/// SDK crop on it, returning the full crop result.
Future<CroppedCard> cropPhotographed(
  img.Image card, {
  double angle = 3,
  double brightness = 0.8,
  int blur = 0,
  int quality = 85,
}) {
  const size = Size(1080, 1920);
  const rect = Rect.fromLTWH(90, 700, 900, 900 / ScannerConstants.idCardAspectRatio);
  final photo = img.Image(width: 1080, height: 1920);
  img.fill(photo, color: img.ColorRgb8(50, 42, 36));
  final placed = img.copyRotate(
    img.copyResize(card, width: rect.width.round(), height: rect.height.round()).convert(numChannels: 4),
    angle: angle,
    interpolation: .linear,
  );
  img.compositeImage(
    photo,
    placed,
    dstX: (rect.center.dx - placed.width / 2).round(),
    dstY: (rect.center.dy - placed.height / 2).round(),
  );
  // Sensor noise: a real camera never delivers perfectly flat areas.
  img.noise(photo, 2.5, random: Random(7));
  final adjusted = img.adjustColor(photo, brightness: brightness);
  final dim = blur > 0 ? img.gaussianBlur(adjusted, radius: blur) : adjusted;
  final expected = Rect.fromLTRB(
    rect.left / size.width,
    rect.top / size.height,
    rect.right / size.width,
    rect.bottom / size.height,
  );
  return DocumentCropper.cropCard(
    img.encodeJpg(dim, quality: quality),
    expected: expected,
    preview: size,
  );
}

/// A card that is not Paraguayan: other header text, other layout.
img.Image otherCard() {
  final card = img.Image(width: 1012, height: 638);
  img.fill(card, color: img.ColorRgb8(196, 220, 236));
  img.drawString(card, 'REPUBLICA ARGENTINA', font: img.arial48, x: 260, y: 40, color: img.ColorRgb8(30, 30, 60));
  img.drawString(card, 'DOCUMENTO NACIONAL', font: img.arial24, x: 260, y: 100, color: img.ColorRgb8(30, 30, 60));
  img.fillRect(card, x1: 40, y1: 160, x2: 320, y2: 520, color: img.ColorRgb8(120, 110, 115));
  for (var i = 0; i < 3; i++) {
    img.drawString(
      card,
      'IDARG12345678<<<<<<<<<<<<<<<<<',
      font: img.arial24,
      x: 60,
      y: 540 + i * 30,
      color: img.ColorRgb8(20, 20, 20),
    );
  }
  return card;
}

/// Previous-design front: the real header strip (no personal data) on a
/// plain body.
img.Image legacyFront() {
  final card = img.Image(width: 1012, height: 638);
  img.fill(card, color: img.ColorRgb8(205, 214, 232));
  img.fillRect(card, x1: 640, y1: 140, x2: 900, y2: 470, color: img.ColorRgb8(140, 130, 150));
  for (var i = 0; i < 6; i++) {
    img.fillRect(card, x1: 50, y1: 170 + i * 60, x2: 380, y2: 190 + i * 60, color: img.ColorRgb8(40, 40, 70));
  }
  final strip = img.decodePng(File('test/fixtures/paraguay_id_legacy_front_header.png').readAsBytesSync())!;
  img.compositeImage(card, strip);
  return card;
}

void main() {
  const verifier = ParaguayIdVerifier();
  final front = load('paraguay_id_current_specimen.webp');
  final back = load('paraguay_id_current_back_specimen.webp');

  group('front', () {
    test('recognises the current card photographed', () async {
      final result = verifier.verifyFront(await capture(front), .paraguayIdCurrent);
      printOnFailure('score ${result.score}');
      expect(result.status, DocumentVerificationStatus.verified);
      expect(result.detectedType, DocumentType.paraguayIdCurrent);
    });

    test('rejects the back shown as front', () async {
      final result = verifier.verifyFront(await capture(back), .paraguayIdCurrent);
      printOnFailure('score ${result.score}');
      expect(result.status, DocumentVerificationStatus.rejected);
      expect(result.reason, DocumentRejectionReason.frontNotRecognized);
    });

    test('rejects another country card', () async {
      final result = verifier.verifyFront(await capture(otherCard()), .paraguayIdCurrent);
      printOnFailure('score ${result.score}');
      expect(result.status, DocumentVerificationStatus.rejected);
    });

    test('an unknown card is rejected whatever design was expected', () async {
      final result = verifier.verifyFront(await capture(otherCard()), .paraguayIdLegacy);
      expect(result.status, DocumentVerificationStatus.rejected);
    });

    test('recognises the previous design by its header', () async {
      for (final expected in DocumentType.values) {
        final result = verifier.verifyFront(await capture(legacyFront()), expected);
        printOnFailure('score ${result.score}');
        expect(result.status, DocumentVerificationStatus.verified);
        expect(result.detectedType, DocumentType.paraguayIdLegacy);
      }
    });

    test('the current design is not mistaken for the previous one', () async {
      final result = verifier.verifyFront(await capture(front), .paraguayIdLegacy);
      expect(result.detectedType, DocumentType.paraguayIdCurrent);
    });
  });

  group('back', () {
    test('reads and validates the MRZ of the current card photographed', () async {
      final result = verifier.verifyBack(await capture(back), .paraguayIdCurrent);
      printOnFailure('${result.reason} ${result.mrzLines?.join(' | ')}');
      expect(result.status, DocumentVerificationStatus.verified);
      expect(result.detectedType, DocumentType.paraguayIdCurrent);
      expect(result.mrz!.documentNumber, 'AA0008958');
      expect(result.mrz!.surnames, 'MARTINIEZ');
    });

    test('auto-detects the design when the expected one is wrong', () async {
      final result = verifier.verifyBack(await capture(back, angle: -2), .paraguayIdLegacy);
      expect(result.status, DocumentVerificationStatus.verified);
      expect(result.detectedType, DocumentType.paraguayIdCurrent);
    });

    test('rejects the front shown as back', () async {
      final result = verifier.verifyBack(await capture(front), .paraguayIdCurrent);
      expect(result.status, DocumentVerificationStatus.rejected);
    });

    test('rejects another country card', () async {
      final result = verifier.verifyBack(await capture(otherCard()), .paraguayIdCurrent);
      expect(result.status, DocumentVerificationStatus.rejected);
    });

    testWidgets('reads the previous design (fictional MRZ, OCR-B)', (tester) async {
      await tester.runAsync(() async {
        final card = await legacyBackCard();
        for (final angle in [0.0, 3.0, -2.0]) {
          final result = verifier.verifyBack(await capture(card, angle: angle), .paraguayIdCurrent);
          printOnFailure('$angle ${result.reason} ${result.mrzLines}');
          expect(result.status, DocumentVerificationStatus.verified);
          expect(result.detectedType, DocumentType.paraguayIdLegacy);
          expect(result.mrz!.documentNumber, '1234567');
          expect(result.mrz!.surnames, 'PEREZ');
        }
      });
    });

    test('a valid MRZ from another country is not a Paraguayan ID', () {
      // ICAO 9303 sample TD1 (fictional state "UTO").
      final mrz = MrzParser.parse([
        'I<UTOD231458907<<<<<<<<<<<<<<<',
        '7408122F1204159UTO<<<<<<<<<<<6',
        'ERIKSSON<<ANNA<MARIA<<<<<<<<<<',
      ])!;
      expect(mrz.isValid, isTrue);
      expect(ParaguayIdVerifier.isParaguayanId(mrz), isFalse);
    });
  });
}
