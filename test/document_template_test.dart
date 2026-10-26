import 'package:flutter_test/flutter_test.dart';
import 'package:id_document_scanner/id_document_scanner.dart';

void main() {
  test('every type and side has a template with fields inside the card', () {
    for (final type in DocumentType.values) {
      for (final side in DocumentSide.values) {
        final template = DocumentTemplate.of(type, side);
        expect(template.type, type);
        expect(template.side, side);
        expect(template.fields, isNotEmpty);
        for (final rect in template.fields.values) {
          expect(rect.left >= 0 && rect.top >= 0 && rect.right <= 1 && rect.bottom <= 1, isTrue, reason: '$type $side');
        }
      }
    }
  });

  test('back templates locate the 3 MRZ lines', () {
    for (final type in DocumentType.values) {
      final fields = DocumentTemplate.of(type, .back).fields;
      expect(fields.keys, containsAll([DocumentField.mrzLine1, DocumentField.mrzLine2, DocumentField.mrzLine3]));
    }
  });
}
