/// ICAO 9303 TD1 layout (ID cards: 3 lines of 30 characters).
abstract final class MrzConstants {
  static const int td1Lines = 3;
  static const int td1LineLength = 30;
  static const String filler = '<';
  static const List<int> checkWeights = [7, 3, 1];
  static const int checkModulo = 10;
  static const int letterValueOffset = 10;

  // Line 1
  static const int documentCodeStart = 0;
  static const int documentCodeEnd = 2;
  static const int issuingStateEnd = 5;
  static const int documentNumberEnd = 14;
  static const int documentNumberCheck = 14;
  static const int optionalData1End = 30;

  // Line 2
  static const int birthDateEnd = 6;
  static const int birthDateCheck = 6;
  static const int sex = 7;
  static const int expiryDateStart = 8;
  static const int expiryDateEnd = 14;
  static const int expiryDateCheck = 14;
  static const int nationalityStart = 15;
  static const int nationalityEnd = 18;
  static const int optionalData2End = 29;
  static const int compositeCheck = 29;

  static const String nameSeparator = '<<';

  static const int centuryLength = 100;

  /// Document codes of the Paraguayan cards.
  static const String paraguayCurrentCode = 'IN';
  static const String paraguayLegacyCode = 'ID';
}
