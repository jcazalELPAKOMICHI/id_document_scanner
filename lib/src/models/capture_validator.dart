import 'dart:async';

import 'capture_validation.dart';
import 'document_capture.dart';

/// Called with every capture before moving on. Upload the cropped card to
/// your backend here and answer whether the flow can continue.
typedef CaptureValidator = FutureOr<CaptureValidation> Function(DocumentCapture capture);
