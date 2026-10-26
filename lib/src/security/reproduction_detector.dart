import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'reproduction_check.dart';
import 'spectrum.dart';

/// Detects photos of a screen or of a printed copy of the card, without
/// asking the user for anything.
///
/// A camera pointed at a monitor or phone records the display's pixel grid
/// (and its R/G/B sub-pixels), which aliases into moiré; a printout carries
/// the printer's halftone dot screen. Both are strictly periodic, so they
/// appear as sharp, isolated peaks in the high-frequency spectrum, in
/// brightness and in colour. The physical card's security print (guilloche
/// curves) and the sensor noise spread their energy instead.
class ReproductionDetector {
  const ReproductionDetector({
    this.chromaThreshold = 1500,
    this.lumaThreshold = 25000,
    this.patchSize = 128,
    this.patchesPerAxis = 4,
  });

  /// Colour score from which the capture is a reproduction. Measured on
  /// simulations: real card photos 80..420, colour prints 3400..4600, screens
  /// above 250 000.
  final double chromaThreshold;

  /// Brightness score from which it is a reproduction (screens only: the
  /// card's own security print already scores up to a few thousand).
  final double lumaThreshold;
  final int patchSize;
  final int patchesPerAxis;

  Future<ReproductionCheck> check(Uint8List cardJpeg) => Isolate.run(() => analyze(img.decodeImage(cardJpeg)!));

  ReproductionCheck analyze(img.Image card) {
    final rgb = card.convert(numChannels: _rgbChannels).getBytes(order: img.ChannelOrder.rgb);
    final luma = <double>[];
    final chroma = <double>[];
    final usableWidth = card.width - patchSize;
    final usableHeight = card.height - patchSize;
    if (usableWidth <= 0 || usableHeight <= 0) return ReproductionCheck.none;
    for (var py = 0; py < patchesPerAxis; py++) {
      for (var px = 0; px < patchesPerAxis; px++) {
        final left = (usableWidth * (px + 0.5) / patchesPerAxis).round();
        final top = (usableHeight * (py + 0.5) / patchesPerAxis).round();
        final y = Float64List(patchSize * patchSize);
        final c = Float64List(patchSize * patchSize);
        for (var row = 0; row < patchSize; row++) {
          for (var col = 0; col < patchSize; col++) {
            final i = ((top + row) * card.width + left + col) * _rgbChannels;
            final r = rgb[i].toDouble(), g = rgb[i + 1].toDouble(), b = rgb[i + 2].toDouble();
            y[row * patchSize + col] = 0.299 * r + 0.587 * g + 0.114 * b;
            // Opponent colour: R/G/B sub-pixel stripes alternate here.
            c[row * patchSize + col] = r - b;
          }
        }
        luma.add(
          Spectrum.of(y, patchSize).peakProminence(minRadius: _minRadius, maxRadius: _maxRadius, floor: _powerFloor),
        );
        chroma.add(
          Spectrum.of(c, patchSize).peakProminence(minRadius: _minRadius, maxRadius: _maxRadius, floor: _powerFloor),
        );
      }
    }
    final lumaScore = _robust(luma);
    final chromaScore = _robust(chroma);
    return ReproductionCheck(
      lumaScore: lumaScore,
      chromaScore: chromaScore,
      isReproduction: chromaScore >= chromaThreshold || lumaScore >= lumaThreshold,
    );
  }

  /// A reproduction covers the whole card, so require the pattern in most
  /// patches (a high percentile, not the single best one).
  double _robust(List<double> values) {
    final sorted = [...values]..sort();
    return sorted[(sorted.length * _percentile).floor()];
  }

  static const double _minRadius = 0.3;
  static const double _maxRadius = 1.0;
  static const double _percentile = 0.4;

  /// About the spectrum of camera noise (sigma ~2 levels) on a 128 px patch.
  static const double _powerFloor = 5000;
  static const int _rgbChannels = 3;
}
