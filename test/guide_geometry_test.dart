import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:id_document_scanner/id_document_scanner.dart';

void main() {
  test('guide keeps the ID-1 aspect ratio', () {
    final guide = GuideGeometry.guideRect(const Size(400, 800));
    expect(guide.width / guide.height, closeTo(ScannerConstants.idCardAspectRatio, 1e-9));
    expect(guide.center.dx, 200);
  });

  test('maps through a cover-fitted preview and back', () {
    const viewport = Size(400, 800);
    const preview = Size(720, 1280); // wider than the viewport: cropped left/right
    final guide = GuideGeometry.guideRect(viewport);
    final normalized = GuideGeometry.toImageRect(guide, viewport, preview);

    expect(normalized.center.dx, closeTo(0.5, 1e-9));
    expect(normalized.width, lessThan(guide.width / viewport.width));
    final back = GuideGeometry.toWidgetRect(normalized, viewport, preview);
    expect(back.left, closeTo(guide.left, 1e-9));
    expect(back.bottom, closeTo(guide.bottom, 1e-9));
  });
}
