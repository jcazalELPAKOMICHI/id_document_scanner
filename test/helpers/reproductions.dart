import 'dart:math';

import 'package:image/image.dart' as img;

/// The card shown on an LCD: every card pixel becomes a 3x3 block of R, G
/// and B sub-pixel stripes with a dark gap row, as a camera close to a
/// screen sees it.
img.Image onScreen(img.Image card, {int width = 700}) {
  final source = img.copyResize(card, width: width);
  final screen = img.Image(width: source.width * 3, height: source.height * 3);
  for (var y = 0; y < source.height; y++) {
    for (var x = 0; x < source.width; x++) {
      final p = source.getPixel(x, y);
      for (var sy = 0; sy < 3; sy++) {
        final gap = sy == 2 ? 0.55 : 1.0;
        screen
          ..setPixelRgb(x * 3, y * 3 + sy, (p.r * gap).round(), 0, 0)
          ..setPixelRgb(x * 3 + 1, y * 3 + sy, 0, (p.g * gap).round(), 0)
          ..setPixelRgb(x * 3 + 2, y * 3 + sy, 0, 0, (p.b * gap).round());
      }
    }
  }
  // Lens blur, then the camera's own sampling of the grid.
  return img.gaussianBlur(screen, radius: 1);
}

/// The card printed by a colour printer: each channel rendered with
/// amplitude-modulated dots on a rotated screen (classic halftone).
img.Image printed(img.Image card, {int width = 1012, double period = 4.2}) {
  final source = img.copyResize(card, width: width);
  final out = img.Image(width: source.width, height: source.height);
  const angles = [15.0, 75.0, 0.0];
  for (var y = 0; y < source.height; y++) {
    for (var x = 0; x < source.width; x++) {
      final p = source.getPixel(x, y);
      final channels = [p.r, p.g, p.b];
      final inked = List.generate(3, (c) {
        final a = angles[c] * pi / 180;
        final u = (x * cos(a) + y * sin(a)) / period;
        final v = (-x * sin(a) + y * cos(a)) / period;
        final du = u - u.floorToDouble() - 0.5;
        final dv = v - v.floorToDouble() - 0.5;
        final coverage = 1 - channels[c] / 255; // ink amount for this channel
        return du * du + dv * dv < coverage * 0.32 ? 0 : 255;
      });
      out.setPixelRgb(x, y, inked[0], inked[1], inked[2]);
    }
  }
  return img.gaussianBlur(out, radius: 1);
}
