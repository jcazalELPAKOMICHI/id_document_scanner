import 'dart:math';
import 'dart:ui';

/// Straight line `across = slope * along + intercept`, fitted to edge points
/// with outlier rejection (text or patterns near the card border).
class FittedLine {
  const FittedLine({required this.slope, required this.intercept, required this.inliers});

  final double slope;
  final double intercept;

  /// How many of the points support the line.
  final int inliers;

  double at(double along) => slope * along + intercept;

  /// Least squares fit of points (dx = along, dy = across), refitted after
  /// dropping points far from the first estimate. Null with too few points.
  static FittedLine? fit(List<Offset> points, {required double minResidual, required double madFactor}) {
    final first = _leastSquares(points);
    if (first == null) return null;
    final residuals = points.map((point) => (point.dy - first.at(point.dx)).abs()).toList();
    final sorted = [...residuals]..sort();
    final limit = max(minResidual, sorted[sorted.length ~/ 2] * madFactor);
    final inliers = [
      for (var i = 0; i < points.length; i++)
        if (residuals[i] <= limit) points[i],
    ];
    return _leastSquares(inliers);
  }

  static FittedLine? _leastSquares(List<Offset> points) {
    if (points.length < _minPoints) return null;
    final n = points.length;
    final meanX = points.map((p) => p.dx).reduce((a, b) => a + b) / n;
    final meanY = points.map((p) => p.dy).reduce((a, b) => a + b) / n;
    var covariance = 0.0;
    var variance = 0.0;
    for (final point in points) {
      covariance += (point.dx - meanX) * (point.dy - meanY);
      variance += (point.dx - meanX) * (point.dx - meanX);
    }
    if (variance == 0) return null;
    final slope = covariance / variance;
    return FittedLine(slope: slope, intercept: meanY - slope * meanX, inliers: n);
  }

  static const int _minPoints = 4;
}
