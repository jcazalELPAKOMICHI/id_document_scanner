import '../models/document_type.dart';
import '../mrz/mrz_constants.dart';
import '../ocr/mrz_reading.dart';

/// Short, non-personal summaries of a verification, shown with
/// `showDebugInfo` to calibrate on real cards. MRZ characters are masked
/// (`A` letter, `9` digit, `<` filler) and the names line is left out, so
/// the text can be shared without exposing the holder's data.
abstract final class VerificationDiagnostics {
  /// Per design: mean header score and the score of each reference region.
  static String front(Map<DocumentType, List<double>> scores) => scores.entries
      .map((entry) {
        final parts = entry.value.map(_score).join('/');
        final mean = entry.value.reduce((a, b) => a + b) / entry.value.length;
        return '${_label(entry.key)} ${_score(mean)} ($parts)';
      })
      .join(' · ');

  /// One MRZ attempt: how many wide lines were found, or what was read.
  static String mrzAttempt(String zone, int lineCount, MrzReading? reading) {
    if (reading == null) return '$zone: $lineCount lines';
    final mrz = reading.mrz;
    final checks = mrz == null
        ? 'unparsed'
        : 'doc${_check(mrz.documentNumberValid)} birth${_check(mrz.birthDateValid)} '
              'exp${_check(mrz.expiryDateValid)} all${_check(mrz.compositeValid)} '
              '${mrz.documentCode}/${mrz.issuingState}';
    final pattern = reading.lines.take(_maskedLines).map(_mask).join(' ');
    return '$zone: conf ${_score(reading.confidence)} $checks $pattern';
  }

  static String _mask(String line) => line.split('').map((character) {
    if (character == MrzConstants.filler) return character;
    return _digit.hasMatch(character) ? '9' : 'A';
  }).join();

  static String _label(DocumentType type) => type == .paraguayIdCurrent ? 'cur' : 'leg';

  static String _score(double value) => value.toStringAsFixed(2);

  static String _check(bool valid) => valid ? '✓' : '✗';

  /// Lines 1 and 2 (document code, number, dates); line 3 holds the names.
  static const int _maskedLines = 2;
  static final RegExp _digit = RegExp('[0-9]');
}
