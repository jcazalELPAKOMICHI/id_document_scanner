import 'package:flutter/painting.dart';

import '../constants/scanner_constants.dart';
import 'scan_status.dart';

/// Look of the guide frame and message. Pass your app palette colors here.
class ScannerOverlayStyle {
  const ScannerOverlayStyle({
    this.scrimColor = ScannerConstants.defaultScrimColor,
    this.idleColor = ScannerConstants.defaultIdleColor,
    this.warningColor = ScannerConstants.defaultWarningColor,
    this.readyColor = ScannerConstants.defaultReadyColor,
    this.errorColor = ScannerConstants.defaultErrorColor,
    this.borderWidth = ScannerConstants.guideBorderWidth,
    this.cornerRadius = ScannerConstants.guideCornerRadius,
    this.cornerLength = ScannerConstants.guideCornerLength,
    this.cornerWidth = ScannerConstants.guideCornerWidth,
    this.messageBackgroundColor = ScannerConstants.defaultMessageBackground,
    this.messageTextStyle = const TextStyle(
      color: ScannerConstants.defaultMessageText,
      fontSize: 16,
      fontWeight: .w600,
    ),
    this.titleTextStyle = const TextStyle(color: ScannerConstants.defaultMessageText, fontSize: 20, fontWeight: .w700),
    this.subtitleTextStyle = const TextStyle(color: ScannerConstants.defaultMessageText, fontSize: 14),
    this.flashColor = ScannerConstants.defaultFlashColor,
    this.cardIllustrationColor = ScannerConstants.defaultCardIllustration,
    this.showScanLine = true,
    this.enableHaptics = true,
  });

  final Color scrimColor;
  final Color idleColor;
  final Color warningColor;
  final Color readyColor;
  final Color errorColor;
  final double borderWidth;
  final double cornerRadius;
  final double cornerLength;
  final double cornerWidth;
  final Color messageBackgroundColor;
  final TextStyle messageTextStyle;
  final TextStyle titleTextStyle;
  final TextStyle subtitleTextStyle;

  /// Flash shown when the photo is taken.
  final Color flashColor;

  /// Card drawn in the flip animation between sides.
  final Color cardIllustrationColor;

  /// Animated scan line sweeping the frame while searching.
  final bool showScanLine;

  /// Vibrates when the frame turns green and when the photo is taken.
  final bool enableHaptics;

  /// Frame color for [status]: green when the card can be captured.
  Color colorFor(ScanStatus status) {
    if (status == .rejected || status == .error || status == .permissionDenied) return errorColor;
    if (status.isReady || status == .captured || status == .completed || status == .validating) return readyColor;
    if (status.isWarning) return warningColor;
    return idleColor;
  }
}
