import 'document_capture.dart';
import 'document_side.dart';

/// All accepted captures once every side of the flow was scanned.
class ScanResult {
  const ScanResult({required this.captures, required this.validationData});

  final Map<DocumentSide, DocumentCapture> captures;

  /// `CaptureValidation.data` returned by the validator for each side.
  final Map<DocumentSide, Object?> validationData;

  DocumentCapture? get front => captures[DocumentSide.front];

  DocumentCapture? get back => captures[DocumentSide.back];
}
