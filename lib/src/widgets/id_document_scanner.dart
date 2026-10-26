import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/scanner_constants.dart';
import '../controller/id_document_scanner_controller.dart';
import '../geometry/guide_geometry.dart';
import '../models/document_capture.dart';
import '../models/scan_result.dart';
import '../models/scan_status.dart';
import '../models/scanner_messages.dart';
import '../models/scanner_overlay_state.dart';
import '../models/scanner_overlay_style.dart';
import 'document_flip_transition.dart';
import 'scanner_camera_preview.dart';
import 'scanner_capture_feedback.dart';
import 'scanner_capture_button.dart';
import 'scanner_debug_panel.dart';
import 'scanner_overlay.dart';

/// Full-screen camera with a card-shaped guide. The frame turns green when the
/// document is aligned, sharp and well lit, and (with auto-capture) the photo
/// is taken once it stays steady.
class IdDocumentScanner extends StatefulWidget {
  const IdDocumentScanner({
    super.key,
    required this.controller,
    this.onCaptured,
    this.onCompleted,
    this.onStatusChanged,
    this.title,
    this.subtitle,
    this.messages = const ScannerMessages(),
    this.style = const ScannerOverlayStyle(),
    this.overlayBuilder,
    this.bottomBuilder,
    this.showCaptureButton = false,
    this.showDebugInfo = false,
    this.guideWidthFactor = ScannerConstants.guideWidthFactor,
    this.guideVerticalCenter = ScannerConstants.guideVerticalCenter,
  });

  final IdDocumentScannerController controller;

  /// Every photo taken (cropped to the card), before validation.
  final ValueChanged<DocumentCapture>? onCaptured;

  /// Every side of the flow was captured and accepted by the validator.
  final ValueChanged<ScanResult>? onCompleted;
  final ValueChanged<ScanStatus>? onStatusChanged;

  /// Custom text above the guide (e.g. "Frente de tu cédula").
  final String? title;
  final String? subtitle;
  final ScannerMessages messages;
  final ScannerOverlayStyle style;

  /// Replaces the default frame and message with your own UI.
  final Widget Function(BuildContext context, ScannerOverlayState state)? overlayBuilder;

  /// Extra content pinned to the bottom (e.g. a help link or a cancel button).
  final Widget Function(BuildContext context, ScannerOverlayState state)? bottomBuilder;

  /// Shows a shutter button, enabled while the frame is green.
  final bool showCaptureButton;

  /// Prints the raw detection values on screen.
  final bool showDebugInfo;
  final double guideWidthFactor;
  final double guideVerticalCenter;

  @override
  State<IdDocumentScanner> createState() => _IdDocumentScannerState();
}

class _IdDocumentScannerState extends State<IdDocumentScanner> with WidgetsBindingObserver {
  StreamSubscription<DocumentCapture>? captureSubscription;
  StreamSubscription<ScanResult>? resultSubscription;
  ScanStatus? lastStatus;

  IdDocumentScannerController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    controller.addListener(onControllerChanged);
    captureSubscription = controller.captures.listen((capture) => widget.onCaptured?.call(capture));
    resultSubscription = controller.results.listen((result) => widget.onCompleted?.call(result));
    unawaited(controller.initialize());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == .inactive) unawaited(controller.pause());
    if (state == .resumed && controller.camera == null) unawaited(controller.initialize());
  }

  void onControllerChanged() {
    if (controller.status == lastStatus) return;
    lastStatus = controller.status;
    if (controller.status == .ready && widget.style.enableHaptics) unawaited(HapticFeedback.selectionClick());
    widget.onStatusChanged?.call(controller.status);
  }

  String messageFor(IdDocumentScannerController controller) {
    if (controller.status != .rejected) return widget.messages.of(controller.status);
    if (controller.cropFailed) return widget.messages.cropFailed;
    if (controller.reproductionDetected) return widget.messages.reproductionDetected;
    if (controller.rejectionReason case final reason?) return widget.messages.forRejection(reason);
    return controller.rejectionMessage ?? widget.messages.rejected;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller.removeListener(onControllerChanged);
    unawaited(captureSubscription?.cancel());
    unawaited(resultSubscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    return ColoredBox(
      color: widget.style.scrimColor.withValues(alpha: 1),
      child: Material(
        type: .transparency,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final viewport = constraints.biggest;
            final guide = GuideGeometry.guideRect(
              viewport,
              widthFactor: widget.guideWidthFactor,
              verticalCenter: widget.guideVerticalCenter,
            );
            controller.updateGuide(guide, viewport);
            return ListenableBuilder(
              listenable: controller,
              builder: (context, _) {
                final camera = controller.camera;
                final previewSize = controller.previewSize;
                final state = ScannerOverlayState(
                  status: controller.status,
                  message: messageFor(controller),
                  guide: guide,
                  frameColor: widget.style.colorFor(controller.status),
                  analysis: controller.analysis,
                  progress: controller.stabilityProgress,
                  side: controller.side,
                );
                final cameraReady = camera != null && camera.value.isInitialized && previewSize != null;
                return Stack(
                  fit: .expand,
                  children: [
                    AnimatedOpacity(
                      opacity: cameraReady ? 1 : 0,
                      duration: ScannerConstants.entryDuration,
                      curve: Curves.easeOut,
                      child: cameraReady
                          ? ScannerCameraPreview(camera: camera, previewSize: previewSize)
                          : const SizedBox(),
                    ),
                    if (widget.overlayBuilder case final builder?)
                      builder(context, state)
                    else
                      ScannerOverlay(state: state, style: widget.style, title: widget.title, subtitle: widget.subtitle),
                    ScannerCaptureFeedback(
                      status: state.status,
                      guide: guide,
                      style: widget.style,
                      cardImage: controller.capture?.cardImage,
                    ),
                    DocumentFlipTransition(
                      side: state.side,
                      guide: guide,
                      message: state.side == .back ? widget.messages.flipToBack : widget.messages.flipToFront,
                      style: widget.style,
                    ),
                    if (widget.showCaptureButton)
                      Positioned(
                        bottom: padding.bottom + 32,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: ScannerCaptureButton(
                            color: state.frameColor,
                            onPressed: state.status == .ready ? () => unawaited(controller.takePicture()) : null,
                          ),
                        ),
                      ),
                    if (widget.bottomBuilder case final builder?)
                      Positioned(
                        bottom: padding.bottom + (widget.showCaptureButton ? 120 : 24),
                        left: 24,
                        right: 24,
                        child: builder(context, state),
                      ),
                    if (widget.showDebugInfo)
                      Positioned(
                        top: padding.top,
                        left: 0,
                        right: 0,
                        child: ScannerDebugPanel(analysis: state.analysis, style: widget.style),
                      ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}
