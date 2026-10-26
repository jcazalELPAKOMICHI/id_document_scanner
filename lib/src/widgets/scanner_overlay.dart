import 'dart:math';

import 'package:flutter/material.dart';

import '../constants/scanner_constants.dart';
import '../models/scanner_overlay_state.dart';
import '../models/scanner_overlay_style.dart';
import 'scanner_header.dart';
import 'scanner_message_banner.dart';
import 'scanner_overlay_painter.dart';

/// Default overlay: dimmed surroundings and a card-shaped frame that opens
/// with an entry animation, breathes and sweeps a scan line while searching,
/// glows green when ready and traces its border while the card is held steady.
class ScannerOverlay extends StatefulWidget {
  const ScannerOverlay({super.key, required this.state, required this.style, this.title, this.subtitle});

  final ScannerOverlayState state;
  final ScannerOverlayStyle style;
  final String? title;
  final String? subtitle;

  @override
  State<ScannerOverlay> createState() => _ScannerOverlayState();
}

class _ScannerOverlayState extends State<ScannerOverlay> with TickerProviderStateMixin {
  late final AnimationController entry = AnimationController(vsync: this, duration: ScannerConstants.entryDuration)
    ..forward();
  late final AnimationController scanLine = AnimationController(
    vsync: this,
    duration: ScannerConstants.scanLineDuration,
  )..repeat();
  late final AnimationController pulse = AnimationController(vsync: this, duration: ScannerConstants.pulseDuration)
    ..repeat(reverse: true);
  late final Animation<double> entryCurve = CurvedAnimation(parent: entry, curve: Curves.easeOutCubic);
  late final Animation<double> pulseCurve = CurvedAnimation(parent: pulse, curve: Curves.easeInOut);
  late final Animation<double> scanCurve = CurvedAnimation(parent: scanLine, curve: Curves.easeInOutSine);
  late final AnimationController shake = AnimationController(vsync: this, duration: ScannerConstants.shakeDuration);

  @override
  void didUpdateWidget(ScannerOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state.status == .rejected && oldWidget.state.status != .rejected) shake.forward(from: 0);
  }

  /// Damped horizontal shake of the frame (rejection).
  double get shakeOffset =>
      sin(shake.value * pi * 2 * ScannerConstants.shakeCycles) * (1 - shake.value) * ScannerConstants.shakeDistance;

  @override
  void dispose() {
    entry.dispose();
    scanLine.dispose();
    pulse.dispose();
    shake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final state = widget.state;
    final searching = !state.status.isSettled;
    return Material(
      type: .transparency,
      child: Stack(
        fit: .expand,
        children: [
          TweenAnimationBuilder(
            tween: ColorTween(end: state.frameColor),
            duration: ScannerConstants.colorTransition,
            builder: (context, color, _) => TweenAnimationBuilder(
              tween: Tween(end: searching ? 0.0 : 1.0),
              duration: ScannerConstants.readinessDuration,
              curve: Curves.easeOut,
              builder: (context, readiness, _) => TweenAnimationBuilder(
                tween: Tween(end: state.status == .captured || state.status == .completed ? 1.0 : state.progress),
                duration: ScannerConstants.progressDuration,
                builder: (context, progress, _) => AnimatedBuilder(
                  animation: Listenable.merge([entry, scanLine, pulse, shake]),
                  builder: (context, _) => CustomPaint(
                    painter: ScannerOverlayPainter(
                      guide: state.guide.translate(shakeOffset, 0),
                      color: color ?? state.frameColor,
                      style: widget.style,
                      entry: entryCurve.value,
                      pulse: pulseCurve.value,
                      scanLine: widget.style.showScanLine && searching ? scanCurve.value : null,
                      readiness: readiness,
                      progress: progress,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (widget.title != null || widget.subtitle != null)
            Positioned(
              top: padding.top + 24,
              left: 24,
              right: 24,
              child: FadeTransition(
                opacity: entryCurve,
                child: SlideTransition(
                  position: Tween(begin: const Offset(0, -0.4), end: Offset.zero).animate(entryCurve),
                  child: ScannerHeader(title: widget.title, subtitle: widget.subtitle, style: widget.style),
                ),
              ),
            ),
          Positioned(
            top: state.guide.bottom + 24,
            left: 24,
            right: 24,
            child: FadeTransition(
              opacity: entryCurve,
              child: Center(
                child: ScannerMessageBanner(
                  status: state.status,
                  message: state.message,
                  accentColor: state.frameColor,
                  style: widget.style,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
