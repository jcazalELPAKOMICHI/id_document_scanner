import 'dart:ui';

import 'document_side.dart';
import 'frame_analysis.dart';
import 'scan_status.dart';

/// What a custom `overlayBuilder` receives to draw its own UI.
class ScannerOverlayState {
  const ScannerOverlayState({
    required this.status,
    required this.message,
    required this.guide,
    required this.frameColor,
    required this.analysis,
    this.progress = 0,
    this.side = .front,
  });

  final ScanStatus status;
  final String message;

  /// Guide rect in the scanner widget's coordinates.
  final Rect guide;
  final Color frameColor;
  final FrameAnalysis? analysis;

  /// 0..1 while the card is held steady before auto-capture.
  final double progress;
  final DocumentSide side;
}
