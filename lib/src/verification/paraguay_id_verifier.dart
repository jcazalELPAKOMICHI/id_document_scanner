import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui';

import 'package:image/image.dart' as img;

import '../models/document_field.dart';
import '../models/document_side.dart';
import '../models/document_type.dart';
import '../mrz/mrz_constants.dart';
import '../mrz/mrz_data.dart';
import '../mrz/mrz_parser.dart';
import '../ocr/gray_image.dart';
import '../ocr/mrz_reader.dart';
import '../ocr/mrz_reading.dart';
import '../templates/document_template.dart';
import 'document_verification.dart';
import 'header_matcher.dart';
import 'header_reference_regions.dart';
import 'paraguay_front_references.g.dart';
import 'verification_diagnostics.dart';

/// Checks that a cropped card really is a Paraguayan "Cédula de Identidad".
///
/// * Back: reads the MRZ with the built-in OCR and requires valid ICAO check
///   digits, issuing state "PRY" and an identity card document code ("IN"
///   current design, "ID" legacy). Random cards practically never pass this.
/// * Front: compares the fixed header and coat of arms with references from
///   the public specimen (current design only, for now).
class ParaguayIdVerifier {
  const ParaguayIdVerifier({this.minHeaderScore = 0.5, this.mrzReader = const MrzReader()});

  /// Minimum mean correlation of the front header references.
  final double minHeaderScore;
  final MrzReader mrzReader;

  static const String issuingState = 'PRY';
  static const Map<String, DocumentType> documentCodes = {
    MrzConstants.paraguayCurrentCode: .paraguayIdCurrent,
    MrzConstants.paraguayLegacyCode: .paraguayIdLegacy,
  };

  /// Runs off the UI isolate.
  Future<DocumentVerification> verify(Uint8List cardJpeg, DocumentSide side, DocumentType expectedType) =>
      Isolate.run(() {
        final card = GrayImage.fromImage(img.decodeImage(cardJpeg)!);
        return side == .back ? verifyBack(card, expectedType) : verifyFront(card, expectedType);
      });

  DocumentVerification verifyBack(GrayImage card, DocumentType expectedType) {
    // Try the expected design first, then the other one (auto-detect), then
    // the whole lower part of the card: a crop with some background (or a
    // card printed slightly off) moves the MRZ out of the template box.
    final types = [expectedType, ...DocumentType.values.where((type) => type != expectedType)];
    final zones = {
      for (final type in types)
        type.name: DocumentTemplate.of(type, .back).fields[DocumentField.mrz]!.inflate(_mrzZoneMargin),
      _fallbackZoneName: _mrzFallbackZone,
    };
    MrzReading? bestReading;
    final attempts = <String>[];
    for (final MapEntry(key: name, value: zone) in zones.entries) {
      final reading = mrzReader.read(card, zone);
      if (reading != null && reading.isValid) return _checkMrz(_snapIssuingState(reading));
      attempts.add(VerificationDiagnostics.mrzAttempt(name, mrzReader.textLineCount(card, zone), reading));
      if (reading == null) continue;
      if (bestReading == null || reading.confidence > bestReading.confidence) bestReading = reading;
    }
    return DocumentVerification(
      status: .rejected,
      reason: bestReading == null ? .mrzUnreadable : .mrzInvalid,
      mrzLines: bestReading?.lines,
      score: bestReading?.confidence,
      diagnostics: attempts.join('\n'),
    );
  }

  /// The issuing state has no check digit, so a single misread letter
  /// ("PAY") would go unnoticed. When "PRY" is among the OCR candidates of
  /// those 3 positions, read it as "PRY".
  MrzReading _snapIssuingState(MrzReading reading) {
    final line = reading.lines.first;
    const start = MrzConstants.documentCodeEnd;
    final current = line.substring(start, MrzConstants.issuingStateEnd);
    if (current == issuingState) return reading;
    final supported = List.generate(
      issuingState.length,
      (i) => i,
    ).every((i) => reading.candidates.first[start + i].any((match) => match.character == issuingState[i]));
    if (!supported) return reading;
    final lines = [line.replaceRange(start, MrzConstants.issuingStateEnd, issuingState), ...reading.lines.skip(1)];
    return MrzReading(
      lines: lines,
      candidates: reading.candidates,
      mrz: MrzParser.parse(lines),
      confidence: reading.confidence,
    );
  }

  /// Paraguay-issued identity card according to its (valid) MRZ.
  static bool isParaguayanId(MrzData mrz) =>
      mrz.isValid && mrz.issuingState == issuingState && documentCodes.containsKey(mrz.documentCode);

  DocumentVerification _checkMrz(MrzReading reading) {
    final mrz = reading.mrz!;
    final type = documentCodes[mrz.documentCode];
    final paraguayan = isParaguayanId(mrz);
    return DocumentVerification(
      status: paraguayan ? .verified : .rejected,
      reason: paraguayan ? null : .notParaguayanId,
      detectedType: type,
      mrz: mrz,
      mrzLines: reading.lines,
      score: reading.confidence,
    );
  }

  /// Recognises the front of either design by its fixed header, whatever
  /// design was expected (the result says which one it is).
  DocumentVerification verifyFront(GrayImage card, DocumentType expectedType) {
    final normalized = card.resize(HeaderReferenceRegions.cardWidth, HeaderReferenceRegions.cardHeight);
    final regionScores = {
      DocumentType.paraguayIdCurrent: _headerScores(
        normalized,
        paraguayCurrentFrontReferences,
        HeaderReferenceRegions.paraguayCurrentFront,
      ),
      DocumentType.paraguayIdLegacy: _headerScores(
        normalized,
        paraguayLegacyFrontReferences,
        HeaderReferenceRegions.paraguayLegacyFront,
      ),
    };
    final scores = regionScores.map((type, values) => MapEntry(type, values.reduce((a, b) => a + b) / values.length));
    final best = scores.entries.reduce((a, b) => a.value >= b.value ? a : b);
    final diagnostics = VerificationDiagnostics.front(regionScores);
    if (best.value < minHeaderScore) {
      return DocumentVerification(
        status: .rejected,
        reason: .frontNotRecognized,
        score: best.value,
        diagnostics: diagnostics,
      );
    }
    return DocumentVerification(status: .verified, detectedType: best.key, score: best.value, diagnostics: diagnostics);
  }

  /// Correlation of each reference region (title, coat of arms) with [card].
  List<double> _headerScores(GrayImage card, List<(int, int, String)> references, List<Rect> regions) {
    const matcher = HeaderMatcher();
    return List.generate(
      references.length,
      (i) => matcher.match(card, HeaderMatcher.decode(references[i]), regions[i]),
    );
  }

  static const double _mrzZoneMargin = 0.02;
  static const Rect _mrzFallbackZone = Rect.fromLTRB(0, 0.5, 1, 1);
  static const String _fallbackZoneName = 'wide';
}
