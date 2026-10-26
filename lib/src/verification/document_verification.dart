import '../models/document_type.dart';
import '../mrz/mrz_data.dart';
import 'document_rejection_reason.dart';
import 'document_verification_status.dart';

/// Result of checking a capture against the Paraguayan identity card.
class DocumentVerification {
  const DocumentVerification({
    required this.status,
    this.reason,
    this.detectedType,
    this.mrz,
    this.mrzLines,
    this.score,
  });

  final DocumentVerificationStatus status;
  final DocumentRejectionReason? reason;

  /// Card design recognised (from the MRZ document code or the front header).
  final DocumentType? detectedType;

  /// Data read from the back.
  final MrzData? mrz;
  final List<String>? mrzLines;

  /// Header correlation (front) or OCR confidence (back), 0..1.
  final double? score;

  bool get isVerified => status == .verified;
}
