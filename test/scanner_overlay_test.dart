import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:id_document_scanner/id_document_scanner.dart';
import 'package:id_document_scanner/src/widgets/document_flip_transition.dart';
import 'package:id_document_scanner/src/widgets/scanner_capture_feedback.dart';

void main() {
  const style = ScannerOverlayStyle();
  const messages = ScannerMessages();
  final guide = GuideGeometry.guideRect(const Size(800, 600));

  Widget overlay(ScanStatus status, {double progress = 0}) => MaterialApp(
    home: Stack(
      children: [
        ScannerOverlay(
          state: ScannerOverlayState(
            status: status,
            message: messages.of(status),
            guide: guide,
            frameColor: style.colorFor(status),
            analysis: null,
            progress: progress,
          ),
          style: style,
          title: 'Title',
        ),
        ScannerCaptureFeedback(status: status, guide: guide, style: style),
      ],
    ),
  );

  testWidgets('shows the message of every status while animating', (tester) async {
    for (final status in ScanStatus.values) {
      await tester.pumpWidget(overlay(status, progress: status == .ready ? 0.5 : 0));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text(messages.of(status)), findsOneWidget);
    }
  });

  testWidgets('capture shows the check mark', (tester) async {
    await tester.pumpWidget(overlay(.ready));
    await tester.pumpWidget(overlay(.capturing));
    await tester.pumpWidget(overlay(.captured));
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
  });

  testWidgets('switching side plays the flip hint and then hides it', (tester) async {
    Widget flip(DocumentSide side) => MaterialApp(
      home: DocumentFlipTransition(side: side, guide: guide, message: messages.flipToBack, style: style),
    );
    await tester.pumpWidget(flip(.front));
    expect(find.text(messages.flipToBack), findsNothing);
    await tester.pumpWidget(flip(.back));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text(messages.flipToBack), findsOneWidget);
    await tester.pump(ScannerConstants.flipDuration);
    expect(find.text(messages.flipToBack), findsNothing);
  });
}
