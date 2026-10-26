import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:id_document_scanner/src/security/spectrum.dart';

void main() {
  const size = 64;

  test('a pure grating gives one prominent peak at its frequency', () {
    final samples = Float64List(size * size);
    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        samples[y * size + x] = 128 + 60 * sin(2 * pi * 20 * x / size);
      }
    }
    final spectrum = Spectrum.of(samples, size);
    expect(spectrum.at(20, 0), greaterThan(spectrum.at(10, 0) * 1000));
    expect(spectrum.peakProminence(minRadius: 0.4, maxRadius: 0.9), greaterThan(100));
  });

  test('random noise has no prominent peak', () {
    final random = Random(3);
    final samples = Float64List.fromList(List.generate(size * size, (_) => random.nextDouble() * 255));
    expect(Spectrum.of(samples, size).peakProminence(minRadius: 0.4, maxRadius: 0.9), lessThan(20));
  });
}
