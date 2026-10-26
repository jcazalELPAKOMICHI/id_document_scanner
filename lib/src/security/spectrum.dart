import 'dart:math';
import 'dart:typed_data';

/// 2D power spectrum of a square, power-of-two patch (pure Dart FFT).
class Spectrum {
  Spectrum({required this.size, required this.power});

  /// [samples] is a size x size patch (row major). A Hann window is applied
  /// so the patch borders do not add artificial frequencies.
  factory Spectrum.of(Float64List samples, int size) {
    assert(size & (size - 1) == 0, 'size must be a power of two');
    final re = Float64List(size * size);
    final im = Float64List(size * size);
    var mean = 0.0;
    for (final value in samples) {
      mean += value;
    }
    mean /= samples.length;
    for (var y = 0; y < size; y++) {
      final wy = _hann(y, size);
      for (var x = 0; x < size; x++) {
        re[y * size + x] = (samples[y * size + x] - mean) * wy * _hann(x, size);
      }
    }
    final rowRe = Float64List(size);
    final rowIm = Float64List(size);
    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        rowRe[x] = re[y * size + x];
        rowIm[x] = im[y * size + x];
      }
      _fft(rowRe, rowIm);
      for (var x = 0; x < size; x++) {
        re[y * size + x] = rowRe[x];
        im[y * size + x] = rowIm[x];
      }
    }
    for (var x = 0; x < size; x++) {
      for (var y = 0; y < size; y++) {
        rowRe[y] = re[y * size + x];
        rowIm[y] = im[y * size + x];
      }
      _fft(rowRe, rowIm);
      for (var y = 0; y < size; y++) {
        re[y * size + x] = rowRe[y];
        im[y * size + x] = rowIm[y];
      }
    }
    final power = Float64List(size * size);
    for (var i = 0; i < power.length; i++) {
      power[i] = re[i] * re[i] + im[i] * im[i];
    }
    return Spectrum(size: size, power: power);
  }

  final int size;
  final Float64List power;

  /// Power at frequency (fx, fy) in cycles per patch, -size/2..size/2.
  double at(int fx, int fy) => power[(fy % size) * size + (fx % size)];

  /// Strongest isolated peak in the ring [minRadius, maxRadius] (as a
  /// fraction of the Nyquist frequency), relative to the median power of the
  /// same ring. Periodic structures (pixel grids, halftone screens) give
  /// sharp peaks far above the ring; natural texture and print do not.
  /// [floor] keeps flat, featureless patches (tiny median) from turning
  /// meaningless specks into huge ratios.
  double peakProminence({required double minRadius, required double maxRadius, double floor = 0}) {
    final half = size ~/ 2;
    final ring = <double>[];
    final points = <(int, int, double)>[];
    for (var fy = -half + 1; fy < half; fy++) {
      for (var fx = 0; fx < half; fx++) {
        final radius = sqrt(fx * fx + fy * fy) / half;
        if (radius < minRadius || radius > maxRadius) continue;
        // JPEG's 8x8 block grid (and its harmonics) is periodic too.
        if (fx % (size ~/ _jpegBlock) == 0 && fy % (size ~/ _jpegBlock) == 0) continue;
        final value = at(fx, fy);
        ring.add(value);
        points.add((fx, fy, value));
      }
    }
    if (ring.isEmpty) return 0;
    ring.sort();
    final median = max(ring[ring.length ~/ 2], floor);
    if (median <= 0) return 0;
    var best = 0.0;
    for (final (fx, fy, value) in points) {
      // A peak must also dominate its immediate neighbours (not broad texture).
      var neighbours = 0.0;
      var count = 0;
      for (var dy = -_neighbourhood; dy <= _neighbourhood; dy++) {
        for (var dx = -_neighbourhood; dx <= _neighbourhood; dx++) {
          if (dx.abs() <= 1 && dy.abs() <= 1) continue;
          neighbours += at(fx + dx, fy + dy);
          count++;
        }
      }
      final local = neighbours / count;
      if (value < local * _localDominance) continue;
      best = max(best, value / median);
    }
    return best;
  }

  static double _hann(int i, int n) => 0.5 - 0.5 * cos(2 * pi * i / (n - 1));

  /// In-place iterative radix-2 FFT.
  static void _fft(Float64List re, Float64List im) {
    final n = re.length;
    for (var i = 1, j = 0; i < n; i++) {
      var bit = n >> 1;
      for (; j & bit != 0; bit >>= 1) {
        j ^= bit;
      }
      j ^= bit;
      if (i < j) {
        final tr = re[i];
        re[i] = re[j];
        re[j] = tr;
        final ti = im[i];
        im[i] = im[j];
        im[j] = ti;
      }
    }
    for (var length = 2; length <= n; length <<= 1) {
      final angle = -2 * pi / length;
      final wRe = cos(angle);
      final wIm = sin(angle);
      for (var start = 0; start < n; start += length) {
        var curRe = 1.0;
        var curIm = 0.0;
        for (var k = 0; k < length ~/ 2; k++) {
          final a = start + k;
          final b = a + length ~/ 2;
          final tRe = re[b] * curRe - im[b] * curIm;
          final tIm = re[b] * curIm + im[b] * curRe;
          re[b] = re[a] - tRe;
          im[b] = im[a] - tIm;
          re[a] += tRe;
          im[a] += tIm;
          final nextRe = curRe * wRe - curIm * wIm;
          curIm = curRe * wIm + curIm * wRe;
          curRe = nextRe;
        }
      }
    }
  }

  static const int _neighbourhood = 3;
  static const int _jpegBlock = 8;
  static const double _localDominance = 4;
}
