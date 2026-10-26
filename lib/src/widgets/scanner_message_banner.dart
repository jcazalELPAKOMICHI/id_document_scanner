import 'package:flutter/material.dart';

import '../constants/scanner_constants.dart';
import '../models/scan_status.dart';
import '../models/scanner_overlay_style.dart';
import 'scan_status_icon.dart';

/// Pill with the current instruction and its icon. Text changes slide and
/// fade in, and the pill resizes smoothly to the new message.
class ScannerMessageBanner extends StatelessWidget {
  const ScannerMessageBanner({
    super.key,
    required this.status,
    required this.message,
    required this.accentColor,
    required this.style,
  });

  final ScanStatus status;
  final String message;
  final Color accentColor;
  final ScannerOverlayStyle style;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: ScannerConstants.messageTransition,
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: style.messageBackgroundColor,
        borderRadius: .circular(28),
        border: .all(color: accentColor.withValues(alpha: 0.6), width: 1.5),
      ),
      child: AnimatedSize(
        duration: ScannerConstants.messageTransition,
        curve: Curves.easeOutCubic,
        child: AnimatedSwitcher(
          duration: ScannerConstants.messageTransition,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween(begin: const Offset(0, 0.35), end: Offset.zero).animate(animation),
              child: child,
            ),
          ),
          child: Padding(
            key: ValueKey(message),
            padding: const .symmetric(horizontal: 18, vertical: 11),
            child: Row(
              mainAxisSize: .min,
              children: [
                Icon(status.icon, color: accentColor, size: 20),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(message, textAlign: .center, style: style.messageTextStyle),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
