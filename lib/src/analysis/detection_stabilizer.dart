import '../models/detection_config.dart';
import '../models/frame_analysis.dart';

/// Requires several consecutive ready frames with the card barely moving
/// before the scanner auto-captures, so the photo is not taken mid-motion.
class DetectionStabilizer {
  DetectionStabilizer({required this.config});

  final DetectionConfig config;

  int stableFrames = 0;
  FrameAnalysis? previous;

  bool get isStable => stableFrames >= config.requiredStableFrames;

  /// Feeds a new frame and returns whether the card is now stable.
  bool add(FrameAnalysis analysis) {
    if (analysis.status != .ready) {
      reset();
      return false;
    }
    final last = previous;
    stableFrames = last == null || _moved(last, analysis) ? 1 : stableFrames + 1;
    previous = analysis;
    return isStable;
  }

  void reset() {
    stableFrames = 0;
    previous = null;
  }

  bool _moved(FrameAnalysis a, FrameAnalysis b) => Iterable.generate(a.edges.length).any((side) {
    final before = a.edges[side];
    final after = b.edges[side];
    return before.detected && after.detected && (before.offset - after.offset).abs() > config.maxEdgeJitter;
  });
}
