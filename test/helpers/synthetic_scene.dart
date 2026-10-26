import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

import 'package:id_document_scanner/id_document_scanner.dart';
import 'package:image/image.dart' as img;

/// Builds camera-like luminance frames from an upright scene, so the analyzer
/// can be tested without a device.
class SyntheticScene {
  SyntheticScene({this.width = 720, this.height = 1280, int background = 70, int seed = 7})
    : luma = Uint8List(width * height) {
    final random = Random(seed);
    for (var i = 0; i < luma.length; i++) {
      luma[i] = (background + random.nextInt(12) - 6).clamp(0, 255);
    }
  }

  final int width;
  final int height;
  final Uint8List luma;

  Size get size => Size(width.toDouble(), height.toDouble());

  /// Guide rect in normalized coordinates when the preview fills the screen exactly.
  Rect get normalizedGuide {
    final guide = GuideGeometry.guideRect(size);
    return Rect.fromLTRB(guide.left / width, guide.top / height, guide.right / width, guide.bottom / height);
  }

  Rect get guide => GuideGeometry.guideRect(size);

  static img.Image loadSpecimen() =>
      img.decodeWebP(File('test/fixtures/paraguay_id_current_specimen.webp').readAsBytesSync())!;

  static img.Image loadBackSpecimen() =>
      img.decodeWebP(File('test/fixtures/paraguay_id_current_back_specimen.webp').readAsBytesSync())!;

  void paste(img.Image card, Rect target) {
    final resized = img.copyResize(card, width: target.width.round(), height: target.height.round());
    for (var y = 0; y < resized.height; y++) {
      for (var x = 0; x < resized.width; x++) {
        final px = target.left.round() + x;
        final py = target.top.round() + y;
        final pixel = resized.getPixel(x, y);
        if (px < 0 || py < 0 || px >= width || py >= height || (resized.hasAlpha && pixel.a == 0)) continue;
        luma[py * width + px] = img.getLuminance(pixel).round();
      }
    }
  }

  void fill(Rect area, int value) {
    for (var y = max(0, area.top.round()); y < min(height, area.bottom.round()); y++) {
      for (var x = max(0, area.left.round()); x < min(width, area.right.round()); x++) {
        luma[y * width + x] = value;
      }
    }
  }

  void scale(double factor) {
    for (var i = 0; i < luma.length; i++) {
      luma[i] = (luma[i] * factor).round().clamp(0, 255);
    }
  }

  void blur(int radius) {
    final image = img.Image(width: width, height: height, numChannels: 1);
    for (var i = 0; i < luma.length; i++) {
      image.setPixelR(i % width, i ~/ width, luma[i]);
    }
    final blurred = img.gaussianBlur(image, radius: radius);
    for (var i = 0; i < luma.length; i++) {
      luma[i] = blurred.getPixel(i % width, i ~/ width).r.toInt();
    }
  }

  /// Returns the scene as the sensor would deliver it for [sensorOrientation].
  LumaFrame toFrame({int sensorOrientation = 90, int rowPadding = 16}) {
    final rotated = sensorOrientation == 90 || sensorOrientation == 270;
    final sensorWidth = rotated ? height : width;
    final sensorHeight = rotated ? width : height;
    final bytesPerRow = sensorWidth + rowPadding;
    final bytes = Uint8List(bytesPerRow * sensorHeight);
    for (var y = 0; y < sensorHeight; y++) {
      for (var x = 0; x < sensorWidth; x++) {
        final (u, v) = switch (sensorOrientation) {
          90 => (sensorHeight - 1 - y, x),
          180 => (sensorWidth - 1 - x, sensorHeight - 1 - y),
          270 => (y, sensorWidth - 1 - x),
          _ => (x, y),
        };
        bytes[y * bytesPerRow + x] = luma[v * width + u];
      }
    }
    return LumaFrame(
      width: sensorWidth,
      height: sensorHeight,
      bytesPerRow: bytesPerRow,
      bytes: bytes,
      sensorOrientation: sensorOrientation,
    );
  }
}
