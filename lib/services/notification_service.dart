import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/complex.dart';
import '../models/driver.dart';
import '../models/vehicle.dart';
import 'auth_service.dart';
import 'database_helper.dart';

/// Los tipos de aviso que puede mandar la app. Cada uno se puede
/// encender/apagar y tiene su propia frecuencia de repetición.
enum AlertType { maintenance, license, fuelApproaching, fuelLimit }

extension AlertTypeX on AlertType {
  String get label {
    switch (this) {
      case AlertType.maintenance:
        return 'Service por kilometraje';
      case AlertType.license:
        return 'Carnet de conducir';
      case AlertType.fuelApproaching:
        return 'Combustible: cerca del límite';
      case AlertType.fuelLimit:
        return 'Combustible: límite alcanzado';
    }
  }

  String get description {
    switch (this) {
      case AlertType.maintenance:
        return 'Unidades con el service próximo o vencido.';
      case AlertType.license:
        return 'Choferes con el carnet por vencer o vencido.';
      case AlertType.fuelApproaching:
        return 'Unidades que llegaron al 90 % del límite mensual de litros.';
      case AlertType.fuelLimit:
        return 'Unidades que llegaron o pasaron el límite mensual de litros.';
    }
  }

  /// Los avisos de combustible saltan solos en el momento en que se
  /// cruza el umbral; para esos, "Solo una vez" (0) es una opción.
  bool get allowsOnce =>
      this == AlertType.fuelApproaching || this == AlertType.fuelLimit;
}

/// Configuración de un tipo de aviso. [intervalMinutes] = 0 significa
/// "solo una vez" (únicamente combustible).
class AlertTypeConfig {
  final bool enabled;
  final int intervalMinutes;
  const AlertTypeConfig({required this.enabled, required this.intervalMinutes});
}

class _FuelHit {
  final Vehicle vehicle;
  final double total;
  final double limit;
  _FuelHit(this.vehicle, this.total, this.limit);
}

/// Encapsula las notificaciones locales del sistema operativo
/// (Android/iOS) para las alertas de service, carnet y combustible.
///
/// VISUAL: cada aviso sale en la barra de estado de arriba (ícono
/// blanco `ic_stat_fleet`, texto de ticker) y como banner emergente
/// (importancia alta), y se puede expandir para leer el texto completo.
///
/// SONIDO: por defecto suena el sonido de notificación del sistema. En
/// Android se puede elegir un MP3 propio (ver
/// notification_sound_service.dart). Android no permite cambiar el
/// sonido de un canal ya creado, así que cada cambio de sonido crea
/// canales nuevos (con un número de versión en el id) y borra los viejos.
///
/// FRECUENCIA: cada tipo de aviso ([AlertType]) tiene su propio
/// interruptor y su propio intervalo, guardados en este celular. Cada
/// complejo lleva además su propio reloj por tipo. La tarea en segundo
/// plano corre cada ~15 minutos (mínimo de Android) y cada aviso solo
/// se repite cuando pasó SU intervalo.
class NotificationService {
  NotificationService._internal();
  static final NotificationService instance = NotificationService._internal();

  // Clave heredada: el intervalo único anterior. Se usa como valor
  // inicial de service y carnet para no cambiar lo que ya tenían.
  static const _kIntervalMinutesKey = 'alert_sound_interval_minutes';
  static const int kDefaultIntervalMinutes = 60;

  static const _kEnabledPrefix = 'alert_enabled_';
  static const _kIntervalPrefix = 'alert_interval_';
  static const _kLastPrefix = 'alert_last_';

  static const _kSoundUriKey = 'alert_custom_sound_uri';
  static const _kSoundNameKey = 'alert_custom_sound_name';
  static const _kSoundVersionKey = 'alert_sound_channel_version';
  static const _kLegacyChannelsCleanedKey = 'alert_legacy_channels_cleaned';

  /// Opciones de frecuencia (en minutos) para service y carnet.
  static const List<int> kIntervalOptionsMinutes = [
    15, 30, 60, 120, 180, 360, 720, 1440, 4320, 10080,
  ];

  /// Opciones de un tipo de aviso (combustible suma "Solo una vez").
  static List<int> optionsFor(AlertType type) => type.allowsOnce
      ? [0, ...kIntervalOptionsMinutes]
      : kIntervalOptionsMinutes;

  final _plugin = FlutterLocalNotificationsPlugin();

  AndroidFlutterLocalNotificationsPlugin? get _androidImpl =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  /// [isBackground] = true cuando lo llama la tarea en segundo plano
  /// (sin pantalla): ahí no se puede pedir el permiso de
  /// notificaciones, solo se inicializa el plugin y los canales.
  Future<void> init({bool isBackground = false}) async {
    // Ícono blanco y simple para la barra de estado (el ícono de color
    // de la app se vería como un cuadrado blanco).
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    try {
      await _plugin.initialize(const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_fleet'),
        iOS: iosInit,
      ));
    } catch (_) {
      // Si el ícono propio no estuviera, se usa el de la app.
      await _plugin.initialize(const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: iosInit,
      ));
    }

    // Android 13+ exige pedir el permiso de notificaciones en tiempo
    // de ejecución; en versiones anteriores este llamado no hace nada.
    if (!isBackground) {
      await _androidImpl?.requestNotificationsPermission();
    }

    await _createChannels();
  }

  // ---------------------------------------------------------------
  // Permiso de notificaciones (Android 13 o superior)
  // ---------------------------------------------------------------

  /// false si el sistema tiene bloqueadas las notificaciones de la app.
  Future<bool> areNotificationsEnabled() async {
    final impl = _androidImpl;
    if (impl == null) return true;
    try {
      return await impl.areNotificationsEnabled() ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Pide el permiso (si el sistema todavía lo permite) y devuelve si
  /// quedaron habilitadas.
  Future<bool> requestPermission() async {
    final impl = _androidImpl;
    if (impl == null) return true;
    try {
      await impl.requestNotificationsPermission();
    } catch (_) {}
    return areNotificationsEnabled();
  }

  // ---------------------------------------------------------------
  // Sonido propio (MP3)
  // ---------------------------------------------------------------

  AndroidNotificationSound? _soundFrom(SharedPreferences prefs) {
    final uri = prefs.getString(_kSoundUriKey);
    if (uri == null || uri.isEmpty) return null; // sonido del sistema
    return UriAndroidNotificationSound(uri);
  }

  String _channelId(String complexId, int version) =>
      'fleet_alerts_${complexId}_v$version';

  /// Un canal Android por complejo, con el sonido vigente.
  Future<void> _createChannels() async {
    final impl = _androidImpl;
    if (impl == null) return;
    final prefs = await SharedPreferences.getInstance();

    // Las versiones anteriores creaban los canales con un sonido que
    // nunca estuvo en la app. Se borran una vez y se parte de la
    // versión 1 con el sonido del sistema.
    if (prefs.getBool(_kLegacyChannelsCleanedKey) != true) {
      for (final c in kComplexes) {
        await impl.deleteNotificationChannel('fleet_alerts_${c.id}');
      }
      await prefs.setBool(_kLegacyChannelsCleanedKey, true);
    }

    final version = prefs.getInt(_kSoundVersionKey) ?? 1;
    final sound = _soundFrom(prefs);
    for (final c in kComplexes) {
      await impl.createNotificationChannel(
        AndroidNotificationChannel(
          _channelId(c.id, version),
          'Alertas ${c.shortName}',
          description: 'Alertas de ${c.name}',
          importance: Importance.high,
          playSound: true,
          sound: sound,
        ),
      );
    }
  }

  Future<String?> getCustomSoundUri() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kSoundUriKey);
  }

  /// Nombre del MP3 elegido, o null si se usa el sonido del sistema.
  Future<String?> getCustomSoundName() async {
    final prefs = await SharedPreferences.getInstance();
    if ((prefs.getString(_kSoundUriKey) ?? '').isEmpty) return null;
    return prefs.getString(_kSoundNameKey);
  }

  /// Cambia el sonido de las alertas ([uri] null = volver al sonido
  /// del sistema). Crea canales nuevos porque Android no deja
  /// modificar el sonido de un canal existente.
  Future<void> applyCustomSound({String? uri, String? displayName}) async {
    final impl = _androidImpl;
    final prefs = await SharedPreferences.getInstance();
    final oldVersion = prefs.getInt(_kSoundVersionKey) ?? 1;
    if (impl != null) {
      for (final c in kComplexes) {
        await impl.deleteNotificationChannel(_channelId(c.id, oldVersion));
      }
    }
    await prefs.setInt(_kSoundVersionKey, oldVersion + 1);
    if (uri == null || uri.isEmpty) {
      await prefs.remove(_kSoundUriKey);
      await prefs.remove(_kSoundNameKey);
    } else {
      await prefs.setString(_kSoundUriKey, uri);
      await prefs.setString(_kSoundNameKey, displayName ?? 'Sonido propio');
    }
    await _createChannels();
  }

  // ---------------------------------------------------------------
  // Configuración por tipo de aviso
  // ---------------------------------------------------------------

  AlertTypeConfig _readConfig(SharedPreferences prefs, AlertType type) {
    final legacy = prefs.getInt(_kIntervalMinutesKey) ?? kDefaultIntervalMinutes;
    return AlertTypeConfig(
      enabled: prefs.getBool('$_kEnabledPrefix${type.name}') ?? true,
      intervalMinutes: prefs.getInt('$_kIntervalPrefix${type.name}') ??
          (type.allowsOnce ? 0 : legacy),
    );
  }

  Future<AlertTypeConfig> getConfig(AlertType type) async {
    final prefs = await SharedPreferences.getInstance();
    return _readConfig(prefs, type);
  }

  Future<void> setConfig(AlertType type,
      {bool? enabled, int? intervalMinutes}) async {
    final prefs = await SharedPreferences.getInstance();
    if (enabled != null) {
      await prefs.setBool('$_kEnabledPrefix${type.name}', enabled);
    }
    if (intervalMinutes != null) {
      await prefs.setInt('$_kIntervalPrefix${type.name}', intervalMinutes);
    }
  }

  /// Compatibilidad con la versión anterior (un solo intervalo).
  Future<int> getAlertIntervalMinutes() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kIntervalMinutesKey) ?? kDefaultIntervalMinutes;
  }

  Future<void> setAlertIntervalMinutes(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kIntervalMinutesKey, minutes);
  }

  // ---------------------------------------------------------------
  // Mostrar notificaciones
  // ---------------------------------------------------------------

  /// Muestra la notificación sin ningún chequeo (lo usan el botón de
  /// prueba y [_show]).
  Future<void> _display(
      int id, String title, String body, String complexId) async {
    final prefs = await SharedPreferences.getInstance();
    final version = prefs.getInt(_kSoundVersionKey) ?? 1;
    final c = complexById(complexId);
    final sound = _soundFrom(prefs);

    NotificationDetails details(String icon) => NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId(c.id, version),
            'Alertas ${c.shortName}',
            channelDescription: 'Alertas de ${c.name}',
            importance: Importance.high,
            priority: Priority.high,
            playSound: true,
            sound: sound,
            icon: icon,
            ticker: title,
            styleInformation: BigTextStyleInformation(body),
            category: AndroidNotificationCategory.reminder,
            visibility: NotificationVisibility.public,
            groupKey: 'fleet_group_${c.id}',
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentSound: true,
          ),
        );

    final fullTitle = '${c.shortName} · $title';
    try {
      await _plugin.show(id, fullTitle, body, details('ic_stat_fleet'));
    } on PlatformException {
      // Si el ícono de la barra de estado no se encuentra, se muestra
      // igual con el ícono de la app: mejor eso que no avisar.
      await _plugin.show(id, fullTitle, body, details('@mipmap/ic_launcher'));
    }
  }

  /// Notificación de prueba para escuchar el sonido y ver cómo se
  /// muestra en la barra de arriba.
  /// Devuelve null si salió bien, o un texto explicando qué pasó.
  Future<String?> showTest() async {
    final enabled = await requestPermission();
    if (!enabled) {
      return 'Las notificaciones están bloqueadas para esta app. Activalas '
          'en Ajustes del celular → Aplicaciones → esta app → '
          'Notificaciones.';
    }
    try {
      await _display(
        990001,
        'Prueba de notificación',
        'Así se verá y sonará una alerta de la app.',
        kComplexes.first.id,
      );
      return null;
    } catch (e) {
      return 'No se pudo mostrar la notificación: $e';
    }
  }

  /// Muestra una notificación de un complejo puntual. Solo sale si ese
  /// tipo de aviso está encendido Y hay un usuario con sesión iniciada
  /// habilitado en ese complejo (el admin ve los 4).
  Future<void> _show(AlertType type, int id, String title, String body,
      String complexId) async {
    final cfg = await getConfig(type);
    if (!cfg.enabled) return;
    final user = await AuthService.instance.currentUser();
    if (user == null || !user.canAccess(complexId)) return;
    await _display(id, title, body, complexId);
  }

  Future<void> notifyVehicleMaintenance(Vehicle v) async {
    if (v.maintenanceStatus == MaintenanceStatus.ok) return;
    final title = v.maintenanceStatus == MaintenanceStatus.overdue
        ? 'Service vencido'
        : 'Service próximo';
    final body = v.maintenanceStatus == MaintenanceStatus.overdue
        ? 'La unidad ${v.internalNumber} (${v.plate}) superó el kilometraje de service.'
        : 'La unidad ${v.internalNumber} (${v.plate}) está a ${v.kmRemaining} km del próximo service.';
    await _show(AlertType.maintenance, v.plate.hashCode, title, body,
        v.complexId);
  }

  Future<void> notifyDriverLicense(Driver d) async {
    if (d.licenseStatus == LicenseStatus.ok) return;
    final days = d.daysToLicenseExpiration;
    final title = d.licenseStatus == LicenseStatus.expired
        ? 'Carnet vencido'
        : 'Carnet por vencer';
    final body = d.licenseStatus == LicenseStatus.expired
        ? '${d.fullName} tiene el carnet de conducir vencido.'
        : '${d.fullName} tiene el carnet vence en $days días.';
    await _show(AlertType.license, d.documentId.hashCode, title, body,
        d.complexId);
  }

  /// Aviso de que un vehículo llegó (o superó) el límite mensual de
  /// combustible. Salta en el momento en que se cruza el umbral (ver
  /// FuelProvider.addFuelLog); si en los ajustes se elige repetirlo,
  /// la tarea en segundo plano lo vuelve a mandar según esa frecuencia.
  Future<void> notifyFuelLimitReached(Vehicle v, double totalLiters) async {
    await _show(
      AlertType.fuelLimit,
      'fuel_limit_${v.id}'.hashCode,
      'Límite de combustible alcanzado',
      'La unidad ${v.internalNumber} (${v.plate}) llegó a '
          '${totalLiters.toStringAsFixed(1)} litros cargados este mes.',
      v.complexId,
    );
  }

  /// Aviso previo: salta al 90 % del límite mensual.
  Future<void> notifyFuelLimitApproaching(
      Vehicle v, double totalLiters, double limit) async {
    await _show(
      AlertType.fuelApproaching,
      'fuel_limit_approaching_${v.id}'.hashCode,
      'Acercándose al límite de combustible',
      'La unidad ${v.internalNumber} (${v.plate}) ya cargó '
          '${totalLiters.toStringAsFixed(1)} de ${limit.toStringAsFixed(1)} '
          'litros permitidos este mes.',
      v.complexId,
    );
  }

  /// Recorre listas completas y dispara las notificaciones de todos los
  /// casos en warning/overdue, sin mirar frecuencias.
  Future<void> checkAndNotifyAll(
      List<Vehicle> vehicles, List<Driver> drivers) async {
    for (final v in vehicles) {
      await notifyVehicleMaintenance(v);
    }
    for (final d in drivers) {
      await notifyDriverLicense(d);
    }
  }

  // ---------------------------------------------------------------
  // Frecuencia por tipo y por complejo
  // ---------------------------------------------------------------

  String _lastKey(AlertType type, String complexId) =>
      '$_kLastPrefix${type.name}_$complexId';

  /// true si el tipo está encendido, tiene repetición (intervalo > 0)
  /// y ya pasó su intervalo desde el último aviso de ese complejo.
  Future<bool> _isDue(
      SharedPreferences prefs, AlertType type, String complexId) async {
    final cfg = _readConfig(prefs, type);
    if (!cfg.enabled || cfg.intervalMinutes <= 0) return false;
    final lastStr = prefs.getString(_lastKey(type, complexId));
    final last = lastStr != null ? DateTime.tryParse(lastStr) : null;
    if (last == null) return true;
    return DateTime.now().difference(last).inMinutes >= cfg.intervalMinutes;
  }

  Future<void> _markFired(
      SharedPreferences prefs, AlertType type, String complexId) async {
    await prefs.setString(
        _lastKey(type, complexId), DateTime.now().toIso8601String());
  }

  /// Igual que [checkAndNotifyAll], pero cada tipo de aviso respeta su
  /// propia frecuencia. Se usa desde la tarea en segundo plano y al
  /// abrir la app.
  Future<void> checkAndNotifyAllIfDue(
      List<Vehicle> vehicles, List<Driver> drivers) async {
    // Sin sesión iniciada no se notifica nada.
    final user = await AuthService.instance.currentUser();
    if (user == null) return;

    final prefs = await SharedPreferences.getInstance();

    // Cada complejo tiene sus propios relojes: solo se revisan los
    // complejos a los que el usuario está habilitado.
    for (final c in kComplexes) {
      if (!user.canAccess(c.id)) continue;
      final cVehicles = vehicles.where((v) => v.complexId == c.id).toList();
      final cDrivers = drivers.where((d) => d.complexId == c.id).toList();

      // Service
      final pendingService = cVehicles
          .where((v) => v.maintenanceStatus != MaintenanceStatus.ok)
          .toList();
      if (pendingService.isNotEmpty &&
          await _isDue(prefs, AlertType.maintenance, c.id)) {
        for (final v in pendingService) {
          await notifyVehicleMaintenance(v);
        }
        await _markFired(prefs, AlertType.maintenance, c.id);
      }

      // Carnet
      final pendingLicense = cDrivers
          .where((d) => d.licenseStatus != LicenseStatus.ok)
          .toList();
      if (pendingLicense.isNotEmpty &&
          await _isDue(prefs, AlertType.license, c.id)) {
        for (final d in pendingLicense) {
          await notifyDriverLicense(d);
        }
        await _markFired(prefs, AlertType.license, c.id);
      }

      // Combustible
      await _repeatFuelAlerts(prefs, c.id, cVehicles);
    }
  }

  /// Repite los avisos de combustible de un complejo, solo si en los
  /// ajustes se eligió una frecuencia (distinta de "Solo una vez").
  Future<void> _repeatFuelAlerts(
      SharedPreferences prefs, String complexId, List<Vehicle> vehicles) async {
    final wantsApproaching = await _isDue(prefs, AlertType.fuelApproaching, complexId);
    final wantsLimit = await _isDue(prefs, AlertType.fuelLimit, complexId);
    if (!wantsApproaching && !wantsLimit) return;

    final now = DateTime.now();
    final monthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final reached = <_FuelHit>[];
    final approaching = <_FuelHit>[];
    for (final v in vehicles) {
      final limit = v.monthlyFuelLimitLiters;
      if (limit == null || limit <= 0) continue;
      final logs =
          await DatabaseHelper.instance.getFuelLogsForMonth(v.id, monthKey);
      var total = 0.0;
      for (final l in logs) {
        total += l.liters.toDouble();
      }
      if (total >= limit) {
        reached.add(_FuelHit(v, total, limit));
      } else if (total >= limit * 0.9) {
        approaching.add(_FuelHit(v, total, limit));
      }
    }

    if (wantsLimit && reached.isNotEmpty) {
      for (final h in reached) {
        await notifyFuelLimitReached(h.vehicle, h.total);
      }
      await _markFired(prefs, AlertType.fuelLimit, complexId);
    }
    if (wantsApproaching && approaching.isNotEmpty) {
      for (final h in approaching) {
        await notifyFuelLimitApproaching(h.vehicle, h.total, h.limit);
      }
      await _markFired(prefs, AlertType.fuelApproaching, complexId);
    }
  }

  /// Revisa todas las alertas pendientes (leyendo directo de la base
  /// local) y notifica solo las de los complejos habilitados para el
  /// usuario que tiene la sesión iniciada. Lo usan tanto la apertura
  /// de la app como la tarea en segundo plano.
  Future<void> checkForCurrentUser() async {
    // La tarea en segundo plano corre en un isolate aparte con su
    // propia copia en memoria de las preferencias: se recarga desde
    // disco para ver la configuración (intervalos, sonido, "último
    // aviso") que se cambió con la app abierta.
    try {
      await (await SharedPreferences.getInstance()).reload();
    } catch (_) {}
    final user = await AuthService.instance.currentUser();
    if (user == null) return;
    final db = DatabaseHelper.instance;
    final vehicles = await db.getVehicles();
    final drivers = await db.getDrivers();
    await checkAndNotifyAllIfDue(vehicles, drivers);
  }
}
