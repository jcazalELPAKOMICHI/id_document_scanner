import 'mrz_constants.dart';

/// ICAO 9303 check digit (weights 7-3-1, modulo 10).
abstract final class MrzCheckDigit {
  static int of(String field) {
    var sum = 0;
    for (var i = 0; i < field.length; i++) {
      sum += valueOf(field.codeUnitAt(i)) * MrzConstants.checkWeights[i % MrzConstants.checkWeights.length];
    }
    return sum % MrzConstants.checkModulo;
  }

  static bool matches(String field, String checkDigit) => int.tryParse(checkDigit) == of(field);

  static int valueOf(int codeUnit) => switch (codeUnit) {
    >= _zero && <= _nine => codeUnit - _zero,
    >= _upperA && <= _upperZ => codeUnit - _upperA + MrzConstants.letterValueOffset,
    _ => 0,
  };

  static const int _zero = 0x30;
  static const int _nine = 0x39;
  static const int _upperA = 0x41;
  static const int _upperZ = 0x5A;
}
