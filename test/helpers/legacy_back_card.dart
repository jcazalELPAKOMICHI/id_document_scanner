import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:id_document_scanner/id_document_scanner.dart';
import 'package:image/image.dart' as img;

/// Fictional person: valid TD1 MRZ of the previous Paraguayan design ("ID").
List<String> fictionalLegacyMrz() {
  String pad(String value) => value.padRight(MrzConstants.td1LineLength, '<');
  const number = '1234567<<';
  final line1 = pad('IDPRY$number${MrzCheckDigit.of(number)}');
  const birth = '900215';
  const expiry = '310630';
  final partial = '$birth${MrzCheckDigit.of(birth)}M$expiry${MrzCheckDigit.of(expiry)}PRY'.padRight(29, '<');
  final composite = line1.substring(5) + partial.substring(0, 7) + partial.substring(8, 15) + partial.substring(18, 29);
  final line2 = '$partial${MrzCheckDigit.of(composite)}';
  return [line1, line2, pad('PEREZ<<JUAN<CARLOS')];
}

/// Renders a previous-design back (barcode on top, data lines, OCR-B MRZ at
/// the bottom) at camera-like resolution. Needs the OCR-B font from tool/.
Future<img.Image> legacyBackCard() async {
  final loader = FontLoader('OCRB')
    ..addFont(Future.value(ByteData.sublistView(File('tool/fonts/ocrb10.otf').readAsBytesSync())));
  await loader.load();
  const width = 1012.0, height = 638.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)
    ..drawRect(const Rect.fromLTWH(0, 0, width, height), Paint()..color = const Color(0xFFDCE6F0));
  // PDF417-like barcode block.
  for (var x = 20.0; x < width - 20; x += 7) {
    canvas.drawRect(Rect.fromLTWH(x, 8, (x.toInt() * 13 % 5) + 1.0, 236), Paint()..color = const Color(0xFF111111));
  }
  // Data lines above the MRZ (shorter than the MRZ).
  for (final (y, w) in [(318.0, 620.0), (352.0, 300.0), (384.0, 540.0)]) {
    canvas.drawRect(Rect.fromLTWH(20, y, w, 14), Paint()..color = const Color(0xFF333344));
  }
  final mrz = fictionalLegacyMrz();
  for (var i = 0; i < mrz.length; i++) {
    TextPainter(
        text: TextSpan(
          text: mrz[i],
          style: const TextStyle(fontFamily: 'OCRB', fontSize: 40, color: Color(0xFF111111), letterSpacing: 3.6),
        ),
        textDirection: TextDirection.ltr,
      )
      ..layout()
      ..paint(canvas, Offset(22, 430 + i * 55.0));
  }
  final image = await recorder.endRecording().toImage(width.toInt(), height.toInt());
  final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer;
  return img.Image.fromBytes(width: width.toInt(), height: height.toInt(), bytes: bytes, numChannels: 4);
}
