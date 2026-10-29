import 'dart:ui';

import 'document_template.dart';

/// Field layouts of the Paraguayan "Cédula de Identidad Civil".
///
/// Measured on public sample images; each box has a little margin so small
/// misalignments still contain the whole value. Calibrate with real captures
/// (`DocumentCapture.cropFields`) before relying on them for OCR.
abstract final class ParaguayIdTemplates {
  /// Current design: photo on the left, labelled fields in two columns.
  static const DocumentTemplate currentFront = DocumentTemplate(
    type: .paraguayIdCurrent,
    side: .front,
    fields: {
      .surnames: Rect.fromLTWH(0.33, 0.265, 0.38, 0.07),
      .givenNames: Rect.fromLTWH(0.33, 0.400, 0.38, 0.07),
      .expiryDate: Rect.fromLTWH(0.73, 0.265, 0.19, 0.07),
      .organDonor: Rect.fromLTWH(0.77, 0.400, 0.08, 0.07),
      .birthDate: Rect.fromLTWH(0.33, 0.780, 0.17, 0.07),
      .sex: Rect.fromLTWH(0.56, 0.780, 0.18, 0.07),
      .birthPlace: Rect.fromLTWH(0.33, 0.875, 0.32, 0.07),
      .documentNumber: Rect.fromLTWH(0.075, 0.825, 0.17, 0.075),
      .photo: Rect.fromLTWH(0.035, 0.245, 0.28, 0.540),
    },
  );

  /// Previous design: photo on the right, surnames and names stacked under a
  /// single label, document number below the photo. Measured on a
  /// full-resolution photo of a real card (layout only).
  static const DocumentTemplate legacyFront = DocumentTemplate(
    type: .paraguayIdLegacy,
    side: .front,
    fields: {
      .fullName: Rect.fromLTWH(0.065, 0.245, 0.40, 0.12),
      .birthDate: Rect.fromLTWH(0.065, 0.405, 0.18, 0.07),
      .sex: Rect.fromLTWH(0.48, 0.405, 0.18, 0.07),
      .birthPlace: Rect.fromLTWH(0.065, 0.520, 0.32, 0.07),
      .expiryDate: Rect.fromLTWH(0.065, 0.635, 0.18, 0.07),
      .documentNumber: Rect.fromLTWH(0.715, 0.745, 0.185, 0.075),
      .photo: Rect.fromLTWH(0.67, 0.200, 0.29, 0.560),
    },
  );

  /// Current design, back: chip on the left, barcode on the right and a TD1
  /// MRZ (document code "IN") across the bottom third.
  static const DocumentTemplate currentBack = DocumentTemplate(
    type: .paraguayIdCurrent,
    side: .back,
    fields: {
      .civilStatus: Rect.fromLTWH(0.155, 0.095, 0.10, 0.075),
      .nationality: Rect.fromLTWH(0.130, 0.185, 0.21, 0.075),
      .issueDate: Rect.fromLTWH(0.460, 0.100, 0.165, 0.070),
      .identificationCode: Rect.fromLTWH(0.305, 0.355, 0.31, 0.070),
      .location: Rect.fromLTWH(0.305, 0.450, 0.27, 0.070),
      .chip: Rect.fromLTWH(0.090, 0.300, 0.175, 0.230),
      .barcode: Rect.fromLTWH(0.640, 0.475, 0.300, 0.085),
      .cardSerial: Rect.fromLTWH(0.720, 0.550, 0.145, 0.055),
      .mrz: Rect.fromLTWH(0.080, 0.660, 0.820, 0.285),
      .mrzLine1: Rect.fromLTWH(0.080, 0.665, 0.820, 0.080),
      .mrzLine2: Rect.fromLTWH(0.080, 0.755, 0.820, 0.080),
      .mrzLine3: Rect.fromLTWH(0.080, 0.845, 0.820, 0.080),
    },
  );

  /// Previous design, back: PDF417 barcode across the top, data lines in the
  /// middle and a TD1 MRZ (document code "ID") at the bottom. Rows measured on
  /// a low resolution sample: calibrate the field boxes with real captures.
  static const DocumentTemplate legacyBack = DocumentTemplate(
    type: .paraguayIdLegacy,
    side: .back,
    fields: {
      .barcode: Rect.fromLTWH(0.020, 0.000, 0.960, 0.390),
      .identificationCode: Rect.fromLTWH(0.020, 0.495, 0.480, 0.045),
      .location: Rect.fromLTWH(0.480, 0.495, 0.480, 0.045),
      .nationality: Rect.fromLTWH(0.020, 0.550, 0.450, 0.045),
      .civilStatus: Rect.fromLTWH(0.020, 0.595, 0.400, 0.055),
      .issueDate: Rect.fromLTWH(0.400, 0.595, 0.400, 0.055),
      .mrz: Rect.fromLTWH(0.010, 0.665, 0.970, 0.250),
      .mrzLine1: Rect.fromLTWH(0.010, 0.670, 0.970, 0.065),
      .mrzLine2: Rect.fromLTWH(0.010, 0.750, 0.970, 0.065),
      .mrzLine3: Rect.fromLTWH(0.010, 0.840, 0.970, 0.070),
    },
  );
}
