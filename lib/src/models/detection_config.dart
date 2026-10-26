/// Thresholds used to decide whether the card is ready to be captured.
/// Defaults were tuned for ID-1 cards on mid-range phones; adjust them with
/// `showDebugInfo: true` if your devices or documents behave differently.
class DetectionConfig {
  const DetectionConfig({
    this.outerSearchBand = 0.10,
    this.innerSearchBand = 0.28,
    this.edgeTolerance = 0.07,
    this.maxSkew = 0.05,
    this.cornerSkip = 0.12,
    this.minEdgeCoverage = 0.7,
    this.minEdgeStrength = 40,
    this.minDetectedSides = 3,
    this.minBrightness = 55,
    this.glareLuma = 248,
    this.maxGlareRatio = 0.035,
    this.minSharpness = 100,
    this.requiredStableFrames = 4,
    this.maxEdgeJitter = 0.03,
  });

  /// How far outside the guide (fraction of guide size) an edge is searched.
  final double outerSearchBand;

  /// How far inside the guide an edge is searched (used to say "move closer").
  final double innerSearchBand;

  /// Max distance from the guide line for an edge to count as aligned.
  final double edgeTolerance;

  /// Max tilt of a detected edge (offset difference between its halves).
  final double maxSkew;

  /// Fraction ignored at each end of a side (rounded card corners).
  final double cornerSkip;
  final double minEdgeCoverage;
  final double minEdgeStrength;

  /// Sides (of 4) that must be found; 3 tolerates a background similar to the card.
  final int minDetectedSides;
  final double minBrightness;
  final int glareLuma;
  final double maxGlareRatio;

  /// Variance of the Laplacian inside the card.
  final double minSharpness;

  /// Consecutive ready frames before auto-capture.
  final int requiredStableFrames;

  /// Max per-side movement between frames while holding steady.
  final double maxEdgeJitter;
}
