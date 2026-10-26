import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:id_document_scanner/id_document_scanner.dart';

import 'verification_summary.dart';

/// One captured side with its template crops.
class CaptureSection extends StatelessWidget {
  const CaptureSection({super.key, required this.capture, this.validationData});

  final DocumentCapture capture;
  final Object? validationData;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return FutureBuilder(
      future: capture.cropFields(),
      builder: (context, snapshot) {
        final fields = snapshot.data ?? const <DocumentField, Uint8List>{};
        return Column(
          crossAxisAlignment: .stretch,
          children: [
            Text(capture.side == .front ? 'Frente' : 'Dorso', style: textTheme.titleLarge),
            const SizedBox(height: 8),
            ClipRRect(borderRadius: .circular(12), child: Image.memory(capture.cardImage)),
            const SizedBox(height: 4),
            Text(
              'Recorte ${capture.isPreciseCrop ? 'exacto (perspectiva corregida)' : 'aproximado'} · backend: $validationData',
              style: textTheme.bodySmall,
            ),
            if (capture.verification case final verification?) VerificationSummary(verification: verification),
            ...fields.entries.map(
              (entry) => ListTile(
                contentPadding: .zero,
                title: Text(entry.key.name),
                subtitle: Align(alignment: .centerLeft, child: Image.memory(entry.value, height: 44)),
              ),
            ),
            const Divider(height: 32),
          ],
        );
      },
    );
  }
}
