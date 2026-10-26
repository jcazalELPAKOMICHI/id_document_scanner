import 'dart:convert';
import 'dart:math';
import 'dart:ui';

import '../ocr/gray_image.dart';

/// Finds how well a reference crop appears around its expected place in a
/// card image (normalized cross correlation, coarse-to-fine search), so
/// lighting and contrast changes do not matter, only the printed shapes.
class HeaderMatcher {
  const HeaderMatcher({this.searchMargin = 0.05});

  /// Search distance around the expected place, as a fraction of the card.
  final double searchMargin;

  /// Best correlation (-1..1) of [reference] around [expected] in [card].
  double match(GrayImage card, GrayImage reference, Rect expected) {
    final dx = (card.width * searchMargin).round();
    final dy = (card.height * searchMargin).round();
    final originX = (expected.left * card.width).round();
    final originY = (expected.top * card.height).round();

    // Coarse search at half resolution, then refine around the best spot.
    final coarseCard = card.resize(card.width ~/ 2, card.height ~/ 2);
    final coarseRef = reference.resize(max(1, reference.width ~/ 2), max(1, reference.height ~/ 2));
    var best = double.negativeInfinity;
    var bestX = originX;
    var bestY = originY;
    for (var y = (originY - dy) ~/ 2; y <= (originY + dy) ~/ 2; y++) {
      for (var x = (originX - dx) ~/ 2; x <= (originX + dx) ~/ 2; x++) {
        final score = _correlation(coarseCard, coarseRef, x, y);
        if (score > best) {
          best = score;
          bestX = x * 2;
          bestY = y * 2;
        }
      }
    }
    for (var y = bestY - _refine; y <= bestY + _refine; y++) {
      for (var x = bestX - _refine; x <= bestX + _refine; x++) {
        best = max(best, _correlation(card, reference, x, y));
      }
    }
    return best;
  }

  static GrayImage decode((int, int, String) reference) =>
      GrayImage(width: reference.$1, height: reference.$2, pixels: base64Decode(reference.$3));

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

  static const int _refine = 2;
}
