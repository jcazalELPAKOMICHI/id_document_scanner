/// How well one side of the card lines up with the guide frame.
class EdgeMeasurement {
  const EdgeMeasurement({
    required this.detected,
    required this.coverage,
    required this.strength,
    required this.offset,
    this.skew = 0,
  });

  static const EdgeMeasurement none = EdgeMeasurement(detected: false, coverage: 0, strength: 0, offset: 0);

  /// Whether a straight, strong enough edge was found near this side.
  final bool detected;

  /// Fraction (0..1) of the side where the edge was found.
  final double coverage;

  /// Mean luminance step across the edge.
  final double strength;

  /// Distance from the guide line as a fraction of the guide size;
  /// positive = inside the guide (card smaller than the frame).
  final double offset;

  /// Difference in [offset] between both halves of the side: how tilted the
  /// card edge is relative to the guide.
  final double skew;
}
