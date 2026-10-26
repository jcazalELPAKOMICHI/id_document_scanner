import '../mrz/mrz_data.dart';
import 'glyph_match.dart';

/// Text read from the MRZ of a card image.
class MrzReading {
  const MrzReading({required this.lines, required this.candidates, required this.mrz, required this.confidence});

  /// The 3 lines as read (after check digit corrections when they helped).
  final List<String> lines;

  /// Best candidates per position, per line.
  final List<List<List<GlyphMatch>>> candidates;

  /// Parsed data; check `mrz.isValid` for the check digits.
  final MrzData? mrz;

  /// Mean correlation of the chosen characters (0..1).
  final double confidence;

  bool get isValid => mrz?.isValid ?? false;
}
