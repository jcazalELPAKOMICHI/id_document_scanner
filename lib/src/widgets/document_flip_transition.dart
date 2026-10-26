import 'dart:math';

import 'package:flutter/material.dart';

import '../constants/scanner_constants.dart';
import '../models/document_side.dart';
import '../models/scanner_overlay_style.dart';
import 'card_face_illustration.dart';

/// Plays a 3D card flip over the frame when the scanner switches side, so
/// the user knows to turn the document around.
class DocumentFlipTransition extends StatefulWidget {
  const DocumentFlipTransition({
    super.key,
    required this.side,
    required this.guide,
    required this.message,
    required this.style,
  });

  final DocumentSide side;
  final Rect guide;
  final String message;
  final ScannerOverlayStyle style;

  @override
  State<DocumentFlipTransition> createState() => _DocumentFlipTransitionState();
}

class _DocumentFlipTransitionState extends State<DocumentFlipTransition> with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(vsync: this, duration: ScannerConstants.flipDuration);
  late final Animation<double> backdrop = TweenSequence([
    TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.easeOut)), weight: 15),
    TweenSequenceItem(tween: ConstantTween(1.0), weight: 70),
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeIn)), weight: 15),
  ]).animate(controller);
  late final Animation<double> turn = CurvedAnimation(
    parent: controller,
    curve: const Interval(0.2, 0.75, curve: Curves.easeInOutCubic),
  );

  @override
  void didUpdateWidget(DocumentFlipTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.side != widget.side) controller.forward(from: 0);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cardWidth = widget.guide.width * 0.62;
    final from = widget.side == .back ? DocumentSide.front : DocumentSide.back;
    return IgnorePointer(
      child: Material(
        type: .transparency,
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            if (!controller.isAnimating) return const SizedBox();
            final angle = turn.value * pi;
            final showingFrom = angle < pi / 2;
            return Opacity(
              opacity: backdrop.value,
              child: ColoredBox(
                color: widget.style.scrimColor.withValues(alpha: 1),
                child: Stack(
                  children: [
                    Positioned(
                      left: widget.guide.center.dx - cardWidth / 2,
                      top: widget.guide.center.dy - cardWidth / ScannerConstants.idCardAspectRatio / 2,
                      width: cardWidth,
                      child: Transform(
                        alignment: .center,
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.0012)
                          ..rotateY(angle)
                          ..scaleByDouble(1 - sin(angle) * 0.08, 1 - sin(angle) * 0.08, 1, 1),
                        child: Transform(
                          alignment: .center,
                          transform: Matrix4.rotationY(showingFrom ? 0 : pi),
                          child: CardFaceIllustration(
                            side: showingFrom ? from : widget.side,
                            color: widget.style.cardIllustrationColor,
                            accentColor: widget.style.readyColor,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: widget.guide.bottom + 24,
                      left: 24,
                      right: 24,
                      child: Column(
                        children: [
                          Icon(Icons.flip_rounded, color: widget.style.readyColor, size: 30),
                          const SizedBox(height: 10),
                          Text(widget.message, textAlign: .center, style: widget.style.titleTextStyle),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
