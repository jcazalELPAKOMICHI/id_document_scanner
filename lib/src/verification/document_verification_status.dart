/// Outcome of checking that a capture is a Paraguayan identity card.
enum DocumentVerificationStatus {
  verified,
  rejected,

  /// There is no reference to check this face (e.g. front of the legacy card).
  unsupported,
}
