import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:id_document_scanner/id_document_scanner.dart';
import 'package:id_document_scanner/src/ocr/gray_image.dart';
import 'package:image/image.dart' as img;

void main() {
  const specimenMrz = [
    'INPRYAA000895844587123<07<<<<<',
    '8411268F3304031PRY<<<<<<<<<<<5',
    'MARTINIEZ<<MARIA<ALEJANDRA<<<<',
  ];
  final back = img.decodeWebP(File('test/fixtures/paraguay_id_current_back_specimen.webp').readAsBytesSync())!;
  final zone = ParaguayIdTemplates.currentBack.fields[DocumentField.mrz]!;

  test('reads the MRZ printed on the back specimen', () {
    final reading = const MrzReader().read(GrayImage.fromImage(back), zone)!;
    printOnFailure(reading.lines.join('\n'));
    printOnFailure(
      reading.candidates.first
          .skip(13)
          .take(13)
          .map((c) => c.map((m) => '${m.character}${m.score.toStringAsFixed(2)}').join('/'))
          .join(' '),
    );
    expect(reading.lines, specimenMrz);
    expect(reading.isValid, isTrue);
  });
}
