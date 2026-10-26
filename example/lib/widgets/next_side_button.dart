import 'package:flutter/material.dart';

/// Shown when the host controls the transition between sides.
class NextSideButton extends StatelessWidget {
  const NextSideButton({super.key, required this.visible, required this.label, required this.onPressed});

  final bool visible;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      offset: visible ? Offset.zero : const Offset(0, 0.5),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 250),
        child: IgnorePointer(
          ignoring: !visible,
          child: FilledButton(onPressed: onPressed, child: Text(label)),
        ),
      ),
    );
  }
}
