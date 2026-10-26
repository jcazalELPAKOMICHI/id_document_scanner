import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import '../constants/scanner_constants.dart';
import '../models/scanner_overlay_style.dart';

/// Darkens everything outside the guide and draws its frame: border, corner
/// brackets, scan line, readiness glow and the steady-hold progress.
class ScannerOverlayPainter extends CustomPainter {
  const ScannerOverlayPainter({
    required this.guide,
    required this.color,
    required this.style,
    this.entry = 1,
    this.pulse = 0,
    this.scanLine,
    this.readiness = 0,
    this.progress = 0,
  });

  final Rect guide;
  final Color color;
  final ScannerOverlayStyle style;

  /// 0..1 opening animation (frame grows into place, scrim fades in).
  final double entry;

  /// 0..1 breathing of the corner brackets while searching.
  final double pulse;

  /// 0..1 vertical position of the scan line, null to hide it.
  final double? scanLine;

  /// 0..1 how "ready" the frame looks (glow, solid border).
  final double readiness;

  /// 0..1 portion of the border traced while holding steady.
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = guide.inflate((1 - entry) * ScannerConstants.entryInset);
    final frame = RRect.fromRectAndRadius(rect, Radius.circular(style.cornerRadius));

    final scrim = Path()
      ..fillType = .evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(frame);
    canvas.drawPath(scrim, Paint()..color = style.scrimColor.withValues(alpha: style.scrimColor.a * entry));

    if (readiness > 0) {
      canvas.drawRRect(
        frame,
        Paint()
          ..color = color.withValues(alpha: 0.55 * readiness * entry)
          ..style = .stroke
          ..strokeWidth = style.borderWidth * 2
          ..maskFilter = const .blur(.outer, ScannerConstants.glowBlur),
      );
    }

    if (scanLine case final position? when entry > 0) _paintScanLine(canvas, frame, rect, position);

    canvas.drawRRect(
      frame,
      Paint()
        // Dimmed while ready so the steady-hold progress stands out on top.
        ..color = color.withValues(alpha: (0.45 - 0.15 * readiness) * entry)
        ..style = .stroke
        ..strokeWidth = style.borderWidth,
    );

    _paintCorners(canvas, rect);
    if (progress > 0) _paintProgress(canvas, frame);
  }

  void _paintScanLine(Canvas canvas, RRect frame, Rect rect, double position) {
    final y = rect.top + rect.height * position;
    final band = Rect.fromLTRB(rect.left, y - ScannerConstants.scanLineHeight, rect.right, y);
    final fade = sin(position * pi) * (1 - readiness) * entry;
    canvas
      ..save()
      ..clipRRect(frame)
      ..drawRect(
        band,
        Paint()
          ..shader = ui.Gradient.linear(band.topCenter, band.bottomCenter, [
            color.withValues(alpha: 0),
            color.withValues(alpha: 0.28 * fade),
          ]),
      )
      ..drawLine(
        Offset(rect.left, y),
        Offset(rect.right, y),
        Paint()
          ..color = color.withValues(alpha: 0.9 * fade)
          ..strokeWidth = 2,
      )
      ..restore();
  }

  void _paintCorners(Canvas canvas, Rect rect) {
    final corners = Paint()
      ..color = color.withValues(alpha: entry)
      ..style = .stroke
      ..strokeWidth = style.cornerWidth
      ..strokeCap = .round;
    final radius = style.cornerRadius;
    final length = style.cornerLength * (1 + (1 - readiness) * pulse * 0.25);
    final shift = (1 - readiness) * pulse * ScannerConstants.pulseAmplitude;
    for (final (corner, dx, dy) in [
      (rect.topLeft, 1.0, 1.0),
      (rect.topRight, -1.0, 1.0),
      (rect.bottomRight, -1.0, -1.0),
      (rect.bottomLeft, 1.0, -1.0),
    ]) {
      final origin = corner.translate(-dx * shift, -dy * shift);
      final path = Path()
        ..moveTo(origin.dx, origin.dy + dy * (radius + length))
        ..lineTo(origin.dx, origin.dy + dy * radius)
        ..arcToPoint(
          Offset(origin.dx + dx * radius, origin.dy),
          radius: Radius.circular(radius),
          clockwise: dx * dy > 0,
        )
        ..lineTo(origin.dx + dx * (radius + length), origin.dy);
      canvas.drawPath(path, corners);
    }
  }

  /// Traces the border clockwise starting at the top centre.
  void _paintProgress(Canvas canvas, RRect frame) {
    final metric = _clockwiseFromTopCenter(frame).computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * progress),
      Paint()
        ..color = color
        ..style = .stroke
        ..strokeWidth = ScannerConstants.progressWidth
        ..strokeCap = .round,
    );
  }

  Path _clockwiseFromTopCenter(RRect frame) {
    final radius = Radius.circular(style.cornerRadius);
    final r = style.cornerRadius;
    return Path()
      ..moveTo(frame.center.dx, frame.top)
      ..lineTo(frame.right - r, frame.top)
      ..arcToPoint(Offset(frame.right, frame.top + r), radius: radius)
      ..lineTo(frame.right, frame.bottom - r)
      ..arcToPoint(Offset(frame.right - r, frame.bottom), radius: radius)
      ..lineTo(frame.left + r, frame.bottom)
      ..arcToPoint(Offset(frame.left, frame.bottom - r), radius: radius)
      ..lineTo(frame.left, frame.top + r)
      ..arcToPoint(Offset(frame.left + r, frame.top), radius: radius)
      ..close();
  }

  @override
  bool shouldRepaint(ScannerOverlayPainter oldDelegate) =>
      oldDelegate.guide != guide ||
      oldDelegate.color != color ||
      oldDelegate.style != style ||
      oldDelegate.entry != entry ||
      oldDelegate.pulse != pulse ||
      oldDelegate.scanLine != scanLine ||
      oldDelegate.readiness != readiness ||
      oldDelegate.progress != progress;
}
