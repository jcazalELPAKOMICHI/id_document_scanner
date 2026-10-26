import 'dart:typed_data';

import '../camera/document_cropper.dart';
import '../templates/document_template.dart';
import '../security/reproduction_check.dart';
import '../verification/document_verification.dart';
import 'card_corners.dart';
import 'document_field.dart';
import 'document_side.dart';
import 'document_type.dart';
import 'frame_analysis.dart';

/// Photo taken once the card was aligned and stable.
class DocumentCapture {
  const DocumentCapture({
    required this.documentType,
    required this.side,
    required this.photoPath,
    required this.cardImage,
    required this.corners,
    required this.analysis,
    this.verification,
    this.reproduction = ReproductionCheck.none,
  });

  final DocumentType documentType;
  final DocumentSide side;

  /// Full-resolution photo as saved by the camera.
  final String photoPath;

  /// JPEG with only the card, straightened to the ID-1 aspect ratio when
  /// its borders were found ([isPreciseCrop]). This is what to upload.
  final Uint8List cardImage;

  /// Card corners in the original photo (normalized), null if not found.
  final CardCorners? corners;

  /// Analysis of the last frame before capture (quality metrics).
  final FrameAnalysis analysis;

  /// Paraguayan ID check (front header / back MRZ), including the MRZ data
  /// read from the back. Null when verification is disabled.
  final DocumentVerification? verification;

  /// Screen / printed-copy check of the photo.
  final ReproductionCheck reproduction;

  bool get isPreciseCrop => corners != null;

  DocumentCapture withVerification(DocumentVerification value) => DocumentCapture(
    documentType: documentType,
    side: side,
    photoPath: photoPath,
    cardImage: cardImage,
    corners: corners,
    analysis: analysis,
    verification: value,
    reproduction: reproduction,
  );

  DocumentTemplate get template => DocumentTemplate.of(documentType, side);

  /// JPEG crops of every field in [template], ready to feed an OCR step.
  Future<Map<DocumentField, Uint8List>> cropFields() => DocumentCropper.cropFields(cardImage, template);
}
