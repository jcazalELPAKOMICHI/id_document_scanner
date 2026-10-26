import 'package:flutter/material.dart';

import '../constants/scanner_constants.dart';
import '../models/document_side.dart';

/// Simplified drawing of one face of an ID card, used in the flip hint.
class CardFaceIllustration extends StatelessWidget {
  const CardFaceIllustration({super.key, required this.side, required this.color, required this.accentColor});

  final DocumentSide side;
  final Color color;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final line = accentColor.withValues(alpha: 0.45);
    return AspectRatio(
      aspectRatio: ScannerConstants.idCardAspectRatio,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          borderRadius: .circular(12),
          boxShadow: const [
            BoxShadow(blurRadius: 18, offset: Offset(0, 8), color: ScannerConstants.cardIllustrationShadow),
          ],
        ),
        child: Padding(
          padding: const .all(12),
          child: Column(
            crossAxisAlignment: .start,
            children: [
              if (side == .front) ...[
                Container(height: 8, width: 120, color: line),
                const SizedBox(height: 10),
                Expanded(
                  child: Row(
                    crossAxisAlignment: .stretch,
                    children: [
                      AspectRatio(
                        aspectRatio: 0.78,
                        child: DecoratedBox(
                          decoration: BoxDecoration(color: line, borderRadius: .circular(6)),
                          child: Icon(Icons.person_rounded, color: color, size: 40),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: .start,
                          mainAxisAlignment: .spaceEvenly,
                          children: [0.9, 0.7, 0.8, 0.5]
                              .map(
                                (width) => FractionallySizedBox(
                                  widthFactor: width,
                                  child: Container(height: 7, color: line),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 26,
                      decoration: BoxDecoration(color: accentColor.withValues(alpha: 0.7), borderRadius: .circular(5)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Container(height: 7, color: line)),
                  ],
                ),
                const Spacer(),
                ...List.generate(
                  3,
                  (_) => Padding(
                    padding: const .only(top: 6),
                    child: Text(
                      ScannerConstants.mrzIllustrationLine,
                      maxLines: 1,
                      overflow: .clip,
                      style: TextStyle(color: line, fontSize: 11, letterSpacing: 1, fontWeight: .w700),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
