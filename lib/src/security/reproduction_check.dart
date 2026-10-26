/// Result of looking for signs that the photo is of a screen or a printout
/// instead of the physical card.
class ReproductionCheck {
  const ReproductionCheck({required this.lumaScore, required this.chromaScore, required this.isReproduction});

  /// Median periodic-peak prominence in brightness (pixel grid moiré,
  /// halftone dots).
  final double lumaScore;

  /// Same in colour: screen sub-pixels (R/G/B stripes) show up here.
  final double chromaScore;

  /// Above the detector's thresholds: very likely a screen or a printout.
  final bool isReproduction;

  static const ReproductionCheck none = ReproductionCheck(lumaScore: 0, chromaScore: 0, isReproduction: false);
}
