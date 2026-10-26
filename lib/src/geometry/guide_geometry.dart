import 'dart:math';
import 'dart:ui';

import '../constants/scanner_constants.dart';

/// Converts between the guide frame drawn on screen and the camera image.
abstract final class GuideGeometry {
  /// Card-shaped guide centred horizontally in [viewport].
  static Rect guideRect(
    Size viewport, {
    double widthFactor = ScannerConstants.guideWidthFactor,
    double verticalCenter = ScannerConstants.guideVerticalCenter,
  }) {
    final width = viewport.width * widthFactor;
    final height = width / ScannerConstants.idCardAspectRatio;
    return Rect.fromCenter(
      center: Offset(viewport.width / 2, viewport.height * verticalCenter),
      width: width,
      height: height,
    );
  }

  /// Maps [widgetRect] (in [viewport] pixels) to normalized coordinates of an
  /// upright image of [imageSize] shown with `BoxFit.cover`.
  static Rect toImageRect(Rect widgetRect, Size viewport, Size imageSize) {
    final scale = max(viewport.width / imageSize.width, viewport.height / imageSize.height);
    final displayed = imageSize * scale;
    final dx = (viewport.width - displayed.width) / 2;
    final dy = (viewport.height - displayed.height) / 2;
    return Rect.fromLTRB(
      (widgetRect.left - dx) / displayed.width,
      (widgetRect.top - dy) / displayed.height,
      (widgetRect.right - dx) / displayed.width,
      (widgetRect.bottom - dy) / displayed.height,
    );
  }

  /// Maps a normalized image rect back to [viewport] pixels (inverse of [toImageRect]).
  static Rect toWidgetRect(Rect imageRect, Size viewport, Size imageSize) {
    final scale = max(viewport.width / imageSize.width, viewport.height / imageSize.height);
    final displayed = imageSize * scale;
    final dx = (viewport.width - displayed.width) / 2;
    final dy = (viewport.height - displayed.height) / 2;
    return Rect.fromLTRB(
      dx + imageRect.left * displayed.width,
      dy + imageRect.top * displayed.height,
      dx + imageRect.right * displayed.width,
      dy + imageRect.bottom * displayed.height,
    );
  }

  /// Maps [previewRect] (normalized to the upright preview) to the upright
  /// photo. Preview and photo are centred crops of the same sensor, so when
  /// their aspect ratios differ the narrower one covers only the middle of the
  /// other along that axis.
  static Rect previewToPhoto(Rect previewRect, Size preview, Size photo) {
    final previewAspect = preview.width / preview.height;
    final photoAspect = photo.width / photo.height;
    final scaleX = previewAspect < photoAspect ? previewAspect / photoAspect : 1.0;
    final scaleY = previewAspect > photoAspect ? photoAspect / previewAspect : 1.0;
    double mapX(double x) => 0.5 + (x - 0.5) * scaleX;
    double mapY(double y) => 0.5 + (y - 0.5) * scaleY;
    return Rect.fromLTRB(
      mapX(previewRect.left),
      mapY(previewRect.top),
      mapX(previewRect.right),
      mapY(previewRect.bottom),
    );
  }
}
