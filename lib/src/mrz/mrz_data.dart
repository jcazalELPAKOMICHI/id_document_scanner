import 'mrz_sex.dart';

/// Data read from a TD1 machine readable zone, with the result of each
/// ICAO check digit.
class MrzData {
  const MrzData({
    required this.lines,
    required this.documentCode,
    required this.issuingState,
    required this.documentNumber,
    required this.optionalData1,
    required this.birthDate,
    required this.sex,
    required this.expiryDate,
    required this.nationality,
    required this.optionalData2,
    required this.surnames,
    required this.givenNames,
    required this.documentNumberValid,
    required this.birthDateValid,
    required this.expiryDateValid,
    required this.compositeValid,
  });

  /// The 3 lines actually validated (after OCR corrections).
  final List<String> lines;
  final String documentCode;
  final String issuingState;
  final String documentNumber;
  final String optionalData1;
  final DateTime? birthDate;
  final MrzSex sex;
  final DateTime? expiryDate;
  final String nationality;
  final String optionalData2;
  final String surnames;
  final String givenNames;
  final bool documentNumberValid;
  final bool birthDateValid;
  final bool expiryDateValid;
  final bool compositeValid;

  /// Every check digit matches: the MRZ was read without errors.
  bool get isValid => documentNumberValid && birthDateValid && expiryDateValid && compositeValid;

  bool isExpiredAt(DateTime date) => expiryDate?.isBefore(date) ?? true;
}
