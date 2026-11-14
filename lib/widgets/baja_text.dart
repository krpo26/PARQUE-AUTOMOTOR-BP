import 'package:intl/intl.dart';

/// "Baja: dd/MM/yyyy" + "Motivo: ..." (solo lo que exista).
String bajaText(DateTime? date, String reason) {
  final parts = <String>[
    if (date != null) 'Baja: ${DateFormat('dd/MM/yyyy').format(date)}',
    if (reason.isNotEmpty) 'Motivo: $reason',
  ];
  return parts.join('\n');
}
