import 'package:flutter/material.dart';

import '../models/scanner_overlay_style.dart';

/// Optional custom title and subtitle shown above the guide.
class ScannerHeader extends StatelessWidget {
  const ScannerHeader({super.key, this.title, this.subtitle, required this.style});

  final String? title;
  final String? subtitle;
  final ScannerOverlayStyle style;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: .min,
      children: [
        if (title case final title?) Text(title, textAlign: .center, style: style.titleTextStyle),
        if (subtitle case final subtitle?) ...[
          const SizedBox(height: 6),
          Text(subtitle, textAlign: .center, style: style.subtitleTextStyle),
        ],
      ],
    );
  }
}
