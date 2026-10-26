import 'package:flutter/material.dart';

import '../models/frame_analysis.dart';
import '../models/scanner_overlay_style.dart';

/// Raw detection values, for calibrating `DetectionConfig` on real devices.
class ScannerDebugPanel extends StatelessWidget {
  const ScannerDebugPanel({super.key, required this.analysis, required this.style});

  final FrameAnalysis? analysis;
  final ScannerOverlayStyle style;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: style.messageBackgroundColor,
      child: Padding(
        padding: const .all(8),
        child: Text(
          analysis?.toString() ?? '-',
          style: style.subtitleTextStyle.copyWith(fontFamily: 'monospace', fontSize: 11),
        ),
      ),
    );
  }
}
