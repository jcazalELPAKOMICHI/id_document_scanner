import 'capture_validation_status.dart';

/// What your [CaptureValidator] answers for a capture.
///
/// `accepted` moves the flow forward (next side, or completion); `rejected`
/// shows [message] (or the default rejection text) and scans the same side
/// again.
class CaptureValidation {
  const CaptureValidation({required this.status, this.message, this.data});

  const CaptureValidation.accepted({Object? data}) : this(status: .accepted, data: data);

  const CaptureValidation.rejected({String? message}) : this(status: .rejected, message: message);

  final CaptureValidationStatus status;

  /// Text shown to the user when rejected (e.g. the backend's reason).
  final String? message;

  /// Anything your validator wants to keep with the capture (e.g. the
  /// backend response); available in [ScanResult.validationData].
  final Object? data;

  bool get isAccepted => status == .accepted;
}
