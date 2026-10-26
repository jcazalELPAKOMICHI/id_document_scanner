import '../verification/document_rejection_reason.dart';
import 'scan_status.dart';

/// Text shown for each [ScanStatus]. Pass your own (e.g. from your l10n) to
/// translate or change the tone; defaults are Paraguayan Spanish.
class ScannerMessages {
  const ScannerMessages({
    this.initializing = 'Iniciando cámara…',
    this.searching = 'Ubicá tu cédula dentro del recuadro',
    this.tooFar = 'Acercá un poco más el documento',
    this.notAligned = 'Enderezá la cédula dentro del recuadro',
    this.tooDark = 'Buscá un lugar con más luz',
    this.glare = 'Evitá los reflejos sobre el documento',
    this.blurry = 'Mantené el celular quieto',
    this.ready = '¡Perfecto! No te muevas',
    this.capturing = 'Capturando…',
    this.validating = 'Verificando tu documento…',
    this.rejected = 'No pudimos validar la foto, intentemos de nuevo',
    this.cropFailed = 'No vimos bien los bordes de la cédula, intentemos de nuevo',
    this.notParaguayanId = 'Esto no parece una cédula paraguaya',
    this.mrzUnreadable = 'No pudimos leer las líneas de abajo, probemos de nuevo',
    this.reproductionDetected = 'Necesitamos tu cédula física, no una foto, pantalla o fotocopia',
    this.captured = 'Documento capturado',
    this.completed = '¡Listo! Ya tenemos tu cédula',
    this.permissionDenied = 'Necesitamos permiso para usar la cámara',
    this.error = 'No pudimos abrir la cámara',
    this.flipToBack = 'Ahora dale vuelta a tu cédula',
    this.flipToFront = 'Mostrá el frente de tu cédula',
  });

  final String initializing;
  final String searching;
  final String tooFar;
  final String notAligned;
  final String tooDark;
  final String glare;
  final String blurry;
  final String ready;
  final String capturing;
  final String validating;
  final String rejected;

  /// Shown when the photo did not contain the whole card with clear borders.
  final String cropFailed;

  /// The front or back is not a Paraguayan identity card.
  final String notParaguayanId;

  /// The back's MRZ could not be read or its check digits failed.
  final String mrzUnreadable;

  /// The photo is of a screen or a printed copy, not of the card.
  final String reproductionDetected;
  final String captured;
  final String completed;
  final String permissionDenied;
  final String error;

  /// Shown during the flip animation when switching sides.
  final String flipToBack;
  final String flipToFront;

  String forRejection(DocumentRejectionReason reason) => switch (reason) {
    .frontNotRecognized || .notParaguayanId => notParaguayanId,
    .mrzUnreadable || .mrzInvalid => mrzUnreadable,
  };

  String of(ScanStatus status) => switch (status) {
    .initializing => initializing,
    .searching => searching,
    .tooFar => tooFar,
    .notAligned => notAligned,
    .tooDark => tooDark,
    .glare => glare,
    .blurry => blurry,
    .ready => ready,
    .capturing => capturing,
    .validating => validating,
    .rejected => rejected,
    .captured => captured,
    .completed => completed,
    .permissionDenied => permissionDenied,
    .error => error,
  };
}
