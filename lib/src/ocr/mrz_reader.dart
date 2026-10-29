import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

import '../mrz/mrz_constants.dart';
import '../mrz/mrz_parser.dart';
import 'glyph_features.dart';
import 'glyph_match.dart';
import 'gray_image.dart';
import 'mrz_check_group.dart';
import 'mrz_reading.dart';
import 'ocrb_glyph_bank.dart';

/// Pure-Dart OCR for the TD1 machine readable zone.
///
/// The MRZ is printed in OCR-B, a fixed-pitch font with 37 possible symbols,
/// in 3 lines of 30 characters, so it can be read reliably without a general
/// OCR engine: find the 3 text lines, split each into 30 equal cells using the
/// measured character pitch, and match every cell against OCR-B templates.
/// Check digits then confirm the reading (and fix single misreads using the
/// second-best candidates).
class MrzReader {
  const MrzReader({this.bank});

  final OcrbGlyphBank? bank;

  /// Reads the MRZ inside [zone] (normalized to [card]).
  MrzReading? read(GrayImage card, Rect zone) {
    final (scaled, threshold) = _prepare(card, zone);
    final allBands = _textLines(scaled, threshold);
    if (allBands.length < MrzConstants.td1Lines) return null;
    final bands = allBands.sublist(allBands.length - MrzConstants.td1Lines);

    final glyphs = bank ?? OcrbGlyphBank.instance;
    final layouts = <(GrayImage, double, double, List<double>, List<double>)>[];
    for (final (top, bottom) in bands) {
      final layout = _layoutLine(scaled, top, bottom, threshold);
      if (layout == null) return null;
      layouts.add(layout);
    }
    final candidates = _alignLines(layouts).map((layout) {
      final (band, origin, pitch, _, _) = layout;
      return _classifyLine(band, origin, pitch, threshold, glyphs);
    }).toList();
    if (candidates.any((line) => line == null)) return null;

    final lines = candidates.cast<List<List<GlyphMatch>>>();
    final best = lines.map((line) => line.map((cell) => cell.first.character).join()).toList();
    final confidence =
        lines.expand((line) => line).map((cell) => cell.first.score).reduce((a, b) => a + b) /
        (MrzConstants.td1Lines * MrzConstants.td1LineLength);
    final read = _correct(best, lines) ?? best;
    return MrzReading(lines: read, candidates: lines, mrz: MrzParser.parse(read), confidence: confidence);
  }

  /// Wide text lines found inside [zone], for diagnostics: a readable MRZ
  /// needs at least 3.
  int textLineCount(GrayImage card, Rect zone) {
    final (scaled, threshold) = _prepare(card, zone);
    return _textLines(scaled, threshold).length;
  }

  /// [zone] of [card] at the working width, with its ink threshold.
  (GrayImage, int) _prepare(GrayImage card, Rect zone) {
    // Stay off the card border: shadows and the desk show up as tall strokes.
    final crop = card.cropNormalized(
      Rect.fromLTRB(
        max(zone.left, _cardBorder),
        max(zone.top, 0),
        min(zone.right, 1 - _cardBorder),
        min(zone.bottom, 1 - _cardBorder),
      ),
    );
    final scaled = crop.resize(_workWidth, max(1, (crop.height * _workWidth / crop.width).round()));
    return (scaled, scaled.otsuThreshold());
  }

  /// Rows with ink grouped into bands that span most of the zone width. MRZ
  /// lines are the last text on the card, so the caller keeps the 3
  /// bottom-most; shorter data lines above the MRZ are already left out.
  List<(int, int)> _textLines(GrayImage image, int threshold) {
    final counts = List.generate(image.height, (y) {
      var count = 0;
      for (var x = 0; x < image.width; x++) {
        if (image.at(x, y) < threshold) count++;
      }
      return count;
    });
    final peak = counts.reduce(max);
    if (peak == 0) return const [];
    final limit = peak * _rowInkFraction;
    final bands = <(int, int)>[];
    int? start;
    for (var y = 0; y <= image.height; y++) {
      final inked = y < image.height && counts[y] >= limit;
      if (inked) {
        start ??= y;
      } else if (start != null) {
        if (y - start >= _minLineHeight && _inkExtent(image, start, y, threshold) >= _minLineExtent) {
          bands.add((start, y));
        }
        start = null;
      }
    }
    return bands;
  }

  /// Fraction of the width between the first and last inked column of rows
  /// [top]..[bottom].
  double _inkExtent(GrayImage image, int top, int bottom, int threshold) {
    var first = image.width;
    var last = -1;
    for (var x = 0; x < image.width; x++) {
      var inked = 0;
      for (var y = top; y < bottom; y++) {
        if (image.at(x, y) < threshold) inked++;
      }
      if (inked >= _minColumnInk) {
        first = min(first, x);
        last = max(last, x);
      }
    }
    return last < first ? 0 : (last - first) / image.width;
  }

  /// TD1 lines are left aligned and share the pitch. A line whose grid
  /// disagrees with the other two (a border mark taken as its first
  /// character) is moved onto theirs.
  List<(GrayImage, double, double, List<double>, List<double>)> _alignLines(
    List<(GrayImage, double, double, List<double>, List<double>)> layouts,
  ) {
    final origins = layouts.map((layout) => layout.$2).toList()..sort();
    final pitches = layouts.map((layout) => layout.$3).toList()..sort();
    final origin = origins[origins.length ~/ 2];
    final pitch = pitches[pitches.length ~/ 2];
    return layouts.map((layout) {
      final (band, lineOrigin, _, centers, weights) = layout;
      if ((lineOrigin - origin).abs() <= pitch * _alignTolerance) return layout;
      // Start from the shared grid, then refit on this line's own glyphs
      // (the stray mark now falls outside the grid and is ignored).
      var fitted = (origin, pitch);
      for (var pass = 0; pass < _gridPasses; pass++) {
        final fit = _matchGrid(centers, weights, fitted.$1, fitted.$2);
        if (fit == null) break;
        fitted = (fit.$1, fit.$2);
      }
      return (band, fitted.$1, fitted.$2, centers, weights);
    }).toList();
  }

  /// Finds the character grid of one text line: (band image, first cell
  /// centre, pitch).
  (GrayImage, double, double, List<double>, List<double>)? _layoutLine(
    GrayImage image,
    int top,
    int bottom,
    int threshold,
  ) {
    final pad = ((bottom - top) * _linePadding).round();
    final band = image.crop(
      Rect.fromLTRB(0, (top - pad).toDouble(), image.width.toDouble(), (bottom + pad).toDouble()),
    );

    // Character segments: runs of columns with ink. At the line ends, columns
    // inked over the whole band (padding included) are the card border or its
    // shadow: blank them so they cannot merge with the first/last character.
    final columns = List.generate(band.width, (x) {
      var count = 0;
      for (var y = 0; y < band.height; y++) {
        if (band.at(x, y) < threshold) count++;
      }
      return count;
    });
    for (var x = 0; x < band.width; x++) {
      final atEnd = x < band.width * _edgeZone || x >= band.width * (1 - _edgeZone);
      if (!atEnd || columns[x] < band.height * _fullHeightFraction) continue;
      columns[x] = 0;
      for (var y = 0; y < band.height; y++) {
        band.pixels[y * band.width + x] = _paper;
      }
    }
    final segments = <(int, int, int)>[];
    int? start;
    var mass = 0;
    for (var x = 0; x <= band.width; x++) {
      final inked = x < band.width && columns[x] > 0;
      if (inked) {
        start ??= x;
        mass += columns[x];
      } else if (start != null) {
        segments.add((start, x, mass));
        start = null;
        mass = 0;
      }
    }
    if (segments.length < MrzConstants.td1LineLength ~/ 2) return null;
    final masses = segments.map((segment) => segment.$3).toList()..sort();
    final medianMass = masses[masses.length ~/ 2];
    final widths = segments.map((segment) => segment.$2 - segment.$1).toList()..sort();
    final medianWidth = widths[widths.length ~/ 2];
    // Drop specks, and slivers or blobs of background at the zone ends.
    final kept = segments.where((segment) {
      final nearEdge = segment.$1 <= band.width * _edgeZone || segment.$2 >= band.width * (1 - _edgeZone);
      final width = segment.$2 - segment.$1;
      // A narrow mark is a border sliver only if it is also short ("I" and
      // "1" are narrow too, but full height).
      final sliver = width < medianWidth * _sliverWidthFraction && segment.$3 < medianMass * _sliverMassFraction;
      // Glyphs leave the band padding empty; a mark taller than that at the
      // ends is the slanted card border.
      final tall = _inkHeight(band, segment.$1, segment.$2, threshold) >= band.height * _borderHeightFraction;
      final odd = sliver || tall || width > medianWidth * _blobWidthFactor;
      return segment.$3 >= medianMass * _noiseMassFraction && !(nearEdge && odd);
    }).toList();
    if (kept.length < MrzConstants.td1LineLength ~/ 2) return null;

    // Weight by ink height: every glyph (even a narrow "I") is about as tall
    // as the line, while specks and edge marks are not.
    final heights = kept.map((segment) => _inkHeight(band, segment.$1, segment.$2, threshold)).toList();
    final sortedHeights = [...heights]..sort();
    final medianHeight = max(1, sortedHeights[sortedHeights.length ~/ 2]);
    final centers = kept.map((segment) => (segment.$1 + segment.$2) / 2).toList();
    final weights = heights.map((height) => min(1.0, height / medianHeight)).toList();
    final grid = _fitGrid(centers, weights);
    if (grid == null) return null;
    return (band, grid.$1, grid.$2, centers, weights);
  }

  /// Splits [band] into the 30 cells of the grid and classifies each one.
  List<List<GlyphMatch>>? _classifyLine(
    GrayImage band,
    double firstCenter,
    double pitch,
    int threshold,
    OcrbGlyphBank glyphs,
  ) {
    final glyphHeights = <int>[];
    final cells = <GrayImage>[];
    for (var index = 0; index < MrzConstants.td1LineLength; index++) {
      final center = firstCenter + pitch * index;
      final cell = _isolate(
        band.crop(Rect.fromLTRB(center - pitch / 2, 0, center + pitch / 2, band.height.toDouble())),
        threshold,
      );
      cells.add(cell);
      final raster = GlyphFeatures.rasterize(cell, threshold: threshold);
      if (raster != null) glyphHeights.add(raster.$3);
    }
    if (glyphHeights.isEmpty) return null;
    glyphHeights.sort();
    final capHeight = glyphHeights[(glyphHeights.length * _capHeightPercentile).floor()].toDouble();
    return cells.map((cell) {
      final features = GlyphFeatures.fromCell(cell, threshold: threshold, capHeight: capHeight);
      return features == null
          ? const [GlyphMatch(character: MrzConstants.filler, score: 0)]
          : glyphs.classify(features);
    }).toList();
  }

  /// Rows with ink between columns [left] and [right] (first to last).
  int _inkHeight(GrayImage image, int left, int right, int threshold) {
    var first = image.height;
    var last = -1;
    for (var y = 0; y < image.height; y++) {
      for (var x = left; x < right; x++) {
        if (image.at(x, y) < threshold) {
          first = min(first, y);
          last = max(last, y);
          break;
        }
      }
    }
    return last < first ? 0 : last - first + 1;
  }

  /// Fixed-pitch grid of 30 cells (first centre, pitch) that explains the
  /// most segment centres. Anchoring on every segment and keeping the best
  /// fit makes stray ink at the line ends (card edge, specks) harmless.
  /// [weights] (0..1, by ink height) make specks count less than glyphs.
  (double, double)? _fitGrid(List<double> centers, List<double> weights) {
    if (centers.length < 2) return null;
    final diffs = [for (var i = 1; i < centers.length; i++) centers[i] - centers[i - 1]]..sort();
    final median = diffs[diffs.length ~/ 2];
    if (median <= 0) return null;
    // Sub-pixel pitch: mean of the gaps between neighbouring characters (an
    // integer median would drift by several pixels over 30 characters).
    final regular = diffs.where((diff) => (diff - median).abs() <= median * _pitchSpread).toList();
    final roughPitch = regular.reduce((a, b) => a + b) / regular.length;

    (double, double)? best;
    var bestSupport = -1.0;
    var bestError = double.infinity;
    for (final anchor in centers) {
      var origin = anchor;
      var pitch = roughPitch;
      var support = 0.0;
      var error = 0.0;
      // Match, refit by least squares, and match again with the refined grid.
      for (var pass = 0; pass < _gridPasses; pass++) {
        final fit = _matchGrid(centers, weights, origin, pitch);
        if (fit == null) break;
        (origin, pitch, support, error) = fit;
      }
      if (support > bestSupport + _supportEpsilon ||
          (support - bestSupport).abs() <= _supportEpsilon && error < bestError) {
        best = (origin, pitch);
        bestSupport = support;
        bestError = error;
      }
    }
    return best;
  }

  /// Centres lying on the grid (origin + pitch * index, index 0..29): the
  /// least squares grid through them, their weight and residual.
  (double, double, double, double)? _matchGrid(
    List<double> centers,
    List<double> weights,
    double origin,
    double pitch,
  ) {
    const cells = MrzConstants.td1LineLength;
    final indexes = <int>[];
    final matched = <double>[];
    var support = 0.0;
    for (var c = 0; c < centers.length; c++) {
      final index = ((centers[c] - origin) / pitch).round();
      if (index < 0 || index >= cells) continue;
      if ((centers[c] - origin - index * pitch).abs() > pitch * _gridTolerance) continue;
      indexes.add(index);
      matched.add(centers[c]);
      support += weights[c];
    }
    if (matched.length < 2) return null;
    final meanIndex = indexes.reduce((a, b) => a + b) / indexes.length;
    final meanCenter = matched.reduce((a, b) => a + b) / matched.length;
    var covariance = 0.0;
    var variance = 0.0;
    for (var i = 0; i < matched.length; i++) {
      covariance += (indexes[i] - meanIndex) * (matched[i] - meanCenter);
      variance += (indexes[i] - meanIndex) * (indexes[i] - meanIndex);
    }
    if (variance == 0) return null;
    final fittedPitch = covariance / variance;
    final fittedOrigin = meanCenter - fittedPitch * meanIndex;
    var error = 0.0;
    for (var i = 0; i < matched.length; i++) {
      error += (matched[i] - fittedOrigin - fittedPitch * indexes[i]).abs();
    }
    return (fittedOrigin, fittedPitch, support, error);
  }

  /// Keeps only the column run nearest the cell centre, dropping slivers of
  /// the neighbouring characters that fall inside the cell.
  GrayImage _isolate(GrayImage cell, int threshold) {
    final runs = <(int, int)>[];
    int? start;
    for (var x = 0; x <= cell.width; x++) {
      var inked = false;
      if (x < cell.width) {
        for (var y = 0; y < cell.height && !inked; y++) {
          inked = cell.at(x, y) < threshold;
        }
      }
      if (inked) {
        start ??= x;
      } else if (start != null) {
        runs.add((start, x));
        start = null;
      }
    }
    if (runs.length < 2) return cell;
    final center = cell.width / 2;
    double distance((int, int) run) =>
        run.$1 <= center && center < run.$2 ? 0 : min((run.$1 - center).abs(), (run.$2 - center).abs());
    final main = runs.reduce((a, b) => distance(a) <= distance(b) ? a : b);
    // Keep runs touching the main one (a glyph may have small internal gaps).
    final keepLeft = runs
        .where((run) => run.$2 >= main.$1 - _glyphGap && run.$1 <= main.$1)
        .map((run) => run.$1)
        .fold(main.$1, min);
    final keepRight = runs
        .where((run) => run.$1 <= main.$2 + _glyphGap && run.$2 >= main.$2)
        .map((run) => run.$2)
        .fold(main.$2, max);
    final out = GrayImage(width: cell.width, height: cell.height, pixels: Uint8List.fromList(cell.pixels));
    for (var y = 0; y < cell.height; y++) {
      for (var x = 0; x < cell.width; x++) {
        if (x < keepLeft || x >= keepRight) out.pixels[y * cell.width + x] = _paper;
      }
    }
    return out;
  }

  /// Fixes misreads using the check digits, one check group at a time.
  ///
  /// Candidate substitutions are limited to ambiguous positions (runner-up
  /// close to the best, or an OCR-B look-alike pair such as 0/O or 1/I) and
  /// to a few per group: blindly trying everything would satisfy a modulo-10
  /// check by chance. The result is accepted only if every check passes.
  List<String>? _correct(List<String> lines, List<List<List<GlyphMatch>>> candidates) {
    if (MrzParser.parse(lines)?.isValid ?? false) return lines;
    final fixed = [...lines];
    for (final group in _checkGroups) {
      final options = _ambiguousPositions(candidates, group.positions);
      final best = _search(fixed, options, group.isValid);
      if (best == null) continue;
      fixed.setAll(0, best);
    }
    return MrzParser.parse(fixed)?.isValid ?? false ? fixed : null;
  }

  /// Ambiguous positions among [positions] with their alternative characters
  /// (runner-ups close to the best, or its OCR-B look-alike if it is listed).
  List<(int, int, List<String>)> _ambiguousPositions(
    List<List<List<GlyphMatch>>> candidates,
    List<(int, int)> positions,
  ) {
    final options = <(int, int, List<String>, double)>[];
    for (final (line, position) in positions) {
      final cell = candidates[line][position];
      final best = cell.first;
      final alternatives = cell
          .skip(1)
          .where((alternative) {
            final gap = best.score - alternative.score;
            final lookAlike = _lookAlikes[best.character] == alternative.character;
            return gap < _ambiguityMargin || lookAlike && gap < _lookAlikeMargin;
          })
          .map((alternative) => alternative.character)
          .toList();
      final lookAlike = _lookAlikes[best.character];
      if (lookAlike != null && !alternatives.contains(lookAlike) && cell.any((m) => m.character == lookAlike)) {
        alternatives.add(lookAlike);
      }
      if (alternatives.isEmpty) continue;
      options.add((line, position, alternatives, best.score - cell[1].score));
    }
    options.sort((a, b) => a.$4.compareTo(b.$4));
    return options.take(_maxChangesPerGroup).map((option) => (option.$1, option.$2, option.$3)).toList();
  }

  /// Fewest substitutions from [options] that make [isValid] pass.
  List<String>? _search(
    List<String> lines,
    List<(int, int, List<String>)> options,
    bool Function(List<String>) isValid,
  ) {
    if (isValid(lines)) return lines;
    for (var changes = 1; changes <= options.length; changes++) {
      final found = _combine(lines, options, 0, changes, isValid);
      if (found != null) return found;
    }
    return null;
  }

  List<String>? _combine(
    List<String> lines,
    List<(int, int, List<String>)> options,
    int from,
    int changes,
    bool Function(List<String>) isValid,
  ) {
    if (changes == 0) return isValid(lines) ? lines : null;
    for (var i = from; i < options.length; i++) {
      final (line, position, alternatives) = options[i];
      for (final character in alternatives) {
        final attempt = [...lines];
        attempt[line] = attempt[line].replaceRange(position, position + 1, character);
        final found = _combine(attempt, options, i + 1, changes - 1, isValid);
        if (found != null) return found;
      }
    }
    return null;
  }

  /// OCR-B pairs that differ only in small details.
  static const Map<String, String> _lookAlikes = {
    '0': 'O',
    'O': '0',
    '1': 'I',
    'I': '1',
    '5': 'S',
    'S': '5',
    '8': 'B',
    'B': '8',
    '2': 'Z',
    'Z': '2',
    '6': 'G',
    'G': '6',
    '7': 'T',
    'T': '7',
    'D': '0',
  };

  /// TD1 check digit groups: what each check digit covers.
  static final List<MrzCheckGroup> _checkGroups = [
    MrzCheckGroup.of(
      0,
      MrzConstants.issuingStateEnd,
      MrzConstants.documentNumberCheck + 1,
      (mrz) => mrz.documentNumberValid,
    ),
    MrzCheckGroup.of(1, 0, MrzConstants.birthDateCheck + 1, (mrz) => mrz.birthDateValid),
    MrzCheckGroup.of(1, MrzConstants.expiryDateStart, MrzConstants.expiryDateCheck + 1, (mrz) => mrz.expiryDateValid),
    MrzCheckGroup(
      positions: [
        for (var p = MrzConstants.documentNumberCheck + 1; p < MrzConstants.optionalData1End; p++) (0, p),
        for (var p = MrzConstants.nationalityEnd; p <= MrzConstants.compositeCheck; p++) (1, p),
      ],
      check: (mrz) => mrz.compositeValid,
    ),
  ];

  static const int _workWidth = 900;
  static const double _gridTolerance = 0.35;
  static const double _alignTolerance = 0.5;
  static const double _pitchSpread = 0.2;
  static const int _gridPasses = 2;
  static const double _supportEpsilon = 0.01;
  static const double _edgeZone = 0.03;
  static const double _blobWidthFactor = 1.8;
  static const double _sliverMassFraction = 0.3;
  static const double _borderHeightFraction = 0.9;
  static const double _fullHeightFraction = 0.95;
  static const double _cardBorder = 0.012;
  static const double _sliverWidthFraction = 0.35;
  static const int _glyphGap = 1;
  static const int _paper = 255;
  static const double _rowInkFraction = 0.2;
  static const int _minLineHeight = 6;
  static const double _minLineExtent = 0.6;
  static const int _minColumnInk = 2;
  static const double _linePadding = 0.12;
  static const double _noiseMassFraction = 0.15;
  static const double _capHeightPercentile = 0.6;
  static const double _ambiguityMargin = 0.06;
  static const double _lookAlikeMargin = 0.2;
  static const int _maxChangesPerGroup = 4;
}
