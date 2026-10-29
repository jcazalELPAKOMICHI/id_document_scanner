import 'dart:math';
import 'dart:ui';

import '../constants/scanner_constants.dart';
import '../models/detection_config.dart';
import '../models/edge_measurement.dart';
import '../models/frame_analysis.dart';
import '../models/luma_frame.dart';
import '../models/scan_status.dart';
import 'luma_grid.dart';
import 'luma_statistics.dart';

/// Pure-Dart detector: decides whether an ID-1 card fills the guide frame,
/// using only the luminance plane (no ML, no native OCR).
///
/// The guide area (plus a search band around it) is resampled into a small
/// upright grid. On that grid each side of the guide is checked for a long,
/// straight luminance edge: a real card border produces the same gradient sign
/// along the whole side, while text and patterns cancel out. Brightness, glare
/// and sharpness (variance of the Laplacian) are measured inside the card.
class FrameAnalyzer {
  const FrameAnalyzer({this.config = const DetectionConfig(), this.gridWidth = ScannerConstants.analysisGridWidth});

  final DetectionConfig config;
  final int gridWidth;

  /// [guide] is in normalized upright image coordinates (0..1).
  FrameAnalysis analyze(LumaFrame frame, Rect guide) {
    final region = Rect.fromLTRB(
      guide.left - guide.width * config.outerSearchBand,
      guide.top - guide.height * config.outerSearchBand,
      guide.right + guide.width * config.outerSearchBand,
      guide.bottom + guide.height * config.outerSearchBand,
    );
    final regionAspect = (region.height * frame.uprightHeight) / (region.width * frame.uprightWidth);
    final grid = LumaGrid.sample(frame, region, gridWidth, max(_minGridSize, (gridWidth * regionAspect).round()));

    final guideInGrid = Rect.fromLTRB(
      (guide.left - region.left) / region.width * grid.width,
      (guide.top - region.top) / region.height * grid.height,
      (guide.right - region.left) / region.width * grid.width,
      (guide.bottom - region.top) / region.height * grid.height,
    );

    final edges = [
      _measureHorizontal(grid, guideInGrid, guideInGrid.top, inward: 1),
      _measureVertical(grid, guideInGrid, guideInGrid.right, inward: -1),
      _measureHorizontal(grid, guideInGrid, guideInGrid.bottom, inward: -1),
      _measureVertical(grid, guideInGrid, guideInGrid.left, inward: 1),
    ];

    final interior = guideInGrid.deflate(min(guideInGrid.width, guideInGrid.height) * _interiorInset);
    final stats = grid.statistics(interior, config.glareLuma);
    final sharpness = _sharpness(frame, guide);

    return FrameAnalysis(
      status: _statusFor(edges, stats, sharpness),
      edges: edges,
      brightness: stats.mean,
      sharpness: sharpness,
      glareRatio: stats.glareRatio,
    );
  }

  /// Variance of the Laplacian on a central patch sampled at (up to) native
  /// resolution: the coarse grid used for edges hides motion and focus blur.
  double _sharpness(LumaFrame frame, Rect guide) {
    final patch = Rect.fromCenter(
      center: guide.center,
      width: guide.width * _sharpnessPatch,
      height: guide.height * _sharpnessPatch,
    );
    final pixelWidth = (patch.width * frame.uprightWidth).round();
    final pixelHeight = (patch.height * frame.uprightHeight).round();
    final downscale = max(1.0, pixelWidth / _maxSharpnessPatchWidth);
    final grid = LumaGrid.sample(
      frame,
      patch,
      max(_minGridSize, (pixelWidth / downscale).round()),
      max(_minGridSize, (pixelHeight / downscale).round()),
      boxFilter: false,
    );
    return grid
        .statistics(Rect.fromLTWH(0, 0, grid.width.toDouble(), grid.height.toDouble()), config.glareLuma)
        .sharpness;
  }

  ScanStatus _statusFor(List<EdgeMeasurement> edges, LumaStatistics stats, double sharpness) {
    if (stats.mean < config.minBrightness) return .tooDark;
    final detected = edges.where((edge) => edge.detected).toList();
    if (detected.length < config.minDetectedSides) return .searching;
    if (detected.any((edge) => edge.skew > config.maxSkew)) return .notAligned;
    final aligned = detected.where((edge) => edge.offset.abs() <= config.edgeTolerance).length;
    if (aligned < config.minDetectedSides) {
      // On average the edges sit inside the guide: the card looks small.
      final meanOffset = detected.map((edge) => edge.offset).reduce((a, b) => a + b) / detected.length;
      return meanOffset > config.edgeTolerance * _tooFarFraction ? .tooFar : .notAligned;
    }
    if (stats.glareRatio > config.maxGlareRatio) return .glare;
    if (sharpness < config.minSharpness) return .blurry;
    return .ready;
  }

  EdgeMeasurement _measureHorizontal(LumaGrid grid, Rect guide, double lineY, {required int inward}) {
    final outer = config.outerSearchBand * guide.height;
    final inner = config.innerSearchBand * guide.height;
    final skip = guide.width * config.cornerSkip;
    return _measure(
      lineStart: (guide.left + skip).round(),
      lineEnd: (guide.right - skip).round(),
      searchFrom: (lineY - (inward > 0 ? outer : inner)).round(),
      searchTo: (lineY + (inward > 0 ? inner : outer)).round(),
      searchLimit: grid.height,
      gradient: (along, across) => grid.at(along, across + 1) - grid.at(along, across - 1),
      offsetOf: (across) => (across - lineY) * inward / guide.height,
    );
  }

  EdgeMeasurement _measureVertical(LumaGrid grid, Rect guide, double lineX, {required int inward}) {
    final outer = config.outerSearchBand * guide.width;
    final inner = config.innerSearchBand * guide.width;
    final skip = guide.height * config.cornerSkip;
    return _measure(
      lineStart: (guide.top + skip).round(),
      lineEnd: (guide.bottom - skip).round(),
      searchFrom: (lineX - (inward > 0 ? outer : inner)).round(),
      searchTo: (lineX + (inward > 0 ? inner : outer)).round(),
      searchLimit: grid.width,
      gradient: (along, across) => grid.at(across + 1, along) - grid.at(across - 1, along),
      offsetOf: (across) => (across - lineX) * inward / guide.width,
    );
  }

  /// Projects the signed gradient along slightly tilted lines across the
  /// search band, so a card held a few degrees off still shows a straight,
  /// continuous edge. The card border is the outermost strong line that runs
  /// along most of the side: text and bands printed inside the card can be
  /// stronger, so the absolute maximum is not used.
  EdgeMeasurement _measure({
    required int lineStart,
    required int lineEnd,
    required int searchFrom,
    required int searchTo,
    required int searchLimit,
    required int Function(int along, int across) gradient,
    required double Function(double across) offsetOf,
  }) {
    final from = max(1, searchFrom);
    final to = min(searchLimit - 2, searchTo);
    final length = lineEnd - lineStart;
    if (to <= from || length <= 0) return EdgeMeasurement.none;

    final middle = (lineStart + lineEnd) / 2;
    final lines = _strongestLines(from, to, lineStart, lineEnd, middle, gradient);
    final strongest = lines.map((line) => line.$3.abs()).reduce(max);
    final outwardFirst = lines.where((line) => line.$3.abs() >= strongest * _outermostFraction).toList()
      ..sort((a, b) => offsetOf(a.$1.toDouble()).compareTo(offsetOf(b.$1.toDouble())));

    var measured = EdgeMeasurement.none;
    for (final (position, slope, value) in outwardFirst) {
      double lineAt(int along) => position + slope * (along - middle);
      final polarity = value.sign.toInt();
      final hitThreshold = max(config.minEdgeStrength, value.abs() * _hitThresholdFactor);
      var hits = 0;
      for (var along = lineStart; along < lineEnd; along++) {
        final center = lineAt(along).round();
        var best = 0;
        for (var across = max(from, center - _lineSlack); across <= min(to, center + _lineSlack); across++) {
          best = max(best, gradient(along, across) * polarity);
        }
        if (best >= hitThreshold) hits++;
      }

      final coverage = hits / length;
      final strength = value.abs();
      // Tilt: where the edge sits at the middle of the first third versus
      // the middle of the last third of the side.
      final third = length / _skewSegments;
      final skew = (offsetOf(lineAt((lineStart + third / 2).round())) - offsetOf(lineAt((lineEnd - third / 2).round())))
          .abs();
      final detected = coverage >= config.minEdgeCoverage && strength >= config.minEdgeStrength;
      if (detected || measured == EdgeMeasurement.none || strength > measured.strength) {
        measured = EdgeMeasurement(
          detected: detected,
          coverage: coverage,
          strength: strength,
          offset: offsetOf(position.toDouble()),
          skew: skew,
        );
      }
      if (detected) break;
    }
    return measured;
  }

  /// For every position across the band, the line through it (slope in grid
  /// cells per cell along the side) whose mean signed gradient along
  /// [lineStart]..[lineEnd] is strongest: (position at [middle], slope, mean).
  List<(int, double, double)> _strongestLines(
    int from,
    int to,
    int lineStart,
    int lineEnd,
    double middle,
    int Function(int along, int across) gradient,
  ) {
    final lines = <(int, double, double)>[];
    for (var across = from; across <= to; across++) {
      var bestSlope = 0.0;
      var bestValue = 0.0;
      for (var step = -_slopeSteps; step <= _slopeSteps; step++) {
        final slope = step * _maxSlope / _slopeSteps;
        var sum = 0;
        var count = 0;
        for (var along = lineStart; along < lineEnd; along++) {
          final position = (across + slope * (along - middle)).round();
          if (position < from || position > to) continue;
          sum += gradient(along, position);
          count++;
        }
        // A line that leaves the band for most of the side is not an edge.
        if (count < (lineEnd - lineStart) * config.minEdgeCoverage) continue;
        final mean = sum / (lineEnd - lineStart);
        if (mean.abs() > bestValue.abs()) {
          bestValue = mean;
          bestSlope = slope;
        }
      }
      lines.add((across, bestSlope, bestValue));
    }
    return lines;
  }

  static const int _minGridSize = 16;
  static const int _lineSlack = 2;
  static const double _hitThresholdFactor = 0.5;
  static const double _outermostFraction = 0.5;
  static const double _tooFarFraction = 0.5;
  static const double _interiorInset = 0.1;
  static const int _skewSegments = 3;

  /// Steepest edge searched (about 9°): steeper cards are reported as tilted.
  static const double _maxSlope = 0.16;
  static const int _slopeSteps = 8;
  static const double _sharpnessPatch = 0.5;
  static const int _maxSharpnessPatchWidth = 320;
}
