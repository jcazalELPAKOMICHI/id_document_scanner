import 'dart:ui';

import '../models/document_field.dart';
import '../models/document_side.dart';
import '../models/document_type.dart';
import 'paraguay_id_templates.dart';

/// Where each field is printed on one face of a card, in coordinates
/// normalized to the card (0..1, origin top-left, card upright). Used to crop
/// fields for OCR.
class DocumentTemplate {
  const DocumentTemplate({required this.type, required this.side, required this.fields});

  final DocumentType type;
  final DocumentSide side;
  final Map<DocumentField, Rect> fields;

  static DocumentTemplate of(DocumentType type, DocumentSide side) => switch ((type, side)) {
    (.paraguayIdCurrent, .front) => ParaguayIdTemplates.currentFront,
    (.paraguayIdCurrent, .back) => ParaguayIdTemplates.currentBack,
    (.paraguayIdLegacy, .front) => ParaguayIdTemplates.legacyFront,
    (.paraguayIdLegacy, .back) => ParaguayIdTemplates.legacyBack,
  };
}
