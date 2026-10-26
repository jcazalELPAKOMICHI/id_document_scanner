import 'mrz_check_digit.dart';
import 'mrz_constants.dart';
import 'mrz_data.dart';
import 'mrz_sex.dart';

/// Parses and validates a TD1 MRZ (ID cards), tolerating the usual OCR
/// confusions: in fields that can only hold digits, letters that look like
/// digits are corrected before validating.
abstract final class MrzParser {
  /// Returns null when [rawLines] cannot be a TD1 MRZ (wrong count/length).
  static MrzData? parse(List<String> rawLines) {
    final lines = rawLines.map(normalizeLine).where((line) => line.isNotEmpty).toList();
    if (lines.length != MrzConstants.td1Lines) return null;
    if (lines.any((line) => line.length != MrzConstants.td1LineLength)) return null;

    final line1 = _fixDigits(lines[0], const {MrzConstants.documentNumberCheck});
    final line2 = _fixDigits(lines[1], _line2DigitPositions);
    final line3 = lines[2];

    final documentNumber = line1.substring(MrzConstants.issuingStateEnd, MrzConstants.documentNumberEnd);
    final birth = line2.substring(0, MrzConstants.birthDateEnd);
    final expiry = line2.substring(MrzConstants.expiryDateStart, MrzConstants.expiryDateEnd);
    final composite =
        line1.substring(MrzConstants.issuingStateEnd) +
        line2.substring(0, MrzConstants.sex) +
        line2.substring(MrzConstants.expiryDateStart, MrzConstants.nationalityStart) +
        line2.substring(MrzConstants.nationalityEnd, MrzConstants.optionalData2End);
    final names = line3.split(MrzConstants.nameSeparator);

    return MrzData(
      lines: [line1, line2, line3],
      documentCode: _clean(line1.substring(MrzConstants.documentCodeStart, MrzConstants.documentCodeEnd)),
      issuingState: _clean(line1.substring(MrzConstants.documentCodeEnd, MrzConstants.issuingStateEnd)),
      documentNumber: _clean(documentNumber),
      optionalData1: _clean(line1.substring(MrzConstants.documentNumberCheck + 1, MrzConstants.optionalData1End)),
      birthDate: _date(birth, isExpiry: false),
      sex: MrzSex.fromCode(line2[MrzConstants.sex]),
      expiryDate: _date(expiry, isExpiry: true),
      nationality: _clean(line2.substring(MrzConstants.nationalityStart, MrzConstants.nationalityEnd)),
      optionalData2: _clean(line2.substring(MrzConstants.nationalityEnd, MrzConstants.optionalData2End)),
      surnames: _clean(names.first),
      givenNames: _clean(names.skip(1).join(MrzConstants.filler)),
      documentNumberValid: MrzCheckDigit.matches(documentNumber, line1[MrzConstants.documentNumberCheck]),
      birthDateValid: MrzCheckDigit.matches(birth, line2[MrzConstants.birthDateCheck]),
      expiryDateValid: MrzCheckDigit.matches(expiry, line2[MrzConstants.expiryDateCheck]),
      compositeValid: MrzCheckDigit.matches(composite, line2[MrzConstants.compositeCheck]),
    );
  }

  /// Uppercases, removes spaces and maps look-alike symbols to the filler.
  static String normalizeLine(String line) =>
      line.toUpperCase().replaceAll(_whitespace, '').replaceAll(_fillerLookAlikes, MrzConstants.filler);

  static String _fixDigits(String line, Set<int> positions) {
    final chars = line.split('');
    for (final position in positions) {
      chars[position] = _letterToDigit[chars[position]] ?? chars[position];
    }
    return chars.join();
  }

  static String _clean(String value) => value.replaceAll(MrzConstants.filler, ' ').trim().replaceAll(_spaces, ' ');

  static DateTime? _date(String yymmdd, {required bool isExpiry}) {
    final value = int.tryParse(yymmdd);
    if (value == null) return null;
    final yy = int.parse(yymmdd.substring(0, 2));
    final month = int.parse(yymmdd.substring(2, 4));
    final day = int.parse(yymmdd.substring(4, 6));
    final currentYear = DateTime.now().year % MrzConstants.centuryLength;
    final currentCentury = DateTime.now().year - currentYear;
    // Expiry dates are in the near future; birth dates are never in the future.
    final century = isExpiry || yy <= currentYear ? currentCentury : currentCentury - MrzConstants.centuryLength;
    final date = DateTime(century + yy, month, day);
    return date.month == month && date.day == day ? date : null;
  }

  /// Positions of line 2 that can only be digits (dates and check digits).
  static final Set<int> _line2DigitPositions = {
    ...List.generate(MrzConstants.birthDateCheck + 1, (i) => i),
    ...List.generate(
      MrzConstants.expiryDateCheck - MrzConstants.expiryDateStart + 1,
      (i) => MrzConstants.expiryDateStart + i,
    ),
    MrzConstants.compositeCheck,
  };

  static const Map<String, String> _letterToDigit = {
    'O': '0',
    'Q': '0',
    'D': '0',
    'I': '1',
    'L': '1',
    'Z': '2',
    'S': '5',
    'G': '6',
    'B': '8',
  };

  static final RegExp _whitespace = RegExp(r'\s');
  static final RegExp _spaces = RegExp(r' +');
  static final RegExp _fillerLookAlikes = RegExp(r'[«‹≤(\[{]');
}
