import 'dart:convert';
import 'dart:math';
import 'dart:ui';

import '../ocr/gray_image.dart';

/// Finds how well a reference crop appears around its expected place in a
/// card image (normalized cross correlation, coarse-to-fine search), so
/// lighting and contrast changes do not matter, only the printed shapes.
///
/// The reference is also tried at slightly different sizes: a crop that keeps
/// a bit of background, or cuts a bit of the card, scales the whole header.
class HeaderMatcher {
  const HeaderMatcher({this.searchMargin = 0.08, this.scaleRange = 0.1, this.scaleSteps = 4});

  /// Search distance around the expected place, as a fraction of the card.
  final double searchMargin;

  /// Largest size change of the reference tried (0.1 = 90 % to 110 %).
  final double scaleRange;

  /// Sizes tried on each side of 100 %.
  final int scaleSteps;

  /// Best correlation (-1..1) of [reference] around [expected] in [card].
  double match(GrayImage card, GrayImage reference, Rect expected) {
    final scales = List.generate(2 * scaleSteps + 1, (i) => 1 + scaleRange * (i - scaleSteps) / scaleSteps);
    final originX = expected.left * card.width;
    final originY = expected.top * card.height;

    // Coarse search over every size and position at low resolution...
    final coarseCard = card.resize(card.width ~/ _coarse, card.height ~/ _coarse);
    var best = double.negativeInfinity;
    var bestScale = 0;
    var bestX = 0;
    var bestY = 0;
    for (var s = 0; s < scales.length; s++) {
      final coarseRef = _scaled(reference, scales[s] / _coarse);
      // Keep the reference centred on its expected place while it grows.
      final centerX = (originX + reference.width * (1 - scales[s]) / 2) / _coarse;
      final centerY = (originY + reference.height * (1 - scales[s]) / 2) / _coarse;
      final dx = (card.width * searchMargin / _coarse).round();
      final dy = (card.height * searchMargin / _coarse).round();
      for (var y = centerY.round() - dy; y <= centerY.round() + dy; y++) {
        for (var x = centerX.round() - dx; x <= centerX.round() + dx; x++) {
          final score = _correlation(coarseCard, coarseRef, x, y);
          if (score > best) {
            best = score;
            bestScale = s;
            bestX = x * _coarse;
            bestY = y * _coarse;
          }
        }
      }
    }

    // ...then refine at full resolution around the best spot and size.
    for (var s = max(0, bestScale - 1); s <= min(scales.length - 1, bestScale + 1); s++) {
      final scaledRef = _scaled(reference, scales[s]);
      for (var y = bestY - _refine; y <= bestY + _refine; y++) {
        for (var x = bestX - _refine; x <= bestX + _refine; x++) {
          best = max(best, _correlation(card, scaledRef, x, y));
        }
      }
    }
    return best;
  }

  static GrayImage decode((int, int, String) reference) =>
      GrayImage(width: reference.$1, height: reference.$2, pixels: base64Decode(reference.$3));

  static GrayImage _scaled(GrayImage reference, double factor) =>
      reference.resize(max(1, (reference.width * factor).round()), max(1, (reference.height * factor).round()));

  double _correlation(GrayImage card, GrayImage reference, int left, int top) {
    if (left < 0 || top < 0 || left + reference.width > card.width || top + reference.height > card.height) {
      return double.negativeInfinity;
    }
    final n = reference.width * reference.height;
    var sumA = 0.0, sumB = 0.0, sumAA = 0.0, sumBB = 0.0, sumAB = 0.0;
    for (var y = 0; y < reference.height; y++) {
      final row = (top + y) * card.width + left;
      final refRow = y * reference.width;
      for (var x = 0; x < reference.width; x++) {
        final a = card.pixels[row + x].toDouble();
        final b = reference.pixels[refRow + x].toDouble();
        sumA += a;
        sumB += b;
        sumAA += a * a;
        sumBB += b * b;
        sumAB += a * b;
      }
    }
    final covariance = sumAB - sumA * sumB / n;
    final variance = (sumAA - sumA * sumA / n) * (sumBB - sumB * sumB / n);
    return variance <= 0 ? 0 : covariance / sqrt(variance);
  }

  /// Downscale factor of the coarse search.
  static const int _coarse = 3;
  static const int _refine = 3;
}
