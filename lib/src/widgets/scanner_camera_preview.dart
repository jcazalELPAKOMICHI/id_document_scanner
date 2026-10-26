import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

/// Camera preview filling its parent (`BoxFit.cover`), upright in portrait.
class ScannerCameraPreview extends StatelessWidget {
  const ScannerCameraPreview({super.key, required this.camera, required this.previewSize});

  final CameraController camera;
  final Size previewSize;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: FittedBox(
        fit: .cover,
        child: SizedBox(width: previewSize.width, height: previewSize.height, child: CameraPreview(camera)),
      ),
    );
  }
}
