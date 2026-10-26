import 'dart:async';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../analysis/card_edge_refiner.dart';
import '../analysis/detection_stabilizer.dart';
import '../analysis/frame_analyzer.dart';
import '../camera/camera_frame_converter.dart';
import '../camera/document_cropper.dart';
import '../constants/scanner_constants.dart';
import '../geometry/guide_geometry.dart';
import '../models/capture_validation.dart';
import '../models/capture_validator.dart';
import '../models/detection_config.dart';
import '../models/document_capture.dart';
import '../models/document_side.dart';
import '../models/document_type.dart';
import '../models/frame_analysis.dart';
import '../models/scan_result.dart';
import '../models/scan_status.dart';
import '../security/reproduction_detector.dart';
import '../verification/document_rejection_reason.dart';
import '../verification/paraguay_id_verifier.dart';

/// Owns the camera and the scanning flow.
///
/// For every side in [sides]: detect the card, take the photo, crop only the
/// card, hand it to [validator] (e.g. upload it to your backend) and, if
/// accepted, move to the next side. When every side is accepted the flow
/// completes with a [ScanResult] ([results] / `onCompleted`).
///
/// Create it in your page, hand it to `IdDocumentScanner` and dispose it with
/// the page.
class IdDocumentScannerController extends ChangeNotifier {
  IdDocumentScannerController({
    this.documentType = .paraguayIdCurrent,
    this.sides = const [DocumentSide.front, DocumentSide.back],
    this.validator,
    this.autoAdvance = true,
    this.requirePreciseCrop = true,
    this.verifyDocument = true,
    this.verifier = const ParaguayIdVerifier(),
    this.rejectReproductions = true,
    this.reproductionDetector = const ReproductionDetector(),
    this.detectionConfig = const DetectionConfig(),
    this.edgeRefiner = const CardEdgeRefiner(),
    this.autoCapture = true,
    this.resolutionPreset = .veryHigh,
  }) : assert(sides.isNotEmpty),
       analyzer = FrameAnalyzer(config: detectionConfig),
       stabilizer = DetectionStabilizer(config: detectionConfig);

  final DocumentType documentType;

  /// Faces to scan, in order.
  final List<DocumentSide> sides;

  /// Decides whether a capture is good enough to continue (e.g. uploads it
  /// to your backend). Without one, every precise capture is accepted.
  final CaptureValidator? validator;

  /// Moves to the next side by itself once a capture is accepted. Set it to
  /// false to decide yourself when to call [nextSide].
  final bool autoAdvance;

  /// Rejects photos where the card borders could not be located exactly, so
  /// only clean, card-only crops ever reach the validator.
  final bool requirePreciseCrop;

  /// Checks that the capture is a Paraguayan identity card (front header,
  /// back MRZ read with the built-in OCR) before calling [validator].
  /// Anything else is rejected and the side is scanned again.
  final bool verifyDocument;
  final ParaguayIdVerifier verifier;

  /// Rejects photos of a screen or of a printed copy (moiré, sub-pixel
  /// stripes, halftone dots) so only the physical card goes through.
  final bool rejectReproductions;
  final ReproductionDetector reproductionDetector;
  final DetectionConfig detectionConfig;
  final CardEdgeRefiner edgeRefiner;

  /// Takes the photo by itself once the card is aligned and steady.
  final bool autoCapture;
  final ResolutionPreset resolutionPreset;
  final FrameAnalyzer analyzer;
  final DetectionStabilizer stabilizer;

  CameraController? camera;
  ScanStatus status = .initializing;
  FrameAnalysis? analysis;

  /// Last photo taken (also while it is being validated or after rejection).
  DocumentCapture? capture;

  /// Captures accepted so far, by side.
  final Map<DocumentSide, DocumentCapture> accepted = {};
  final Map<DocumentSide, Object?> validationData = {};

  /// Message of the last rejection, when the validator gave one.
  String? rejectionMessage;

  /// Whether the last rejection came from the crop (borders not found)
  /// instead of the validator.
  bool cropFailed = false;

  /// Set when the last rejection came from the Paraguayan ID verification.
  DocumentRejectionReason? rejectionReason;

  /// Whether the last rejection was a photo of a screen or a printout.
  bool reproductionDetected = false;

  final StreamController<DocumentCapture> _captures = StreamController.broadcast();
  final StreamController<ScanResult> _results = StreamController.broadcast();
  int _sideIndex = 0;
  Rect? _widgetGuide;
  Size? _viewport;
  DateTime _lastAnalysis = DateTime.fromMillisecondsSinceEpoch(0);
  bool _analyzing = false;
  bool _disposed = false;

  /// Face being scanned now.
  DocumentSide get side => sides[_sideIndex];

  bool get isLastSide => _sideIndex == sides.length - 1;

  /// Every photo taken, before validation.
  Stream<DocumentCapture> get captures => _captures.stream;

  /// Emits once every side was accepted.
  Stream<ScanResult> get results => _results.stream;

  /// Camera preview size, upright (portrait).
  Size? get previewSize {
    final size = camera?.value.previewSize;
    return size == null ? null : Size(size.shortestSide, size.longestSide);
  }

  bool get isStreaming => camera?.value.isStreamingImages ?? false;

  /// 0..1 while the card is held steady before auto-capture.
  double get stabilityProgress =>
      status.isReady ? (stabilizer.stableFrames / detectionConfig.requiredStableFrames).clamp(0, 1) : 0;

  Future<void> initialize() async {
    _setStatus(.initializing);
    try {
      final cameras = await availableCameras();
      final back = cameras.where((c) => c.lensDirection == .back).firstOrNull ?? cameras.firstOrNull;
      if (back == null) return _setStatus(.error);

      final controller = CameraController(back, resolutionPreset, enableAudio: false, imageFormatGroup: .yuv420);
      camera = controller;
      await controller.initialize();
      if (_disposed) return controller.dispose();
      await controller.lockCaptureOrientation(.portraitUp);
      await _startStream();
    } on CameraException catch (exception) {
      _setStatus(ScannerConstants.permissionDeniedCodes.contains(exception.code) ? .permissionDenied : .error);
    }
  }

  /// Called by the scanner widget whenever its layout changes.
  void updateGuide(Rect widgetGuide, Size viewport) {
    _widgetGuide = widgetGuide;
    _viewport = viewport;
  }

  /// Takes the photo now (manual capture) and runs the rest of the flow:
  /// crop, validation and, if accepted, the next side.
  Future<DocumentCapture?> takePicture() async {
    final controller = camera;
    final guide = _normalizedGuide;
    final preview = previewSize;
    if (controller == null || guide == null || preview == null || status == .capturing) return null;
    _setStatus(.capturing);
    final DocumentCapture result;
    try {
      if (controller.value.isStreamingImages) await controller.stopImageStream();
      final photo = await controller.takePicture();
      final lastAnalysis = analysis ?? FrameAnalysis.empty;
      final cropped = await DocumentCropper.cropCard(
        await photo.readAsBytes(),
        expected: lastAnalysis.cardRect(guide),
        preview: preview,
        refiner: edgeRefiner,
        reproductionDetector: reproductionDetector,
      );
      result = DocumentCapture(
        documentType: documentType,
        side: side,
        photoPath: photo.path,
        cardImage: cropped.image,
        corners: cropped.corners,
        analysis: lastAnalysis,
        reproduction: cropped.reproduction,
      );
    } on CameraException {
      _setStatus(.error);
      return null;
    }
    if (_disposed) return null;
    await submitCapture(result);
    return result;
  }

  /// Runs validation and the side transition for [result]. Called after every
  /// photo; also usable to feed a capture obtained elsewhere (e.g. tests).
  Future<void> submitCapture(DocumentCapture result) async {
    capture = result;
    _captures.add(result);
    await _validate(result);
  }

  /// Moves to the next side, or completes the flow after the last one.
  /// Only needed with `autoAdvance: false`.
  Future<void> nextSide() async {
    if (isLastSide) return _complete();
    _sideIndex++;
    await restart();
  }

  /// Scans [target] again, discarding its accepted capture.
  Future<void> retakeSide(DocumentSide target) async {
    final index = sides.indexOf(target);
    if (index < 0) return;
    _sideIndex = index;
    accepted.remove(target);
    validationData.remove(target);
    await restart();
  }

  /// Starts the whole flow over from the first side.
  Future<void> reset() async {
    accepted.clear();
    validationData.clear();
    _sideIndex = 0;
    await restart();
  }

  /// Discards the last capture and scans the current side again.
  Future<void> restart() async {
    capture = null;
    analysis = null;
    rejectionMessage = null;
    cropFailed = false;
    rejectionReason = null;
    reproductionDetected = false;
    stabilizer.reset();
    await _startStream();
  }

  /// Releases the camera (app in background); call [initialize] to resume.
  Future<void> pause() async {
    final controller = camera;
    camera = null;
    stabilizer.reset();
    await controller?.dispose();
  }

  Future<void> _validate(DocumentCapture captured) async {
    if (requirePreciseCrop && !captured.isPreciseCrop) return _reject(null, cropFailed: true);
    if (rejectReproductions && captured.reproduction.isReproduction) return _reject(null, reproduction: true);
    _setStatus(.validating);
    var result = captured;
    if (verifyDocument) {
      final verification = await verifier.verify(result.cardImage, result.side, result.documentType);
      if (_disposed) return;
      result = result.withVerification(verification);
      capture = result;
      if (verification.status == .rejected) return _reject(null, reason: verification.reason);
    }
    CaptureValidation validation;
    try {
      validation = await (validator?.call(result) ?? const CaptureValidation.accepted());
    } on Object {
      validation = const CaptureValidation.rejected();
    }
    if (_disposed) return;
    if (!validation.isAccepted) return _reject(validation.message);

    accepted[result.side] = result;
    validationData[result.side] = validation.data;
    _setStatus(.captured);
    if (!autoAdvance) return;
    await Future<void>.delayed(ScannerConstants.acceptedHold);
    if (_disposed || status != .captured) return;
    await nextSide();
  }

  Future<void> _reject(
    String? message, {
    bool cropFailed = false,
    DocumentRejectionReason? reason,
    bool reproduction = false,
  }) async {
    rejectionMessage = message;
    this.cropFailed = cropFailed;
    rejectionReason = reason;
    reproductionDetected = reproduction;
    _setStatus(.rejected);
    await Future<void>.delayed(ScannerConstants.rejectedHold);
    if (_disposed || status != .rejected) return;
    await restart();
  }

  void _complete() {
    _setStatus(.completed);
    _results.add(ScanResult(captures: Map.of(accepted), validationData: Map.of(validationData)));
  }

  Future<void> _startStream() async {
    if (status == .completed) return;
    _setStatus(.searching);
    final controller = camera;
    if (controller == null) return;
    if (!controller.value.isStreamingImages) await controller.startImageStream(_onFrame);
  }

  Rect? get _normalizedGuide {
    final guide = _widgetGuide;
    final viewport = _viewport;
    final preview = previewSize;
    if (guide == null || viewport == null || preview == null) return null;
    return GuideGeometry.toImageRect(guide, viewport, preview);
  }

  void _onFrame(CameraImage image) {
    final now = DateTime.now();
    final guide = _normalizedGuide;
    final controller = camera;
    if (_analyzing || guide == null || controller == null) return;
    if (now.difference(_lastAnalysis) < ScannerConstants.analysisInterval) return;
    if (status == .capturing || status.isSettled && !status.isReady) return;

    final frame = CameraFrameConverter.toLumaFrame(image, controller.description.sensorOrientation);
    if (frame == null) return;
    _analyzing = true;
    _lastAnalysis = now;
    final result = analyzer.analyze(frame, guide);
    analysis = result;
    final stable = stabilizer.add(result);
    _setStatus(result.status);
    _analyzing = false;
    if (autoCapture && stable) unawaited(takePicture());
  }

  void _setStatus(ScanStatus next) {
    if (_disposed) return;
    status = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_captures.close());
    unawaited(_results.close());
    unawaited(camera?.dispose());
    camera = null;
    super.dispose();
  }
}
