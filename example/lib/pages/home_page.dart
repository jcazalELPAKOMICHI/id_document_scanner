import 'package:flutter/material.dart';
import 'package:id_document_scanner/id_document_scanner.dart';

import 'scan_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  DocumentType documentType = .paraguayIdCurrent;
  bool autoCapture = true;
  bool autoAdvance = true;
  bool rejectFirstAttempt = true;
  bool showDebugInfo = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Escáner de cédula')),
      body: ListView(
        padding: const .all(16),
        children: [
          SegmentedButton(
            segments: const [
              ButtonSegment(value: DocumentType.paraguayIdCurrent, label: Text('Cédula nueva')),
              ButtonSegment(value: DocumentType.paraguayIdLegacy, label: Text('Cédula anterior')),
            ],
            selected: {documentType},
            onSelectionChanged: (selection) => setState(() => documentType = selection.first),
          ),
          SwitchListTile(
            title: const Text('Captura automática'),
            value: autoCapture,
            onChanged: (value) => setState(() => autoCapture = value),
          ),
          SwitchListTile(
            title: const Text('Avanzar solo al dorso'),
            subtitle: const Text('Apagado: la app decide cuándo continuar'),
            value: autoAdvance,
            onChanged: (value) => setState(() => autoAdvance = value),
          ),
          SwitchListTile(
            title: const Text('Simular rechazo del backend'),
            subtitle: const Text('El primer intento de cada lado se rechaza'),
            value: rejectFirstAttempt,
            onChanged: (value) => setState(() => rejectFirstAttempt = value),
          ),
          SwitchListTile(
            title: const Text('Mostrar valores de detección'),
            value: showDebugInfo,
            onChanged: (value) => setState(() => showDebugInfo = value),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            icon: const Icon(Icons.document_scanner),
            label: const Text('Escanear frente y dorso'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ScanPage(
                  documentType: documentType,
                  autoCapture: autoCapture,
                  autoAdvance: autoAdvance,
                  rejectFirstAttempt: rejectFirstAttempt,
                  showDebugInfo: showDebugInfo,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
