import 'package:flutter_test/flutter_test.dart';
import 'package:id_document_scanner/id_document_scanner.dart';

void main() {
  // MRZ printed on the public specimen of the current Paraguayan card.
  const specimen = [
    'INPRYAA000895844587123<07<<<<<',
    '8411268F3304031PRY<<<<<<<<<<<5',
    'MARTINIEZ<<MARIA<ALEJANDRA<<<<',
  ];

  test('check digit follows ICAO 9303', () {
    expect(MrzCheckDigit.of('AA0008958'), 4);
    expect(MrzCheckDigit.of('841126'), 8);
    expect(MrzCheckDigit.of('<<<'), 0);
  });

  test('parses and validates the specimen', () {
    final mrz = MrzParser.parse(specimen)!;
    expect(mrz.isValid, isTrue);
    expect(mrz.documentCode, MrzConstants.paraguayCurrentCode);
    expect(mrz.issuingState, 'PRY');
    expect(mrz.documentNumber, 'AA0008958');
    expect(mrz.optionalData1, '4587123 07');
    expect(mrz.birthDate, DateTime(1984, 11, 26));
    expect(mrz.sex, MrzSex.female);
    expect(mrz.expiryDate, DateTime(2033, 4, 3));
    expect(mrz.nationality, 'PRY');
    expect(mrz.surnames, 'MARTINIEZ');
    expect(mrz.givenNames, 'MARIA ALEJANDRA');
  });

  test('fixes OCR look-alikes in digit-only fields', () {
    final ocr = [specimen[0], ' 84II268F33O4O3IPRY«<<<<<<<<<<S ', specimen[2].toLowerCase()];
    final mrz = MrzParser.parse(ocr)!;
    expect(mrz.isValid, isTrue);
    expect(mrz.birthDate, DateTime(1984, 11, 26));
  });

  test('a misread character fails its check digit', () {
    final tampered = [specimen[0].replaceFirst('8958', '8959'), specimen[1], specimen[2]];
    final mrz = MrzParser.parse(tampered)!;
    expect(mrz.documentNumberValid, isFalse);
    expect(mrz.compositeValid, isFalse);
    expect(mrz.isValid, isFalse);
  });

  test('rejects text that is not a TD1 MRZ', () {
    expect(MrzParser.parse(['ABC', 'DEF']), isNull);
    expect(MrzParser.parse([specimen[0], specimen[1], 'SHORT']), isNull);
  });
}
