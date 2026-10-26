import 'dart:math';
import 'dart:ui';

/// The 4 corners of the card found in a photo, normalized to it (0..1).
class CardCorners {
  const CardCorners({
    required this.topLeft,
    required this.topRight,
    required this.bottomRight,
    required this.bottomLeft,
  });

  final Offset topLeft;
  final Offset topRight;
  final Offset bottomRight;
  final Offset bottomLeft;

  List<Offset> get points => [topLeft, topRight, bottomRight, bottomLeft];

  /// Corners in pixels of an image of [size].
  CardCorners scaled(Size size) => CardCorners(
    topLeft: topLeft.scale(size.width, size.height),
    topRight: topRight.scale(size.width, size.height),
    bottomRight: bottomRight.scale(size.width, size.height),
    bottomLeft: bottomLeft.scale(size.width, size.height),
  );

  /// Mean length of the top and bottom edges, in the units of the corners.
  double get width => ((topRight - topLeft).distance + (bottomRight - bottomLeft).distance) / 2;

  /// Mean length of the left and right edges, in the units of the corners.
  double get height => ((bottomLeft - topLeft).distance + (bottomRight - topRight).distance) / 2;

  Rect get bounds {
    final xs = points.map((point) => point.dx);
    final ys = points.map((point) => point.dy);
    return Rect.fromLTRB(xs.reduce(min), ys.reduce(min), xs.reduce(max), ys.reduce(max));
  }
}
