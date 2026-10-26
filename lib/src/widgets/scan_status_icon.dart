import 'package:flutter/material.dart';

import '../models/scan_status.dart';

/// Icon shown next to each status message.
extension ScanStatusIcon on ScanStatus {
  IconData get icon => switch (this) {
    .initializing => Icons.photo_camera_outlined,
    .searching => Icons.crop_free_rounded,
    .tooFar => Icons.zoom_in_rounded,
    .notAligned => Icons.screen_rotation_alt_rounded,
    .tooDark => Icons.wb_sunny_outlined,
    .glare => Icons.flare_rounded,
    .blurry => Icons.back_hand_outlined,
    .ready => Icons.check_circle_rounded,
    .capturing => Icons.camera_rounded,
    .validating => Icons.cloud_upload_outlined,
    .rejected => Icons.refresh_rounded,
    .captured => Icons.task_alt_rounded,
    .completed => Icons.verified_rounded,
    .permissionDenied => Icons.no_photography_outlined,
    .error => Icons.error_outline_rounded,
  };
}
