import 'complex.dart';

enum LicenseStatus { ok, warning, expired }

class Driver {
  final String id;
  final String fullName; // Apellido y Nombre
  final String documentId; // DNI / Identificación
  final String phone;
  final String licenseCategory; // Categoría de licencia / carnet
  final DateTime licenseExpiration; // Vencimiento del carnet
  final String? photoPath; // Foto del chofer (ruta local en el dispositivo)
  final String? licensePhotoPath; // Foto del carnet de conducir
  final String? address; // Dirección del chofer
  final String? cargoNumber; // Número de cargo / legajo
  final String? iconKey; // Ícono elegido para representar al chofer
  final bool isArchived; // true = dado de baja (no se borra, se archiva)
  // Cuándo se guardó esta versión del registro por última vez. Se usa
  // para que, al sincronizar, la edición más reciente (venga de este
  // dispositivo o de otro) sea siempre la que gana — así un cambio
  // del admin nunca lo pisa un dispositivo con datos viejos.
  final DateTime updatedAt;
  // Complejo penitenciario al que pertenece este chofer.
  final String complexId;
  // Vencimiento del LINTI / psicofísico (opcional).
  final DateTime? psychoPhysicalExpiration;
  // Baja del chofer: fecha y motivo (opcional).
  final DateTime? deactivatedAt;
  final String deactivationReason;

  Driver({
    required this.id,
    required this.fullName,
    required this.documentId,
    required this.phone,
    required this.licenseCategory,
    required this.licenseExpiration,
    this.photoPath,
    this.licensePhotoPath,
    this.address,
    this.cargoNumber,
    this.iconKey,
    this.isArchived = false,
    DateTime? updatedAt,
    this.complexId = kDefaultComplexId,
    this.psychoPhysicalExpiration,
    this.deactivatedAt,
    this.deactivationReason = '',
  }) : updatedAt = updatedAt ?? DateTime.now();

  int get daysToLicenseExpiration =>
      licenseExpiration.difference(DateTime.now()).inDays;

  LicenseStatus get licenseStatus {
    final days = daysToLicenseExpiration;
    if (days < 0) return LicenseStatus.expired;
    if (days <= 30) return LicenseStatus.warning;
    return LicenseStatus.ok;
  }

  /// Devuelve true si el vencimiento cae exactamente en uno de los hitos
  /// de aviso (30, 15, 5 días), útil para disparar notificaciones puntuales.
  bool get isAtNotificationMilestone =>
      [30, 15, 5].contains(daysToLicenseExpiration);

  Driver copyWith({
    String? fullName,
    String? documentId,
    String? phone,
    String? licenseCategory,
    DateTime? licenseExpiration,
    String? photoPath,
    String? licensePhotoPath,
    String? address,
    String? cargoNumber,
    String? iconKey,
    bool? isArchived,
    DateTime? updatedAt,
    String? complexId,
    DateTime? psychoPhysicalExpiration,
    bool clearPsychoPhysical = false,
    DateTime? deactivatedAt,
    String? deactivationReason,
    bool clearDeactivation = false,
  }) {
    return Driver(
      id: id,
      fullName: fullName ?? this.fullName,
      documentId: documentId ?? this.documentId,
      phone: phone ?? this.phone,
      licenseCategory: licenseCategory ?? this.licenseCategory,
      licenseExpiration: licenseExpiration ?? this.licenseExpiration,
      photoPath: photoPath ?? this.photoPath,
      licensePhotoPath: licensePhotoPath ?? this.licensePhotoPath,
      address: address ?? this.address,
      cargoNumber: cargoNumber ?? this.cargoNumber,
      iconKey: iconKey ?? this.iconKey,
      isArchived: isArchived ?? this.isArchived,
      // Cualquier copyWith (o sea, cualquier edición real) actualiza
      // el sello de tiempo, salvo que se pase uno explícito (lo usa
      // la sincronización al traer una versión remota).
      updatedAt: updatedAt ?? DateTime.now(),
      complexId: complexId ?? this.complexId,
      psychoPhysicalExpiration: clearPsychoPhysical
          ? null
          : (psychoPhysicalExpiration ?? this.psychoPhysicalExpiration),
      deactivatedAt:
          clearDeactivation ? null : (deactivatedAt ?? this.deactivatedAt),
      deactivationReason: clearDeactivation
          ? ''
          : (deactivationReason ?? this.deactivationReason),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'full_name': fullName,
      'document_id': documentId,
      'phone': phone,
      'license_category': licenseCategory,
      'license_expiration': licenseExpiration.toIso8601String(),
      'photo_path': photoPath,
      'license_photo_path': licensePhotoPath,
      'address': address,
      'cargo_number': cargoNumber,
      'icon_key': iconKey,
      'is_archived': isArchived ? 1 : 0,
      'updated_at': updatedAt.toIso8601String(),
      'complex_id': complexId,
      'psycho_physical_expiration': psychoPhysicalExpiration?.toIso8601String(),
      'deactivated_at': deactivatedAt?.toIso8601String(),
      'deactivation_reason': deactivationReason,
    };
  }

  factory Driver.fromMap(Map<String, dynamic> map) {
    return Driver(
      id: map['id'] as String,
      fullName: map['full_name'] as String,
      documentId: map['document_id'] as String,
      phone: map['phone'] as String,
      licenseCategory: map['license_category'] as String,
      licenseExpiration: DateTime.parse(map['license_expiration'] as String),
      photoPath: map['photo_path'] as String?,
      licensePhotoPath: map['license_photo_path'] as String?,
      address: map['address'] as String?,
      cargoNumber: map['cargo_number'] as String?,
      iconKey: map['icon_key'] as String?,
      isArchived: map['is_archived'] == true || map['is_archived'] == 1,
      // Registros viejos (de antes de este cambio) no tienen
      // updated_at guardado: se los trata como "lo más viejo posible"
      // para que, ante cualquier duda, gane la versión que sí tenga
      // fecha (evita bloquear sincronizaciones futuras).
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : DateTime.fromMillisecondsSinceEpoch(0),
      complexId: (map['complex_id'] ?? kDefaultComplexId) as String,
      psychoPhysicalExpiration: map['psycho_physical_expiration'] != null
          ? DateTime.tryParse(map['psycho_physical_expiration'] as String)
          : null,
      deactivatedAt: map['deactivated_at'] != null
          ? DateTime.tryParse(map['deactivated_at'] as String)
          : null,
      deactivationReason: (map['deactivation_reason'] ?? '') as String,
    );
  }
}
