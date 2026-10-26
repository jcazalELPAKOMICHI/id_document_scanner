import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

import '../models/luma_frame.dart';
import 'luma_statistics.dart';

/// Small upright luminance image resampled from the guide area of a frame.
class LumaGrid {
  LumaGrid({required this.width, required this.height, required this.values});

  /// Samples [region] of the upright frame into a [width] x [height] grid,
  /// averaging 4 points per cell when [boxFilter] is set.
  factory LumaGrid.sample(LumaFrame frame, Rect region, int width, int height, {bool boxFilter = true}) {
    final values = Uint8List(width * height);
    final cellWidth = region.width / width;
    final cellHeight = region.height / height;
    final du = cellWidth / 4;
    final dv = cellHeight / 4;
    for (var y = 0; y < height; y++) {
      final v = region.top + (y + 0.5) * cellHeight;
      for (var x = 0; x < width; x++) {
        final u = region.left + (x + 0.5) * cellWidth;
        values[y * width + x] = boxFilter
            ? (frame.sampleUpright(u - du, v - dv) +
                      frame.sampleUpright(u + du, v - dv) +
                      frame.sampleUpright(u - du, v + dv) +
                      frame.sampleUpright(u + du, v + dv)) >>
                  2
            : frame.sampleUpright(u, v);
      }
    }
    return LumaGrid(width: width, height: height, values: values);
  }

  final int width;
  final int height;
  final Uint8List values;

  int at(int x, int y) => values[y.clamp(0, height - 1) * width + x.clamp(0, width - 1)];

  LumaStatistics statistics(Rect area, int glareLuma) {
    final left = max(1, area.left.round());
    final top = max(1, area.top.round());
    final right = min(width - 2, area.right.round());
    final bottom = min(height - 2, area.bottom.round());
    var count = 0;
    var sum = 0.0;
    var glare = 0;
    var lapSum = 0.0;
    var lapSquares = 0.0;
    for (var y = top; y <= bottom; y++) {
      for (var x = left; x <= right; x++) {
        final value = at(x, y);
        sum += value;
        if (value >= glareLuma) glare++;
        final laplacian = 4 * value - at(x - 1, y) - at(x + 1, y) - at(x, y - 1) - at(x, y + 1);
        lapSum += laplacian;
        lapSquares += laplacian * laplacian;
        count++;
      }
    }
    if (count == 0) return const LumaStatistics(mean: 0, glareRatio: 0, sharpness: 0);
    final lapMean = lapSum / count;
    return LumaStatistics(
      mean: sum / count,
      glareRatio: glare / count,
      sharpness: lapSquares / count - lapMean * lapMean,
    );
  }
}
