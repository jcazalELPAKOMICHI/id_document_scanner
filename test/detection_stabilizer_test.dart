import 'package:flutter_test/flutter_test.dart';
import 'package:id_document_scanner/id_document_scanner.dart';

FrameAnalysis frame(ScanStatus status, {double offset = 0}) => FrameAnalysis(
  status: status,
  edges: List.filled(4, EdgeMeasurement(detected: true, coverage: 1, strength: 40, offset: offset)),
  brightness: 150,
  sharpness: 500,
  glareRatio: 0,
);

void main() {
  const config = DetectionConfig(requiredStableFrames: 3);

  test('becomes stable after consecutive ready frames', () {
    final stabilizer = DetectionStabilizer(config: config);
    expect(stabilizer.add(frame(.ready)), isFalse);
    expect(stabilizer.add(frame(.ready, offset: 0.01)), isFalse);
    expect(stabilizer.add(frame(.ready)), isTrue);
  });

  test('a non-ready frame starts over', () {
    final stabilizer = DetectionStabilizer(config: config);
    stabilizer
      ..add(frame(.ready))
      ..add(frame(.ready))
      ..add(frame(.blurry));
    expect(stabilizer.add(frame(.ready)), isFalse);
  });

  test('moving the card starts over', () {
    final stabilizer = DetectionStabilizer(config: config);
    stabilizer
      ..add(frame(.ready))
      ..add(frame(.ready));
    expect(stabilizer.add(frame(.ready, offset: 0.06)), isFalse);
    expect(stabilizer.stableFrames, 1);
  });
}
