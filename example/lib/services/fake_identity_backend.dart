import 'package:id_document_scanner/id_document_scanner.dart';

/// Stand-in for your backend: replace [validate] with the real upload
/// (e.g. a use case that posts `capture.cardImage` and maps the response).
class FakeIdentityBackend {
  FakeIdentityBackend({required this.rejectFirstAttempt});

  /// Simulates the backend refusing the first photo of each side.
  final bool rejectFirstAttempt;
  final Set<DocumentSide> attempted = {};

  Future<CaptureValidation> validate(DocumentCapture capture) async {
    await Future<void>.delayed(const Duration(milliseconds: 1600));
    if (rejectFirstAttempt && attempted.add(capture.side)) {
      return const CaptureValidation.rejected(message: 'La foto salió con poca nitidez, probemos otra vez');
    }
    return CaptureValidation.accepted(data: 'upload-${capture.side.name}-${capture.cardImage.length}');
  }
}
