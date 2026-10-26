import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:id_document_scanner/id_document_scanner.dart';
import 'package:image/image.dart' as img;

import 'paraguay_id_verifier_test.dart' as verifier_test;

DocumentCapture captureOf(
  DocumentSide side, {
  bool precise = true,
  Uint8List? image,
  ReproductionCheck reproduction = ReproductionCheck.none,
}) => DocumentCapture(
  reproduction: reproduction,
  documentType: .paraguayIdCurrent,
  side: side,
  photoPath: 'photo.jpg',
  cardImage: image ?? Uint8List(1),
  corners: precise
      ? const CardCorners(
          topLeft: Offset(0.1, 0.3),
          topRight: Offset(0.9, 0.3),
          bottomRight: Offset(0.9, 0.6),
          bottomLeft: Offset(0.1, 0.6),
        )
      : null,
  analysis: FrameAnalysis.empty,
);

void main() {
  test('accepted front moves to the back, accepted back completes', () async {
    final seen = <DocumentSide>[];
    final controller = IdDocumentScannerController(
      verifyDocument: false,
      validator: (capture) {
        seen.add(capture.side);
        return CaptureValidation.accepted(data: 'id-${capture.side.name}');
      },
    );
    final result = controller.results.first;

    await controller.submitCapture(captureOf(.front));
    expect(controller.side, DocumentSide.back);
    expect(controller.status, ScanStatus.searching);

    await controller.submitCapture(captureOf(.back));
    expect(controller.status, ScanStatus.completed);
    final scan = await result;
    expect(seen, [DocumentSide.front, DocumentSide.back]);
    expect(scan.front, isNotNull);
    expect(scan.validationData[DocumentSide.back], 'id-back');
    controller.dispose();
  });

  test('a rejection shows its message and scans the same side again', () async {
    final statuses = <ScanStatus>[];
    final controller = IdDocumentScannerController(
      verifyDocument: false,
      validator: (_) => const CaptureValidation.rejected(message: 'Foto borrosa'),
    );
    controller.addListener(() => statuses.add(controller.status));

    final pending = controller.submitCapture(captureOf(.front));
    await Future<void>.delayed(Duration.zero);
    expect(controller.status, ScanStatus.rejected);
    expect(controller.rejectionMessage, 'Foto borrosa');
    await pending;
    expect(controller.side, DocumentSide.front);
    expect(controller.status, ScanStatus.searching);
    expect(statuses, containsAllInOrder([ScanStatus.validating, ScanStatus.rejected, ScanStatus.searching]));
    controller.dispose();
  });

  test('validator errors count as rejections', () async {
    final controller = IdDocumentScannerController(
      verifyDocument: false,
      validator: (_) => throw StateError('network down'),
    );
    final pending = controller.submitCapture(captureOf(.front));
    await Future<void>.delayed(Duration.zero);
    expect(controller.status, ScanStatus.rejected);
    await pending;
    controller.dispose();
  });

  test('imprecise crops never reach the validator', () async {
    var called = false;
    final controller = IdDocumentScannerController(
      verifyDocument: false,
      validator: (_) {
        called = true;
        return const CaptureValidation.accepted();
      },
    );
    final pending = controller.submitCapture(captureOf(.front, precise: false));
    await Future<void>.delayed(Duration.zero);
    expect(controller.status, ScanStatus.rejected);
    expect(controller.cropFailed, isTrue);
    await pending;
    expect(called, isFalse);
    controller.dispose();
  });

  test('without autoAdvance the host decides when to continue', () async {
    final controller = IdDocumentScannerController(verifyDocument: false, autoAdvance: false, sides: const [.back]);
    final result = controller.results.first;
    await controller.submitCapture(captureOf(.back));
    expect(controller.status, ScanStatus.captured);
    await controller.nextSide();
    expect(controller.status, ScanStatus.completed);
    expect((await result).back, isNotNull);
    controller.dispose();
  });

  reproductionTests();

  group('Paraguayan ID verification', () {
    Uint8List jpeg(img.Image image) => img.encodeJpg(image, quality: 90);

    test('a real front and back go through, with the MRZ data', () async {
      final seen = <DocumentCapture>[];
      final controller = IdDocumentScannerController(
        validator: (capture) {
          seen.add(capture);
          return const CaptureValidation.accepted();
        },
      );
      final result = controller.results.first;
      await controller.submitCapture(
        captureOf(.front, image: jpeg(verifier_test.load('paraguay_id_current_specimen.webp'))),
      );
      await controller.submitCapture(
        captureOf(.back, image: jpeg(verifier_test.load('paraguay_id_current_back_specimen.webp'))),
      );
      await result;
      expect(seen.map((capture) => capture.verification!.status), everyElement(DocumentVerificationStatus.verified));
      expect(seen.last.verification!.mrz!.documentNumber, 'AA0008958');
      controller.dispose();
    });

    test('another card is rejected before reaching the validator', () async {
      var called = false;
      final controller = IdDocumentScannerController(
        validator: (_) {
          called = true;
          return const CaptureValidation.accepted();
        },
      );
      final pending = controller.submitCapture(captureOf(.front, image: jpeg(verifier_test.otherCard())));
      await pumpUntil(() => controller.status == ScanStatus.rejected);
      expect(controller.rejectionReason, DocumentRejectionReason.frontNotRecognized);
      await pending;
      expect(called, isFalse);
      controller.dispose();
    });
  });
}

void reproductionTests() {
  test('a photo of a screen is rejected before verification and validation', () async {
    var called = false;
    final controller = IdDocumentScannerController(
      validator: (_) {
        called = true;
        return const CaptureValidation.accepted();
      },
    );
    final pending = controller.submitCapture(
      captureOf(.front, reproduction: const ReproductionCheck(lumaScore: 9e4, chromaScore: 4e5, isReproduction: true)),
    );
    await pumpUntil(() => controller.status == ScanStatus.rejected);
    expect(controller.reproductionDetected, isTrue);
    await pending;
    expect(called, isFalse);
    controller.dispose();
  });
}

Future<void> pumpUntil(bool Function() condition) async {
  for (var i = 0; i < 200 && !condition(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}
