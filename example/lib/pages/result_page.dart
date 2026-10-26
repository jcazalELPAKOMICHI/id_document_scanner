import 'package:flutter/material.dart';
import 'package:id_document_scanner/id_document_scanner.dart';

import '../widgets/capture_section.dart';

class ResultPage extends StatelessWidget {
  const ResultPage({super.key, required this.result});

  final ScanResult result;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Capturas aceptadas')),
      body: ListView(
        padding: const .all(16),
        children: [
          ...result.captures.values.map(
            (capture) => CaptureSection(capture: capture, validationData: result.validationData[capture.side]),
          ),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Volver a escanear')),
          FilledButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Usar estas fotos')),
        ],
      ),
    );
  }
}
