/// Why a capture was not recognised as a Paraguayan identity card.
enum DocumentRejectionReason {
  /// The front does not show the fixed header of the card.
  frontNotRecognized,

  /// No machine readable zone could be read on the back.
  mrzUnreadable,

  /// The MRZ was read but its check digits do not match.
  mrzInvalid,

  /// Valid MRZ, but not issued by Paraguay or not an identity card.
  notParaguayanId,
}
