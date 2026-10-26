import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui';

import 'package:image/image.dart' as img;

import '../analysis/card_edge_refiner.dart';
import '../constants/scanner_constants.dart';
import '../geometry/guide_geometry.dart';
import '../models/cropped_card.dart';
import '../models/document_field.dart';
import '../models/luma_frame.dart';
import '../security/reproduction_check.dart';
import '../security/reproduction_detector.dart';
import '../templates/document_template.dart';

/// Crops the card and its fields out of captured photos, off the UI isolate.
abstract final class DocumentCropper {
  /// Crops the card from the JPEG [bytes]. [expected] is where the live
  /// analysis saw the card, normalized to the upright [preview].
  static Future<CroppedCard> cropCard(
    Uint8List bytes, {
    required Rect expected,
    required Size preview,
    CardEdgeRefiner refiner = const CardEdgeRefiner(),
    ReproductionDetector? reproductionDetector = const ReproductionDetector(),
  }) => Isolate.run(() {
    final photo = img.bakeOrientation(img.decodeImage(bytes)!);
    final photoSize = Size(photo.width.toDouble(), photo.height.toDouble());
    final region = GuideGeometry.previewToPhoto(expected, preview, photoSize);
    final work = photo.width > ScannerConstants.refineWorkWidth
        ? img.copyResize(photo, width: ScannerConstants.refineWorkWidth)
        : photo;
    final corners = refiner.refine(_lumaFrame(work), region);
    if (corners == null) {
      final fallback = _crop(photo, region.inflate(ScannerConstants.cropPadding));
      return CroppedCard(
        image: _encode(fallback),
        corners: null,
        reproduction: reproductionDetector?.analyze(fallback) ?? ReproductionCheck.none,
      );
    }

    final pixels = corners.scaled(photoSize);
    final width = pixels.width.round();
    final card = img.copyRectify(
      photo,
      topLeft: img.Point(pixels.topLeft.dx, pixels.topLeft.dy),
      topRight: img.Point(pixels.topRight.dx, pixels.topRight.dy),
      bottomLeft: img.Point(pixels.bottomLeft.dx, pixels.bottomLeft.dy),
      bottomRight: img.Point(pixels.bottomRight.dx, pixels.bottomRight.dy),
      interpolation: .linear,
      toImage: img.Image(
        width: width,
        height: (width / ScannerConstants.idCardAspectRatio).round(),
        numChannels: photo.numChannels,
      ),
    );
    return CroppedCard(
      image: _encode(card),
      corners: corners,
      reproduction: reproductionDetector?.analyze(card) ?? ReproductionCheck.none,
    );
  });

  /// Crops every field of [template] from a card image produced by [cropCard].
  static Future<Map<DocumentField, Uint8List>> cropFields(Uint8List cardBytes, DocumentTemplate template) =>
      Isolate.run(() {
        final card = img.decodeImage(cardBytes)!;
        return template.fields.map((field, region) => MapEntry(field, _encode(_crop(card, region))));
      });

  static Uint8List _encode(img.Image image) => img.encodeJpg(image, quality: ScannerConstants.capturedJpegQuality);

  static LumaFrame _lumaFrame(img.Image image) {
    final rgb = image.getBytes(order: img.ChannelOrder.rgb);
    final luma = Uint8List(image.width * image.height);
    for (var i = 0; i < luma.length; i++) {
      final j = i * _rgbChannels;
      luma[i] = (77 * rgb[j] + 150 * rgb[j + 1] + 29 * rgb[j + 2]) >> 8;
    }
    return LumaFrame(
      width: image.width,
      height: image.height,
      bytesPerRow: image.width,
      bytes: luma,
      sensorOrientation: 0,
    );
  }

  static img.Image _crop(img.Image source, Rect region) {
    final left = (region.left.clamp(0.0, 1.0) * source.width).round();
    final top = (region.top.clamp(0.0, 1.0) * source.height).round();
    final right = (region.right.clamp(0.0, 1.0) * source.width).round();
    final bottom = (region.bottom.clamp(0.0, 1.0) * source.height).round();
    return img.copyCrop(source, x: left, y: top, width: right - left, height: bottom - top);
  }

  static const int _rgbChannels = 3;
}
