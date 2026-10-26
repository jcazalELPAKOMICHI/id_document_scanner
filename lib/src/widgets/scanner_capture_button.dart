import 'package:flutter/material.dart';

/// Round shutter button, enabled only while the card is ready.
class ScannerCaptureButton extends StatelessWidget {
  const ScannerCaptureButton({super.key, required this.color, required this.onPressed});

  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: .opaque,
      onTap: onPressed,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: onPressed == null ? 0.4 : 1,
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: .circle,
            border: .all(color: color, width: 4),
          ),
          padding: const .all(5),
          child: DecoratedBox(
            decoration: BoxDecoration(shape: .circle, color: color),
          ),
        ),
      ),
    );
  }
}
