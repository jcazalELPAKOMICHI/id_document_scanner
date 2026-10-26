import 'dart:typed_data';

import 'package:camera/camera.dart';

import '../models/luma_frame.dart';

/// Extracts the luminance plane from a streamed [CameraImage].
abstract final class CameraFrameConverter {
  static LumaFrame? toLumaFrame(CameraImage image, int sensorOrientation) {
    if (image.planes.isEmpty) return null;
    final plane = image.planes.first;
    return switch (image.format.group) {
      // Y is the first plane (or the first bytes of the single NV21 plane).
      .yuv420 || .nv21 => LumaFrame(
        width: image.width,
        height: image.height,
        bytesPerRow: plane.bytesPerRow,
        bytes: plane.bytes,
        sensorOrientation: sensorOrientation,
      ),
      .bgra8888 => _fromBgra(image, plane, sensorOrientation),
      _ => null,
    };
  }

  static LumaFrame _fromBgra(CameraImage image, Plane plane, int sensorOrientation) {
    final luma = Uint8List(image.width * image.height);
    final bytes = plane.bytes;
    for (var y = 0; y < image.height; y++) {
      final row = y * plane.bytesPerRow;
      for (var x = 0; x < image.width; x++) {
        final i = row + x * _bgraBytesPerPixel;
        // Integer BT.601 luma: (29 B + 150 G + 77 R) / 256.
        luma[y * image.width + x] = (29 * bytes[i] + 150 * bytes[i + 1] + 77 * bytes[i + 2]) >> 8;
      }
    }
    return LumaFrame(
      width: image.width,
      height: image.height,
      bytesPerRow: image.width,
      bytes: luma,
      sensorOrientation: sensorOrientation,
    );
  }

  static const int _bgraBytesPerPixel = 4;
}
