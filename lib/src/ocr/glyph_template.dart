import 'glyph_features.dart';

/// One reference rendering of an OCR-B character.
class GlyphTemplate {
  const GlyphTemplate({required this.character, required this.features});

  final String character;
  final GlyphFeatures features;
}
