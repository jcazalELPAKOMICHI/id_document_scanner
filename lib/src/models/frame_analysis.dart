import 'dart:ui';

import 'edge_measurement.dart';
import 'scan_status.dart';

/// Result of analysing one frame. Exposed so integrators can calibrate
/// [DetectionConfig] on real devices (see `showDebugInfo`).
class FrameAnalysis {
  const FrameAnalysis({
    required this.status,
    required this.edges,
    required this.brightness,
    required this.sharpness,
    required this.glareRatio,
  });

  static const FrameAnalysis empty = FrameAnalysis(
    status: .searching,
    edges: [EdgeMeasurement.none, EdgeMeasurement.none, EdgeMeasurement.none, EdgeMeasurement.none],
    brightness: 0,
    sharpness: 0,
    glareRatio: 0,
  );

  final ScanStatus status;

  /// Top, right, bottom, left.
  final List<EdgeMeasurement> edges;
  final double brightness;
  final double sharpness;
  final double glareRatio;

  int get detectedSides => edges.where((edge) => edge.detected).length;

  /// The guide rect corrected with the measured edges, i.e. where the card
  /// actually is. Sides that were not detected keep the guide position.
  Rect cardRect(Rect guide) {
    double offsetOf(EdgeMeasurement edge) => edge.detected ? edge.offset : 0;
    return Rect.fromLTRB(
      guide.left + offsetOf(edges[3]) * guide.width,
      guide.top + offsetOf(edges[0]) * guide.height,
      guide.right - offsetOf(edges[1]) * guide.width,
      guide.bottom - offsetOf(edges[2]) * guide.height,
    );
  }

  @override
  String toString() =>
      '${status.name} | edges ${edges.map((e) => '${e.detected ? '✓' : '·'}${(e.coverage * 100).round()}%@${(e.offset * 100).round()}/${(e.skew * 100).round()}~${e.strength.round()}').join(' ')}'
      ' | lum ${brightness.round()} | sharp ${sharpness.round()} | glare ${(glareRatio * 100).toStringAsFixed(1)}%';
}
