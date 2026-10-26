/// What the scanner currently sees inside the guide frame.
enum ScanStatus {
  initializing,
  searching,
  tooFar,
  notAligned,
  tooDark,
  glare,
  blurry,
  ready,
  capturing,

  /// Waiting for the [CaptureValidator] (e.g. your backend).
  validating,

  /// The validator rejected the capture; the same side is scanned again.
  rejected,

  /// Accepted; the flow moves to the next side.
  captured,

  /// Every side was accepted.
  completed,
  permissionDenied,
  error;

  bool get isReady => this == .ready || this == .capturing;

  /// The camera is not looking for the card (photo taken or being processed).
  bool get isSettled => isReady || this == .validating || this == .captured || this == .completed || this == .rejected;

  bool get isWarning => this == .tooFar || this == .notAligned || this == .tooDark || this == .glare || this == .blurry;
}
