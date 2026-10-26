import 'dart:math';
import 'dart:ui';

import '../constants/scanner_constants.dart';
import '../models/card_corners.dart';
import '../models/luma_frame.dart';
import 'fitted_line.dart';

/// Finds the exact card outline in a full photo, starting from where the
/// live analysis saw it. Each side is sampled across a narrow band, the
/// strongest consistent edge is kept per sample and a straight line is fitted
/// through them; the 4 line intersections are the card corners (so a slightly
/// tilted or perspective-distorted card is still cropped exactly).
class CardEdgeRefiner {
  const CardEdgeRefiner({
    this.searchBand = 0.10,
    this.samplesPerSide = 56,
    this.minInlierRatio = 0.45,
    this.aspectTolerance = 0.12,
    this.sizeTolerance = 0.35,
  });

  /// Search distance around the expected side, as a fraction of the card size.
  final double searchBand;
  final int samplesPerSide;
  final double minInlierRatio;

  /// Allowed deviation from the ID-1 aspect ratio.
  final double aspectTolerance;

  /// Allowed size change versus the expected rect.
  final double sizeTolerance;

  /// [expected] is the approximate card rect normalized to [frame] (upright).
  CardCorners? refine(LumaFrame frame, Rect expected) {
    final width = frame.uprightWidth.toDouble();
    final height = frame.uprightHeight.toDouble();
    final rect = Rect.fromLTRB(
      expected.left * width,
      expected.top * height,
      expected.right * width,
      expected.bottom * height,
    );
    int luma(double x, double y) => frame.sampleUpright(x / width, y / height);

    final horizontalBand = rect.height * searchBand;
    final verticalBand = rect.width * searchBand;
    final top = _side(
      luma,
      from: rect.left,
      to: rect.right,
      line: rect.top,
      band: horizontalBand,
      horizontal: true,
      outward: -1,
    );
    final bottom = _side(
      luma,
      from: rect.left,
      to: rect.right,
      line: rect.bottom,
      band: horizontalBand,
      horizontal: true,
      outward: 1,
    );
    final left = _side(
      luma,
      from: rect.top,
      to: rect.bottom,
      line: rect.left,
      band: verticalBand,
      horizontal: false,
      outward: -1,
    );
    final right = _side(
      luma,
      from: rect.top,
      to: rect.bottom,
      line: rect.right,
      band: verticalBand,
      horizontal: false,
      outward: 1,
    );
    if (top == null || bottom == null || left == null || right == null) return null;

    final corners = CardCorners(
      topLeft: _intersect(top, left),
      topRight: _intersect(top, right),
      bottomRight: _intersect(bottom, right),
      bottomLeft: _intersect(bottom, left),
    );
    if (!_plausible(corners, rect)) return null;
    return CardCorners(
      topLeft: corners.topLeft.scale(1 / width, 1 / height),
      topRight: corners.topRight.scale(1 / width, 1 / height),
      bottomRight: corners.bottomRight.scale(1 / width, 1 / height),
      bottomLeft: corners.bottomLeft.scale(1 / width, 1 / height),
    );
  }

  /// Fits one side. For horizontal sides points are (x, y); for vertical
  /// sides (y, x), so every line is `across = slope * along + intercept`.
  FittedLine? _side(
    int Function(double x, double y) luma, {
    required double from,
    required double to,
    required double line,
    required double band,
    required bool horizontal,
    required int outward,
  }) {
    int sample(double along, double across) => horizontal ? luma(along, across) : luma(across, along);
    final step = max(1.0, band / _stepsPerBand);
    final margin = (to - from) * _cornerMargin;
    final spacing = (to - from - 2 * margin) / (samplesPerSide - 1);

    final candidates = <(Offset, int)>[];
    for (var i = 0; i < samplesPerSide; i++) {
      final along = from + margin + i * spacing;
      // Gradients across the band, from outside the card inwards. The card
      // border is the outermost strong edge: text printed close to the
      // border can be even stronger, so the absolute maximum is not used.
      final gradients = <(double, int)>[];
      var strongest = 0;
      for (var k = 0; k * step <= 2 * band; k++) {
        final across = line + outward * (band - k * step);
        var gradient = 0;
        for (var j = -_smoothing; j <= _smoothing; j++) {
          gradient += sample(along + j * step, across + step) - sample(along + j * step, across - step);
        }
        gradients.add((across, gradient));
        strongest = max(strongest, gradient.abs());
      }
      var best = 0;
      var bestAcross = line;
      for (final (across, gradient) in gradients) {
        if (gradient.abs() >= strongest * _outermostFraction) {
          // Refine to the local peak of this first strong edge.
          best = gradient;
          bestAcross = across;
          for (final (nextAcross, nextGradient)
              in gradients.skipWhile((entry) => entry.$1 != across).skip(1).take(_peakSearch)) {
            if (nextGradient.sign == gradient.sign && nextGradient.abs() > best.abs()) {
              best = nextGradient;
              bestAcross = nextAcross;
            }
          }
          break;
        }
      }
      if (best.abs() >= _minGradient * (2 * _smoothing + 1)) candidates.add((Offset(along, bestAcross), best.sign));
    }

    // Keep the dominant polarity: the card border is either lighter or darker
    // than the background along the whole side.
    final positives = candidates.where((candidate) => candidate.$2 > 0).length;
    final polarity = positives * 2 >= candidates.length ? 1 : -1;
    final points = candidates.where((candidate) => candidate.$2 == polarity).map((candidate) => candidate.$1).toList();
    final fitted = FittedLine.fit(points, minResidual: step * _minResidualSteps, madFactor: _madFactor);
    if (fitted == null || fitted.inliers < samplesPerSide * minInlierRatio) return null;
    return fitted;
  }

  /// Intersection of a horizontal side (y = a x + b) and a vertical one (x = c y + d).
  Offset _intersect(FittedLine horizontal, FittedLine vertical) {
    final x = (vertical.slope * horizontal.intercept + vertical.intercept) / (1 - horizontal.slope * vertical.slope);
    return Offset(x, horizontal.at(x));
  }

  bool _plausible(CardCorners corners, Rect expected) {
    final aspect = corners.width / corners.height;
    final aspectError = (aspect - ScannerConstants.idCardAspectRatio).abs() / ScannerConstants.idCardAspectRatio;
    final sizeChange = (corners.width / expected.width - 1).abs();
    return aspectError <= aspectTolerance && sizeChange <= sizeTolerance;
  }

  static const double _stepsPerBand = 40;
  static const double _cornerMargin = 0.12;
  static const int _smoothing = 2;
  static const int _minGradient = 12;
  static const double _minResidualSteps = 1.5;
  static const double _madFactor = 3;
  static const double _outermostFraction = 0.5;
  static const int _peakSearch = 3;
}
