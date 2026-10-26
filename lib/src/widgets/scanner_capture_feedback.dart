import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/scanner_constants.dart';
import '../models/scan_status.dart';
import '../models/scanner_overlay_style.dart';

/// What happens inside the frame after the shutter: camera flash, the cropped
/// card frozen in place while it is validated (with a spinner), then an
/// animated check (accepted) or cross (rejected).
class ScannerCaptureFeedback extends StatefulWidget {
  const ScannerCaptureFeedback({
    super.key,
    required this.status,
    required this.guide,
    required this.style,
    this.cardImage,
  });

  final ScanStatus status;
  final Rect guide;
  final ScannerOverlayStyle style;

  /// Cropped card of the last capture, shown frozen inside the frame.
  final Uint8List? cardImage;

  @override
  State<ScannerCaptureFeedback> createState() => _ScannerCaptureFeedbackState();
}

class _ScannerCaptureFeedbackState extends State<ScannerCaptureFeedback> with TickerProviderStateMixin {
  late final AnimationController flash = AnimationController(vsync: this, duration: ScannerConstants.flashDuration);
  late final AnimationController badge = AnimationController(vsync: this, duration: ScannerConstants.successDuration);
  late final Animation<double> flashOpacity = Tween(begin: 0.85, end: 0.0).animate(flash);
  late final Animation<double> badgeScale = CurvedAnimation(parent: badge, curve: Curves.elasticOut);
  late final Animation<double> badgeFade = CurvedAnimation(parent: badge, curve: const Interval(0, 0.3));

  bool get showsBadge => widget.status == .captured || widget.status == .completed || widget.status == .rejected;

  bool get showsCard =>
      widget.cardImage != null && (widget.status == .validating || showsBadge) && widget.status != .completed;

  @override
  void didUpdateWidget(ScannerCaptureFeedback oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status == widget.status) return;
    if (widget.status == .capturing) {
      flash.forward(from: 0);
      if (widget.style.enableHaptics) HapticFeedback.mediumImpact();
    }
    if (showsBadge && widget.status != .completed) {
      badge.forward(from: 0);
      if (widget.style.enableHaptics && widget.status == .rejected) HapticFeedback.heavyImpact();
    }
    if (!showsBadge) badge.reset();
  }

  @override
  void dispose() {
    flash.dispose();
    badge.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.guide.shortestSide * 0.42;
    final rejected = widget.status == .rejected;
    final badgeColor = rejected ? widget.style.errorColor : widget.style.readyColor;
    final cardImage = widget.cardImage;
    return IgnorePointer(
      child: Stack(
        fit: .expand,
        children: [
          Positioned.fromRect(
            rect: widget.guide,
            child: AnimatedOpacity(
              opacity: showsCard ? 1 : 0,
              duration: ScannerConstants.readinessDuration,
              child: ClipRRect(
                borderRadius: .circular(widget.style.cornerRadius),
                child: Stack(
                  fit: .expand,
                  children: [
                    if (cardImage != null) Image.memory(cardImage, fit: .cover, gaplessPlayback: true),
                    AnimatedContainer(
                      duration: ScannerConstants.readinessDuration,
                      color: widget.style.scrimColor.withValues(alpha: widget.status == .validating ? 0.45 : 0.25),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned.fromRect(
            rect: Rect.fromCenter(center: widget.guide.center, width: size, height: size),
            child: Stack(
              fit: .expand,
              children: [
                AnimatedScale(
                  scale: widget.status == .validating ? 1 : 0.6,
                  duration: ScannerConstants.readinessDuration,
                  curve: Curves.easeOutBack,
                  child: AnimatedOpacity(
                    opacity: widget.status == .validating ? 1 : 0,
                    duration: ScannerConstants.readinessDuration,
                    child: Padding(
                      padding: .all(size * 0.18),
                      child: CircularProgressIndicator(
                        strokeWidth: 4,
                        strokeCap: .round,
                        color: widget.style.readyColor,
                        backgroundColor: widget.style.idleColor.withValues(alpha: 0.25),
                      ),
                    ),
                  ),
                ),
                FadeTransition(
                  opacity: badgeFade,
                  child: ScaleTransition(
                    scale: badgeScale,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: .circle,
                        color: badgeColor,
                        boxShadow: [BoxShadow(color: badgeColor.withValues(alpha: 0.5), blurRadius: 24)],
                      ),
                      child: Icon(
                        rejected ? Icons.close_rounded : Icons.check_rounded,
                        color: widget.style.idleColor,
                        size: size * 0.62,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          FadeTransition(
            opacity: flashOpacity,
            child: AnimatedBuilder(
              animation: flash,
              builder: (context, _) =>
                  flash.isAnimating ? ColoredBox(color: widget.style.flashColor) : const SizedBox(),
            ),
          ),
        ],
      ),
    );
  }
}
