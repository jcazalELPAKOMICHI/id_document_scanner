/// A candidate character for one MRZ position and how well it matched.
class GlyphMatch {
  const GlyphMatch({required this.character, required this.score});

  final String character;
  final double score;
}
