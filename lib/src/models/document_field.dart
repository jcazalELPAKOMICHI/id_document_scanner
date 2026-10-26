/// Data fields printed on either face of a supported identity card.
enum DocumentField {
  surnames,
  givenNames,
  fullName,
  documentNumber,
  birthDate,
  birthPlace,
  expiryDate,
  sex,
  organDonor,
  photo,
  civilStatus,
  nationality,
  issueDate,
  identificationCode,
  location,
  chip,
  barcode,
  cardSerial,

  /// Whole machine readable zone (3 lines, TD1).
  mrz,
  mrzLine1,
  mrzLine2,
  mrzLine3,
}
