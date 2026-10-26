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
      final inward = detected.where((edge) => edge.offset > config.edgeTolerance).length;
      return inward >= config.minDetectedSides ? .tooFar : .notAligned;
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

  /// Projects the signed gradient of every position in the search band along
  /// the side and keeps the strongest line; coverage is how much of the side
  /// actually shows that edge (with the same polarity) near that line.
  EdgeMeasurement _measure({
    required int lineStart,
    required int lineEnd,
    required int searchFrom,
    required int searchTo,
    required int searchLimit,
    required int Function(int along, int across) gradient,
    required double Function(int across) offsetOf,
  }) {
    final from = max(1, searchFrom);
    final to = min(searchLimit - 2, searchTo);
    final length = lineEnd - lineStart;
    if (to <= from || length <= 0) return EdgeMeasurement.none;

    final (peak, peakValue) = _strongestLine(from, to, lineStart, lineEnd, gradient);

    final polarity = peakValue.sign.toInt();
    final hitThreshold = max(config.minEdgeStrength, peakValue.abs() * _hitThresholdFactor);
    var hits = 0;
    for (var along = lineStart; along < lineEnd; along++) {
      var best = 0;
      for (var across = max(from, peak - _lineSlack); across <= min(to, peak + _lineSlack); across++) {
        best = max(best, gradient(along, across) * polarity);
      }
      if (best >= hitThreshold) hits++;
    }

    final coverage = hits / length;
    final strength = peakValue.abs();

    return EdgeMeasurement(
      detected: coverage >= config.minEdgeCoverage && strength >= config.minEdgeStrength,
      coverage: coverage,
      strength: strength,
      offset: offsetOf(peak),
      skew: _skew(
        from: from,
        to: to,
        peak: peak,
        threshold: hitThreshold,
        lineStart: lineStart,
        lineEnd: lineEnd,
        polarity: polarity,
        gradient: gradient,
        offsetOf: offsetOf,
      ),
    );
  }

  /// Tilt of the edge: where it sits in the first third of the side versus
  /// the last third. Per position, takes the strong gradient closest to the
  /// side's main line, so text further inside the card is ignored.
  double _skew({
    required int from,
    required int to,
    required int peak,
    required double threshold,
    required int lineStart,
    required int lineEnd,
    required int polarity,
    required int Function(int along, int across) gradient,
    required double Function(int across) offsetOf,
  }) {
    int? nearestEdge(int along) {
      for (var distance = 0; distance <= max(peak - from, to - peak); distance++) {
        for (final across in [peak - distance, peak + distance]) {
          if (across >= from && across <= to && gradient(along, across) * polarity >= threshold) return across;
        }
      }
      return null;
    }

    double? medianOf(int start, int end) {
      final positions = List.generate(end - start, (i) => nearestEdge(start + i)).nonNulls.toList()..sort();
      return positions.isEmpty ? null : offsetOf(positions[positions.length ~/ 2]);
    }

    final third = (lineEnd - lineStart) ~/ _skewSegments;
    if (third == 0 || polarity == 0) return 0;
    final first = medianOf(lineStart, lineStart + third);
    final last = medianOf(lineEnd - third, lineEnd);
    return first == null || last == null ? 0 : (first - last).abs();
  }

  /// Position across the band whose mean signed gradient along
  /// [lineStart]..[lineEnd] is strongest, with that mean.
  (int, double) _strongestLine(
    int from,
    int to,
    int lineStart,
    int lineEnd,
    int Function(int along, int across) gradient,
  ) {
    var peak = from;
    var peakValue = 0.0;
    for (var across = from; across <= to; across++) {
      var sum = 0;
      for (var along = lineStart; along < lineEnd; along++) {
        sum += gradient(along, across);
      }
      final mean = sum / (lineEnd - lineStart);
      if (mean.abs() > peakValue.abs()) {
        peakValue = mean;
        peak = across;
      }
    }
    return (peak, peakValue);
  }

  static const int _minGridSize = 16;
  static const int _lineSlack = 2;
  static const double _hitThresholdFactor = 0.5;
  static const double _interiorInset = 0.1;
  static const int _skewSegments = 3;
  static const double _sharpnessPatch = 0.5;
  static const int _maxSharpnessPatchWidth = 320;
}
