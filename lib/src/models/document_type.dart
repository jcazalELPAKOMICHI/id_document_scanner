/// Supported identity documents. Both share the ID-1 card format, so detection
/// is the same; the type only selects the field template used after capture.
enum DocumentType {
  /// Paraguay "Cédula de Identidad Civil", current design (photo on the left).
  paraguayIdCurrent,

  /// Paraguay "Cédula de Identidad Civil", previous design (photo on the right).
  paraguayIdLegacy,
}
