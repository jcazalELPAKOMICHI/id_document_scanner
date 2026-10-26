import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'glyph_features.dart';
import 'glyph_match.dart';
import 'glyph_template.dart';
import 'ocrb_glyphs.g.dart';

/// OCR-B reference glyphs (the MRZ font) and the classifier that compares a
/// character picture against all of them.
class OcrbGlyphBank {
  OcrbGlyphBank._(this.templates);

  static final OcrbGlyphBank instance = OcrbGlyphBank._(_load());

  final List<GlyphTemplate> templates;

  /// Best candidates for [glyph], best first, one per character.
  List<GlyphMatch> classify(GlyphFeatures glyph, {int limit = _defaultCandidates}) {
    final best = <String, double>{};
    for (final template in templates) {
      final features = template.features;
      final score =
          glyph.correlation(features) -
          (glyph.heightRatio - features.heightRatio).abs() * _heightPenalty -
          (glyph.aspect - features.aspect).abs() * _aspectPenalty;
      if (score > (best[template.character] ?? double.negativeInfinity)) best[template.character] = score;
    }
    final matches = best.entries.map((entry) => GlyphMatch(character: entry.key, score: entry.value)).toList()
      ..sort((a, b) => b.score.compareTo(a.score));
    _resolveBottomPair(glyph, matches);
    return matches.take(limit).toList();
  }

  /// E/F (and L/I) differ only in the bottom bar, which pale or blurred print
  /// weakens: when they are the top two, decide by the bottom-right ink.
  void _resolveBottomPair(GlyphFeatures glyph, List<GlyphMatch> matches) {
    if (matches.length < 2) return;
    final first = matches[0];
    final second = matches[1];
    if (_bottomPairs[first.character] != second.character || first.score - second.score > _pairMargin) return;
    double distance(String character) => templates
        .where((template) => template.character == character)
        .map((template) => (template.features.bottomInk - glyph.bottomInk).abs())
        .reduce(min);
    if (distance(second.character) < distance(first.character)) {
      matches[0] = GlyphMatch(character: second.character, score: first.score);
      matches[1] = GlyphMatch(character: first.character, score: second.score);
    }
  }

  static List<GlyphTemplate> _load() => ocrbGlyphTemplates.map((entry) {
    final (character, encoded, heightRatio, aspect) = entry;
    final bytes = base64Decode(encoded);
    final values = Float32List(bytes.length);
    for (var i = 0; i < bytes.length; i++) {
      values[i] = bytes[i] / _maxByte;
    }
    return GlyphTemplate(
      character: character,
      features: GlyphFeatures(
        bottomInk: GlyphFeatures.bottomInkOf(values),
        values: GlyphFeatures.normalize(values),
        heightRatio: heightRatio,
        aspect: aspect,
      ),
    );
  }).toList();

  static const int _defaultCandidates = 3;
  static const double _heightPenalty = 1.2;
  static const double _aspectPenalty = 0.35;
  static const double _pairMargin = 0.12;
  static const Map<String, String> _bottomPairs = {'E': 'F', 'F': 'E', 'L': 'I', 'I': 'L'};
  static const double _maxByte = 255;
}
