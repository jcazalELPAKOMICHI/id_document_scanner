import 'dart:ui';

/// Fixed values shared by the scanner. Everything tunable per integration lives
/// in [DetectionConfig] / [ScannerOverlayStyle]; these are the defaults.
abstract final class ScannerConstants {
  /// ISO/IEC 7810 ID-1 card: 85.60 mm x 53.98 mm.
  static const double idCardAspectRatio = 85.60 / 53.98;

  static const double guideWidthFactor = 0.88;
  static const double guideVerticalCenter = 0.42;

  static const int analysisGridWidth = 220;
  static const Duration analysisInterval = Duration(milliseconds: 120);
  static const Duration captureCooldown = Duration(milliseconds: 600);
  static const int maxLuma = 255;

  static const double cropPadding = 0.01;
  static const int refineWorkWidth = 1280;
  static const int capturedJpegQuality = 92;

  /// `CameraException.code` values reported when camera access is refused.
  static const Set<String> permissionDeniedCodes = {
    'CameraAccessDenied',
    'CameraAccessDeniedWithoutPrompt',
    'CameraAccessRestricted',
  };

  static const double guideBorderWidth = 3;
  static const double guideCornerRadius = 14;
  static const double guideCornerLength = 30;
  static const double guideCornerWidth = 6;
  static const Duration colorTransition = Duration(milliseconds: 220);
  static const Duration entryDuration = Duration(milliseconds: 650);
  static const Duration scanLineDuration = Duration(milliseconds: 2200);
  static const Duration pulseDuration = Duration(milliseconds: 1300);
  static const Duration readinessDuration = Duration(milliseconds: 350);
  static const Duration progressDuration = Duration(milliseconds: 160);
  static const Duration messageTransition = Duration(milliseconds: 280);
  static const Duration flashDuration = Duration(milliseconds: 320);
  static const Duration successDuration = Duration(milliseconds: 700);
  static const Duration flipDuration = Duration(milliseconds: 1600);
  static const Duration shakeDuration = Duration(milliseconds: 520);

  /// How long the success check stays before moving to the next side.
  static const Duration acceptedHold = Duration(milliseconds: 900);

  /// How long a rejection message stays before scanning again.
  static const Duration rejectedHold = Duration(milliseconds: 2200);
  static const double shakeDistance = 10;
  static const int shakeCycles = 3;

  static const double entryInset = 18;
  static const double pulseAmplitude = 3;
  static const double glowBlur = 14;
  static const double scanLineHeight = 34;
  static const double progressWidth = 5;

  static const Color defaultScrimColor = Color(0x99000000);
  static const Color defaultIdleColor = Color(0xFFFFFFFF);
  static const Color defaultWarningColor = Color(0xFFFFC107);
  static const Color defaultReadyColor = Color(0xFF2ECC71);
  static const Color defaultErrorColor = Color(0xFFFF5252);
  static const Color defaultMessageBackground = Color(0xCC000000);
  static const Color defaultMessageText = Color(0xFFFFFFFF);
  static const Color defaultFlashColor = Color(0xFFFFFFFF);
  static const Color defaultCardIllustration = Color(0xFFE8EEF6);
  static const Color cardIllustrationShadow = Color(0x55000000);

  /// Placeholder MRZ line drawn on the back-side illustration.
  static const String mrzIllustrationLine = '<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<';
}
