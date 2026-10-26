import 'dart:typed_data';

import '../security/reproduction_check.dart';
import 'card_corners.dart';

/// Result of cropping the card out of a photo.
class CroppedCard {
  const CroppedCard({required this.image, required this.corners, this.reproduction = ReproductionCheck.none});

  /// JPEG with only the card: perspective-corrected to the ID-1 aspect ratio
  /// when [corners] were found, otherwise an axis-aligned crop.
  final Uint8List image;

  /// Card corners found in the photo (normalized), null if not found.
  final CardCorners? corners;

  /// Screen / printout check, measured on the card before JPEG encoding.
  final ReproductionCheck reproduction;

  bool get isPrecise => corners != null;
}
