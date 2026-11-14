import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/complex.dart';
import '../models/driver.dart';
import '../models/vehicle.dart';
import 'auth_service.dart';
import 'database_helper.dart';

/// Encapsula las notificaciones push locales del sistema operativo
/// (Android/iOS) para alertas de service y vencimiento de carnet.
///
/// Estas notificaciones salen del sistema operativo (aparecen en la
/// barra de notificaciones del celular, con sonido) incluso con la
/// app cerrada, siempre que haya sido [BackgroundService] quien las
/// disparó desde la tarea programada (ver background_service.dart).
///
/// CADA CUÁNTO SUENA: el usuario administrador (god) regula el
/// intervalo mínimo entre una alerta sonora y la siguiente desde el
/// panel de administración ([getAlertIntervalMinutes] /
/// [setAlertIntervalMinutes]). Por defecto es cada 60 minutos. Esto
/// evita que, si hay varios vencimientos pendientes, el celular esté
/// sonando todo el tiempo — pero mientras haya algo vencido o por
/// vencer, la alerta se repite cada tanto hasta que se resuelva.
///
/// Para que el sonido personalizado funcione en Android hace falta
/// colocar el archivo de audio en
/// `android/app/src/main/res/raw/alert_sound.wav` (ver README /
/// guía de entrega). Si ese archivo no está, Android usa el sonido
/// de notificación por defecto del sistema — la notificación igual
/// sale, solo cambia el sonido.
class NotificationService {
  NotificationService._internal();
  static final NotificationService instance = NotificationService._internal();

  static const _kIntervalMinutesKey = 'alert_sound_interval_minutes';
  static const _kLastFiredAtKey = 'alert_sound_last_fired_at';
  static const int kDefaultIntervalMinutes = 60;

  /// Opciones que se ofrecen en el panel de administración.
  static const List<int> kIntervalOptionsMinutes = [
    15, 30, 60, 120, 180, 360, 720, 1440,
  ];

  final _plugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings =
        InitializationSettings(android: androidInit, iOS: iosInit);
    await _plugin.initialize(settings);

    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    // Android 13+ exige pedir el permiso de notificaciones en tiempo
    // de ejecución; en versiones anteriores este llamado no hace nada.
    await androidImpl?.requestNotificationsPermission();

    // Un canal Android por complejo (cada uno con su sonido de
    // alerta propio): así cada complejo tiene sus notificaciones
    // individuales y el usuario puede ajustarlas por separado desde
    // los ajustes del celular.
    for (final c in kComplexes) {
      await androidImpl?.createNotificationChannel(
        AndroidNotificationChannel(
          'fleet_alerts_${c.id}',
          'Alertas ${c.shortName}',
          description: 'Alertas de ${c.name}',
          importance: Importance.high,
          sound: const RawResourceAndroidNotificationSound('alert_sound'),
          playSound: true,
        ),
      );
    }
  }

  /// Cada cuánto (en minutos) se repite la alerta sonora mientras haya
  /// algo pendiente. Configurable por el administrador.
  Future<int> getAlertIntervalMinutes() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kIntervalMinutesKey) ?? kDefaultIntervalMinutes;
  }

  Future<void> setAlertIntervalMinutes(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kIntervalMinutesKey, minutes);
  }

  /// Muestra una notificación de un complejo puntual. Solo sale si
  /// hay un usuario con sesión iniciada Y habilitado en ese complejo
  /// (el admin ve los 4). Cada complejo usa su propio canal y su
  /// propio grupo en la barra de notificaciones.
  Future<void> _show(
      int id, String title, String body, String complexId) async {
    final user = await AuthService.instance.currentUser();
    if (user == null || !user.canAccess(complexId)) return;

    final c = complexById(complexId);
    final androidDetails = AndroidNotificationDetails(
      'fleet_alerts_${c.id}',
      'Alertas ${c.shortName}',
      channelDescription: 'Alertas de ${c.name}',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      sound: const RawResourceAndroidNotificationSound('alert_sound'),
      groupKey: 'fleet_group_${c.id}',
    );
    const iosDetails = DarwinNotificationDetails(
      sound: 'alert_sound.wav',
      presentSound: true,
    );
    final details =
        NotificationDetails(android: androidDetails, iOS: iosDetails);
    await _plugin.show(id, '${c.shortName} · $title', body, details);
  }

  Future<void> notifyVehicleMaintenance(Vehicle v) async {
    if (v.maintenanceStatus == MaintenanceStatus.ok) return;
    final title = v.maintenanceStatus == MaintenanceStatus.overdue
        ? 'Service vencido'
        : 'Service próximo';
    final body = v.maintenanceStatus == MaintenanceStatus.overdue
        ? 'La unidad ${v.internalNumber} (${v.plate}) superó el kilometraje de service.'
        : 'La unidad ${v.internalNumber} (${v.plate}) está a ${v.kmRemaining} km del próximo service.';
    await _show(v.plate.hashCode, title, body, v.complexId);
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
    await _show(d.documentId.hashCode, title, body, d.complexId);
  }

  /// Alerta de que un vehículo llegó (o superó) el límite mensual de
  /// combustible que le fijó el admin. Se dispara una sola vez, justo
  /// en el momento en que se cruza el umbral (ver
  /// FuelProvider.addFuelLog), no en cada carga posterior.
  Future<void> notifyFuelLimitReached(Vehicle v, double totalLiters) async {
    await _show(
      'fuel_limit_${v.id}'.hashCode,
      'Límite de combustible alcanzado',
      'La unidad ${v.internalNumber} (${v.plate}) llegó a '
          '${totalLiters.toStringAsFixed(1)} litros cargados este mes.',
      v.complexId,
    );
  }

  /// Aviso previo al de "límite alcanzado": salta al 90% del límite
  /// mensual, para que haya margen de reacción antes de llegar al
  /// tope. Mismo canal con sonido + aparece en la barra de
  /// notificaciones, igual que todas las demás.
  Future<void> notifyFuelLimitApproaching(
      Vehicle v, double totalLiters, double limit) async {
    await _show(
      'fuel_limit_approaching_${v.id}'.hashCode,
      'Acercándose al límite de combustible',
      'La unidad ${v.internalNumber} (${v.plate}) ya cargó '
          '${totalLiters.toStringAsFixed(1)} de ${limit.toStringAsFixed(1)} '
          'litros permitidos este mes.',
      v.complexId,
    );
  }

  /// Recorre listas completas y dispara notificaciones para todos los
  /// casos en warning/overdue. Pensado para llamarse al abrir la app
  /// o desde una tarea programada en background.
  Future<void> checkAndNotifyAll(
      List<Vehicle> vehicles, List<Driver> drivers) async {
    for (final v in vehicles) {
      await notifyVehicleMaintenance(v);
    }
    for (final d in drivers) {
      await notifyDriverLicense(d);
    }
  }

  /// Igual que [checkAndNotifyAll], pero respeta el intervalo mínimo
  /// configurado por el administrador entre una alerta sonora y la
  /// siguiente. Se usa desde la tarea en segundo plano: esta se
  /// ejecuta cada 15 minutos (mínimo técnico de Android), pero el
  /// sonido de alerta en sí solo se repite según lo que haya elegido
  /// el admin en el panel (por defecto, cada 60 minutos).
  Future<void> checkAndNotifyAllIfDue(
      List<Vehicle> vehicles, List<Driver> drivers) async {
    // Sin sesión iniciada no se notifica nada.
    final user = await AuthService.instance.currentUser();
    if (user == null) return;

    final prefs = await SharedPreferences.getInstance();
    final intervalMinutes =
        prefs.getInt(_kIntervalMinutesKey) ?? kDefaultIntervalMinutes;

    // Cada complejo tiene su propio reloj de alertas: solo se
    // revisan los complejos a los que el usuario está habilitado.
    for (final c in kComplexes) {
      if (!user.canAccess(c.id)) continue;

      final key = '${_kLastFiredAtKey}_${c.id}';
      final lastFiredStr = prefs.getString(key);
      final lastFired =
          lastFiredStr != null ? DateTime.tryParse(lastFiredStr) : null;
      final due = lastFired == null ||
          DateTime.now().difference(lastFired).inMinutes >= intervalMinutes;
      if (!due) continue;

      await checkAndNotifyAll(
        vehicles.where((v) => v.complexId == c.id).toList(),
        drivers.where((d) => d.complexId == c.id).toList(),
      );
      await prefs.setString(key, DateTime.now().toIso8601String());
    }
  }

  /// Revisa todas las alertas pendientes (leyendo directo de la base
  /// local) y notifica solo las de los complejos habilitados para el
  /// usuario que tiene la sesión iniciada. Lo usan tanto la apertura
  /// de la app como la tarea en segundo plano.
  Future<void> checkForCurrentUser() async {
    final user = await AuthService.instance.currentUser();
    if (user == null) return;
    final db = DatabaseHelper.instance;
    final vehicles = await db.getVehicles();
    final drivers = await db.getDrivers();
    await checkAndNotifyAllIfDue(vehicles, drivers);
  }
}
