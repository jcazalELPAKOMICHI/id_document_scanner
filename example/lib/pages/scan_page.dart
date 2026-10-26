import 'package:flutter/material.dart';
import 'package:id_document_scanner/id_document_scanner.dart';

import '../services/fake_identity_backend.dart';
import '../widgets/next_side_button.dart';
import 'result_page.dart';

class ScanPage extends StatefulWidget {
  const ScanPage({
    super.key,
    required this.documentType,
    required this.autoCapture,
    required this.autoAdvance,
    required this.rejectFirstAttempt,
    required this.showDebugInfo,
  });

  final DocumentType documentType;
  final bool autoCapture;
  final bool autoAdvance;
  final bool rejectFirstAttempt;
  final bool showDebugInfo;

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  late final FakeIdentityBackend backend = FakeIdentityBackend(rejectFirstAttempt: widget.rejectFirstAttempt);
  late final IdDocumentScannerController controller = IdDocumentScannerController(
    documentType: widget.documentType,
    autoCapture: widget.autoCapture,
    autoAdvance: widget.autoAdvance,
    // The SDK waits for this before moving on: upload the cropped card and
    // answer accepted / rejected.
    validator: backend.validate,
  );

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> onCompleted(ScanResult result) async {
    final retake = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => ResultPage(result: result)));
    if (!mounted) return;
    if (retake ?? false) {
      await controller.reset();
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(backgroundColor: Colors.transparent, foregroundColor: Colors.white),
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final back = controller.side == .back;
          return IdDocumentScanner(
            controller: controller,
            title: back ? 'Dorso de tu cédula' : 'Frente de tu cédula',
            subtitle: back ? 'Que se vean bien las 3 líneas de abajo' : 'Apoyala sobre una superficie oscura y lisa',
            showCaptureButton: !widget.autoCapture,
            showDebugInfo: widget.showDebugInfo,
            onCompleted: onCompleted,
            // With autoAdvance off, the host decides when to continue.
            bottomBuilder: (context, state) => NextSideButton(
              visible: state.status == .captured && !widget.autoAdvance,
              label: controller.isLastSide ? 'Finalizar' : 'Continuar con el dorso',
              onPressed: controller.nextSide,
            ),
            // Example of customizing texts and colors (use your l10n / palette).
            messages: const ScannerMessages(ready: '¡Listo! Quedate quieto un segundo'),
            style: const ScannerOverlayStyle(readyColor: Color(0xFF00C853)),
          );
        },
      ),
    );
  }
}
