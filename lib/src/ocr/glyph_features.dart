import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

import 'gray_image.dart';

/// Size-normalized picture of one character, compared by normalized cross
/// correlation. The glyph keeps its aspect ratio (scaled to [height] rows and
/// centred in [width] columns) so narrow and wide characters stay distinct.
class GlyphFeatures {
  const GlyphFeatures({required this.values, required this.heightRatio, required this.aspect, required this.bottomInk});

  static const int width = 20;
  static const int height = 24;

  /// Ink amount 0..1 per cell, zero mean / unit norm (ready for dot products).
  final Float32List values;

  /// Ink height relative to the line's capital height ('<' is about half).
  final double heightRatio;

  /// Ink width / ink height.
  final double aspect;

  /// Relative ink in the bottom-right corner: tells E from F, L from I...
  /// where whole-glyph correlation is close.
  final double bottomInk;

  /// Builds features from the ink inside [cell] (dark on light), where pixels
  /// darker than [threshold] count as ink and [capHeight] is the line height.
  static GlyphFeatures? fromCell(GrayImage cell, {required int threshold, required double capHeight}) {
    final raster = rasterize(cell, threshold: threshold);
    if (raster == null) return null;
    final (values, inkWidth, inkHeight) = raster;
    return GlyphFeatures(
      bottomInk: bottomInkOf(values),
      values: normalize(values),
      heightRatio: inkHeight / capHeight,
      aspect: inkWidth / inkHeight,
    );
  }

  /// Ink darkness (0..1) of [cell] scaled into the [width] x [height] grid,
  /// with the ink bounding box size in pixels. Null when there is no ink.
  static (Float32List, int, int)? rasterize(GrayImage cell, {required int threshold}) {
    // Ink bounding box from row/column projections, trimming sparse edges so
    // isolated dark specks (security print, JPEG noise) do not stretch it.
    final rows = List.filled(cell.height, 0);
    final columns = List.filled(cell.width, 0);
    for (var y = 0; y < cell.height; y++) {
      for (var x = 0; x < cell.width; x++) {
        if (cell.at(x, y) < threshold) {
          rows[y]++;
          columns[x]++;
        }
      }
    }
    final (top, bottom) = _trim(rows);
    final (left, right) = _trim(columns);
    if (right < left || bottom < top) return null;
    final inkWidth = right - left + 1;
    final inkHeight = bottom - top + 1;
    final ink = cell.crop(Rect.fromLTRB(left.toDouble(), top.toDouble(), right + 1.0, bottom + 1.0));
    final scaledWidth = max(1, min(width, (inkWidth * height / inkHeight).round()));
    final scaled = ink.resize(scaledWidth, height);
    final values = Float32List(width * height);
    final offset = (width - scaledWidth) ~/ 2;
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < scaledWidth; x++) {
        values[y * width + offset + x] = (threshold - scaled.at(x, y)).clamp(0, threshold) / threshold;
      }
    }
    return (values, inkWidth, inkHeight);
  }

  /// Ink in the bottom-right corner relative to the glyph's mean ink (raw,
  /// not normalized [values]), so pale and dark print compare alike.
  static double bottomInkOf(Float32List values) {
    final mean = values.reduce((a, b) => a + b) / values.length;
    if (mean <= 0) return 0;
    final top = (height * _bottomBand).floor();
    final left = (width * _rightBand).floor();
    var sum = 0.0;
    var count = 0;
    for (var y = top; y < height; y++) {
      for (var x = left; x < width; x++) {
        sum += values[y * width + x];
        count++;
      }
    }
    return sum / count / mean / _bottomInkScale;
  }

  static const double _bottomBand = 0.82;
  static const double _rightBand = 0.5;

  /// Keeps the ratio roughly in 0..1.
  static const double _bottomInkScale = 4;

  /// First and last index whose count reaches a fraction of the peak.
  static (int, int) _trim(List<int> counts) {
    final peak = counts.reduce(max);
    if (peak == 0) return (0, -1);
    final minimum = max(_minInkCount, (peak * _trimFraction).ceil());
    var start = 0;
    while (start < counts.length && counts[start] < minimum) {
      start++;
    }
    var end = counts.length - 1;
    while (end > start && counts[end] < minimum) {
      end--;
    }
    return (start, end);
  }

  static const int _minInkCount = 2;
  static const double _trimFraction = 0.12;

  /// Zero mean, unit length.
  static Float32List normalize(Float32List values) {
    final mean = values.reduce((a, b) => a + b) / values.length;
    var norm = 0.0;
    for (var i = 0; i < values.length; i++) {
      values[i] -= mean;
      norm += values[i] * values[i];
    }
    norm = sqrt(norm);
    if (norm > 0) {
      for (var i = 0; i < values.length; i++) {
        values[i] /= norm;
      }
    }
    return values;
  }

  /// Normalized cross correlation with [other] (-1..1).
  double correlation(GlyphFeatures other) {
    var dot = 0.0;
    for (var i = 0; i < values.length; i++) {
      dot += values[i] * other.values[i];
    }
    return dot;
  }
}
