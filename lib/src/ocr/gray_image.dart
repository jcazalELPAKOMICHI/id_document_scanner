import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

import 'package:image/image.dart' as img;

/// 8-bit grayscale image (0 = black) with the few operations the OCR needs.
class GrayImage {
  GrayImage({required this.width, required this.height, required this.pixels});

  factory GrayImage.fromImage(img.Image image) {
    final rgb = image.convert(numChannels: _rgbChannels).getBytes(order: img.ChannelOrder.rgb);
    final pixels = Uint8List(image.width * image.height);
    for (var i = 0; i < pixels.length; i++) {
      final j = i * _rgbChannels;
      pixels[i] = (77 * rgb[j] + 150 * rgb[j + 1] + 29 * rgb[j + 2]) >> 8;
    }
    return GrayImage(width: image.width, height: image.height, pixels: pixels);
  }

  final int width;
  final int height;
  final Uint8List pixels;

  int at(int x, int y) => pixels[y.clamp(0, height - 1) * width + x.clamp(0, width - 1)];

  /// Crops [region] given normalized to this image (0..1).
  GrayImage cropNormalized(Rect region) =>
      crop(Rect.fromLTRB(region.left * width, region.top * height, region.right * width, region.bottom * height));

  /// Crops [region] in pixels, clamped to the image.
  GrayImage crop(Rect region) {
    final left = region.left.round().clamp(0, width - 1);
    final top = region.top.round().clamp(0, height - 1);
    final right = region.right.round().clamp(left + 1, width);
    final bottom = region.bottom.round().clamp(top + 1, height);
    final out = Uint8List((right - left) * (bottom - top));
    for (var y = top; y < bottom; y++) {
      out.setRange((y - top) * (right - left), (y - top + 1) * (right - left), pixels, y * width + left);
    }
    return GrayImage(width: right - left, height: bottom - top, pixels: out);
  }

  /// Bilinear resize.
  GrayImage resize(int newWidth, int newHeight) {
    final out = Uint8List(newWidth * newHeight);
    final sx = width / newWidth;
    final sy = height / newHeight;
    for (var y = 0; y < newHeight; y++) {
      final fy = max(0.0, (y + 0.5) * sy - 0.5);
      final y0 = fy.floor();
      final dy = fy - y0;
      for (var x = 0; x < newWidth; x++) {
        final fx = max(0.0, (x + 0.5) * sx - 0.5);
        final x0 = fx.floor();
        final dx = fx - x0;
        final top = at(x0, y0) * (1 - dx) + at(x0 + 1, y0) * dx;
        final bottom = at(x0, y0 + 1) * (1 - dx) + at(x0 + 1, y0 + 1) * dx;
        out[y * newWidth + x] = (top * (1 - dy) + bottom * dy).round();
      }
    }
    return GrayImage(width: newWidth, height: newHeight, pixels: out);
  }

  /// 3x3 mean filter: removes single-pixel sensor noise before binarizing.
  GrayImage smoothed() {
    final out = Uint8List(pixels.length);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        var sum = 0;
        for (var dy = -1; dy <= 1; dy++) {
          for (var dx = -1; dx <= 1; dx++) {
            sum += at(x + dx, y + dy);
          }
        }
        out[y * width + x] = sum ~/ _kernelSize;
      }
    }
    return GrayImage(width: width, height: height, pixels: out);
  }

  /// Otsu threshold: pixels darker than it are ink.
  int otsuThreshold() {
    final histogram = List.filled(_levels, 0);
    for (final value in pixels) {
      histogram[value]++;
    }
    final total = pixels.length;
    var sum = 0.0;
    for (var i = 0; i < _levels; i++) {
      sum += i * histogram[i];
    }
    var sumBackground = 0.0;
    var weightBackground = 0;
    var best = 0.0;
    var threshold = _levels ~/ 2;
    for (var i = 0; i < _levels; i++) {
      weightBackground += histogram[i];
      if (weightBackground == 0) continue;
      final weightForeground = total - weightBackground;
      if (weightForeground == 0) break;
      sumBackground += i * histogram[i];
      final meanBackground = sumBackground / weightBackground;
      final meanForeground = (sum - sumBackground) / weightForeground;
      final between = weightBackground * weightForeground * pow(meanBackground - meanForeground, 2);
      if (between > best) {
        best = between.toDouble();
        threshold = i;
      }
    }
    return threshold;
  }

  static const int _levels = 256;
  static const int _kernelSize = 9;
  static const int _rgbChannels = 3;
}
