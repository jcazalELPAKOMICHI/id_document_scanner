import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:id_document_scanner/id_document_scanner.dart';
import 'package:image/image.dart' as img;

import 'helpers/synthetic_scene.dart';

void main() {
  const analyzer = FrameAnalyzer();
  final specimen = SyntheticScene.loadSpecimen();

  FrameAnalysis analyze(SyntheticScene scene, {int sensorOrientation = 90}) {
    final analysis = analyzer.analyze(scene.toFrame(sensorOrientation: sensorOrientation), scene.normalizedGuide);
    printOnFailure(analysis.toString());
    return analysis;
  }

  for (final orientation in [0, 90, 180, 270]) {
    test('card filling the guide is ready (sensor $orientation°)', () {
      final scene = SyntheticScene()..paste(specimen, SyntheticScene().guide);
      final analysis = analyze(scene, sensorOrientation: orientation);
      expect(analysis.status, ScanStatus.ready);
      expect(analysis.detectedSides, 4);
    });
  }

  test('back side filling the guide is ready', () {
    final scene = SyntheticScene()..paste(SyntheticScene.loadBackSpecimen(), SyntheticScene().guide);
    expect(analyze(scene).status, ScanStatus.ready);
  });

  test('card slightly off the guide is still ready', () {
    final scene = SyntheticScene();
    scene.paste(specimen, scene.guide.shift(const Offset(12, -10)).inflate(6));
    expect(analyze(scene).status, ScanStatus.ready);
  });

  test('card on a light, low-contrast surface is still found', () {
    final scene = SyntheticScene(background: 120)..paste(specimen, SyntheticScene().guide);
    expect(analyze(scene).status, ScanStatus.ready);
  });

  test('empty scene keeps searching', () {
    expect(analyze(SyntheticScene()).status, ScanStatus.searching);
  });

  test('small card asks to move closer', () {
    final scene = SyntheticScene();
    final guide = scene.guide;
    scene.paste(
      specimen,
      Rect.fromCenter(center: guide.center, width: guide.width * 0.75, height: guide.height * 0.75),
    );
    expect(analyze(scene).status, ScanStatus.tooFar);
  });

  test('card held a few degrees off is still ready', () {
    for (final angle in [-4.0, 4.0]) {
      final scene = SyntheticScene();
      final guide = scene.guide;
      final tilted = img.copyRotate(
        img.copyResize(specimen, width: guide.width.round()).convert(numChannels: 4),
        angle: angle,
      );
      scene.paste(
        tilted,
        Rect.fromCenter(center: guide.center, width: tilted.width.toDouble(), height: tilted.height.toDouble()),
      );
      expect(analyze(scene).status, ScanStatus.ready);
    }
  });

  test('a finger over one side does not hide the card', () {
    final scene = SyntheticScene();
    final guide = scene.guide;
    scene
      ..paste(specimen, guide)
      ..fill(Rect.fromLTWH(guide.left - 30, guide.center.dy - 40, 90, 110), 175);
    expect(analyze(scene).status, ScanStatus.ready);
  });

  test('tilted card is not ready', () {
    final scene = SyntheticScene();
    final guide = scene.guide;
    final tilted = img.copyRotate(
      img.copyResize(specimen, width: guide.width.round()).convert(numChannels: 4),
      angle: 9,
    );
    scene.paste(
      tilted,
      Rect.fromCenter(center: guide.center, width: tilted.width.toDouble(), height: tilted.height.toDouble()),
    );
    expect(analyze(scene).status, isNot(ScanStatus.ready));
  });

  test('dark scene is reported', () {
    final scene = SyntheticScene()..paste(specimen, SyntheticScene().guide);
    scene.scale(0.2);
    expect(analyze(scene).status, ScanStatus.tooDark);
  });

  test('blurred card is reported', () {
    final scene = SyntheticScene()..paste(specimen, SyntheticScene().guide);
    scene.blur(7);
    expect(analyze(scene).status, ScanStatus.blurry);
  });

  test('reflection on the card is reported', () {
    final scene = SyntheticScene();
    final guide = scene.guide;
    scene
      ..paste(specimen, guide)
      ..fill(Rect.fromCenter(center: guide.center, width: guide.width * 0.3, height: guide.height * 0.3), 255);
    expect(analyze(scene).status, ScanStatus.glare);
  });

  test('card rect follows the measured edges', () {
    final scene = SyntheticScene();
    final guide = scene.guide;
    final placed = Rect.fromLTRB(guide.left + 20, guide.top + 12, guide.right - 10, guide.bottom - 8);
    scene.paste(specimen, placed);
    final analysis = analyze(scene);
    final card = analysis.cardRect(scene.normalizedGuide);
    expect(card.left * scene.width, closeTo(placed.left, 6));
    expect(card.top * scene.height, closeTo(placed.top, 6));
    expect(card.right * scene.width, closeTo(placed.right, 6));
    expect(card.bottom * scene.height, closeTo(placed.bottom, 6));
  });
}
