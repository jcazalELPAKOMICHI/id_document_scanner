import 'package:flutter/material.dart';
import 'package:id_document_scanner/id_document_scanner.dart';

/// What the SDK verified about the card (and the MRZ data on the back).
class VerificationSummary extends StatelessWidget {
  const VerificationSummary({super.key, required this.verification});

  final DocumentVerification verification;

  @override
  Widget build(BuildContext context) {
    final mrz = verification.mrz;
    final rows = <(String, String)>[
      (
        'Cédula paraguaya',
        switch (verification.status) {
          .verified => 'Verificada',
          .rejected => 'Rechazada (${verification.reason?.name})',
          .unsupported => 'Sin referencia para este diseño',
        },
      ),
      if (verification.detectedType case final type?) ('Diseño detectado', type.name),
      if (mrz != null) ...[
        ('Documento', mrz.documentNumber),
        ('Apellidos', mrz.surnames),
        ('Nombres', mrz.givenNames),
        ('Nacimiento', mrz.birthDate?.toIso8601String().substring(0, 10) ?? '-'),
        ('Vencimiento', mrz.expiryDate?.toIso8601String().substring(0, 10) ?? '-'),
        ('Sexo', mrz.sex.name),
        ('Nacionalidad', mrz.nationality),
      ],
    ];
    return Card(
      margin: const .symmetric(vertical: 8),
      child: Padding(
        padding: const .all(12),
        child: Column(
          crossAxisAlignment: .start,
          children: rows
              .map(
                (row) => Padding(
                  padding: const .symmetric(vertical: 2),
                  child: Row(
                    children: [
                      SizedBox(width: 140, child: Text(row.$1, style: Theme.of(context).textTheme.labelMedium)),
                      Expanded(child: Text(row.$2)),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}
