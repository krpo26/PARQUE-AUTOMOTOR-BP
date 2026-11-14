import 'complex.dart';

/// Un trámite administrativo del parque automotor: pedido de service,
/// pedido de compras, pedido de arreglo, etc. Cada uno tiene tipo,
/// fecha de inicio, estado y (opcional) número de expediente.
/// Pertenece a un complejo, igual que los móviles y los choferes.
class Procedure {
  /// Tipos más comunes. El usuario también puede escribir uno propio
  /// eligiendo [otherType]; en ese caso se guarda el texto que escribió.
  static const List<String> types = [
    'Pedido de service',
    'Pedido de compras',
    'Pedido de arreglo',
  ];
  static const String otherType = 'Otro';

  static const String statusStarted = 'Iniciado';
  static const String statusInProgress = 'En trámite';
  static const String statusDone = 'Finalizado';
  static const String statusRejected = 'Rechazado';

  static const List<String> statuses = [
    statusStarted,
    statusInProgress,
    statusDone,
    statusRejected,
  ];

  final String id;
  final String type; // Trámite (ej. "Pedido de service")
  final DateTime startDate; // Fecha de inicio del trámite
  final String status; // Estado del trámite
  final DateTime? endDate; // Fecha de finalización (opcional)
  final String fileNumber; // Nº de expediente (opcional, '' si no tiene)
  final String presentedAt; // Dónde se presentó (opcional)
  final String vehicleId; // Móvil del trámite ('' = ninguno)
  final String vehicleNumber; // Nº interno del móvil (copia, ej. 6185)
  final String complexId; // Complejo al que pertenece
  // Última edición: al sincronizar gana la versión más reciente.
  final DateTime updatedAt;

  Procedure({
    required this.id,
    required this.type,
    required this.startDate,
    required this.status,
    this.endDate,
    this.fileNumber = '',
    this.presentedAt = '',
    this.vehicleId = '',
    this.vehicleNumber = '',
    this.complexId = kDefaultComplexId,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  /// true mientras el trámite sigue abierto (no finalizado ni rechazado).
  bool get isOpen => status == statusStarted || status == statusInProgress;

  Procedure copyWith({
    String? type,
    DateTime? startDate,
    String? status,
    DateTime? endDate,
    bool clearEndDate = false,
    String? fileNumber,
    String? presentedAt,
    String? vehicleId,
    String? vehicleNumber,
    String? complexId,
    DateTime? updatedAt,
  }) {
    return Procedure(
      id: id,
      type: type ?? this.type,
      startDate: startDate ?? this.startDate,
      status: status ?? this.status,
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
      fileNumber: fileNumber ?? this.fileNumber,
      presentedAt: presentedAt ?? this.presentedAt,
      vehicleId: vehicleId ?? this.vehicleId,
      vehicleNumber: vehicleNumber ?? this.vehicleNumber,
      complexId: complexId ?? this.complexId,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'start_date': startDate.toIso8601String(),
      'status': status,
      'end_date': endDate?.toIso8601String(),
      'file_number': fileNumber,
      'presented_at': presentedAt,
      'vehicle_id': vehicleId,
      'vehicle_number': vehicleNumber,
      'complex_id': complexId,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Procedure.fromMap(Map<String, dynamic> map) {
    return Procedure(
      id: map['id'] as String,
      type: map['type'] as String,
      startDate: DateTime.parse(map['start_date'] as String),
      status: map['status'] as String,
      endDate: map['end_date'] != null
          ? DateTime.tryParse(map['end_date'] as String)
          : null,
      fileNumber: (map['file_number'] ?? '') as String,
      presentedAt: (map['presented_at'] ?? '') as String,
      vehicleId: (map['vehicle_id'] ?? '') as String,
      vehicleNumber: (map['vehicle_number'] ?? '') as String,
      complexId: (map['complex_id'] ?? kDefaultComplexId) as String,
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
