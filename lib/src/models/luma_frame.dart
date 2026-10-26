import 'dart:typed_data';

/// Luminance (Y) plane of a camera frame as delivered by the sensor, plus the
/// rotation needed to show it upright.
class LumaFrame {
  const LumaFrame({
    required this.width,
    required this.height,
    required this.bytesPerRow,
    required this.bytes,
    required this.sensorOrientation,
  });

  final int width;
  final int height;
  final int bytesPerRow;
  final Uint8List bytes;

  /// Clockwise degrees (0, 90, 180, 270) that turn the sensor image upright.
  final int sensorOrientation;

  bool get isRotated => sensorOrientation == 90 || sensorOrientation == 270;

  int get uprightWidth => isRotated ? height : width;

  int get uprightHeight => isRotated ? width : height;

  /// Luma at normalized upright coordinates ([u], [v] in 0..1).
  int sampleUpright(double u, double v) {
    final (x, y) = switch (sensorOrientation) {
      90 => (v, 1 - u),
      180 => (1 - u, 1 - v),
      270 => (1 - v, u),
      _ => (u, v),
    };
    final px = (x * (width - 1)).round().clamp(0, width - 1);
    final py = (y * (height - 1)).round().clamp(0, height - 1);
    return bytes[py * bytesPerRow + px];
  }
}
