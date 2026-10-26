import 'dart:ui';

import '../constants/scanner_constants.dart';

/// Fixed printed areas used to recognise a card's front, normalized to the
/// card. They never change between people, so they can be compared directly.
abstract final class HeaderReferenceRegions {
  /// Card size the references are stored (and compared) at.
  static const int cardWidth = 600;
  static final int cardHeight = (cardWidth / ScannerConstants.idCardAspectRatio).round();

  /// Current design: "REPUBLICA DEL PARAGUAY / Cédula de Identidad Civil"
  /// and the coat of arms.
  static const List<Rect> paraguayCurrentFront = [
    Rect.fromLTWH(0.265, 0.045, 0.57, 0.135),
    Rect.fromLTWH(0.120, 0.030, 0.115, 0.175),
  ];

  /// Previous design: the same title on a pink band, the coat of arms on the
  /// left (no personal data above 20 % of the card height).
  static const List<Rect> paraguayLegacyFront = [
    Rect.fromLTWH(0.195, 0.055, 0.560, 0.130),
    Rect.fromLTWH(0.030, 0.045, 0.120, 0.150),
  ];

  /// Part of the card covered by the stored legacy header strip.
  static const double legacyHeaderHeight = 0.2;
}
