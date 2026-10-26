/// Brightness, glare and sharpness measured inside the card.
class LumaStatistics {
  const LumaStatistics({required this.mean, required this.glareRatio, required this.sharpness});

  final double mean;
  final double glareRatio;
  final double sharpness;
}
