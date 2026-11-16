import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/driver.dart';
import '../models/fuel_log.dart';
import '../models/maintenance_record.dart';
import '../models/procedure.dart';
import '../models/user_account.dart';
import '../models/vehicle.dart';
import '../models/vehicle_tech_sheet.dart';
import 'database_helper.dart';
import 'drive_backup_service.dart';
import 'sync_service.dart';

const kLastBackupAtKey = 'last_backup_at';

/// Nombre base de todos los respaldos (archivo local, nube y Drive).
const kBackupBaseName = 'respaldo P.A.B.P';

/// Fecha y hora de carga para el nombre: "2026-11-06 10-30".
String backupStamp([DateTime? t]) =>
    DateFormat('yyyy-MM-dd HH-mm').format(t ?? DateTime.now());

/// "respaldo P.A.B.P 2026-11-06 10-30.json"
String backupFileName([DateTime? t]) =>
    '$kBackupBaseName ${backupStamp(t)}.json';

/// Genera y restaura respaldos completos de la base de datos local en
/// formato JSON.
///
/// Hay dos formas de disparar un respaldo:
/// - MANUAL: botón "Exportar ahora" en la pantalla de administración,
///   que genera el archivo y abre el selector para compartirlo
///   (WhatsApp, mail, Drive, guardar en el celular, etc.)
/// - AUTOMÁTICO: cada 3 horas (ver [BackgroundService]), en silencio,
///   sin abrir ningún selector. Si hay nube conectada, además sube el
///   archivo a Firebase Storage; si no hay nube, igual queda un
///   archivo de respaldo guardado en el almacenamiento del propio
///   celular.
///
/// IMPORTANTE: el respaldo incluye los DATOS (vehículos, choferes,
/// combustible, etc.) pero NO las fotos en sí — guarda las RUTAS
/// locales de los archivos de foto, que solo tienen sentido en el
/// celular donde se tomaron. Para que las fotos también viajen entre
/// dispositivos hace falta que Firebase Storage esté conectado (ver
/// [CloudStorageService]).
class BackupService {
  BackupService._internal();
  static final BackupService instance = BackupService._internal();

  Future<Map<String, dynamic>> _buildBackupMap() async {
    final db = DatabaseHelper.instance;
    final vehicles = await db.getVehicles(includeArchived: true);

    final fuelLogs = <Map<String, dynamic>>[];
    final techSheets = <Map<String, dynamic>>[];
    final maintenanceRecords = <Map<String, dynamic>>[];
    for (final v in vehicles) {
      for (final month in await db.getFuelLogMonths(v.id)) {
        for (final f in await db.getFuelLogsForMonth(v.id, month)) {
          fuelLogs.add(f.toMap());
        }
      }
      for (final t in await db.getTechSheetEntries(v.id)) {
        techSheets.add(t.toMap());
      }
      for (final r in await db.getMaintenanceRecords(v.id)) {
        maintenanceRecords.add(r.toMap());
      }
    }

    return {
      'generated_at': DateTime.now().toIso8601String(),
      'vehicles': vehicles.map((v) => v.toMap()).toList(),
      'drivers': (await db.getDrivers(includeArchived: true))
          .map((d) => d.toMap())
          .toList(),
      // Solo usuarios comunes: el usuario god nunca sale del
      // dispositivo, ni siquiera en un respaldo.
      'common_users':
          (await db.getCommonUsers()).map((u) => u.toMap()).toList(),
      'maintenance_records': maintenanceRecords,
      'fuel_logs': fuelLogs,
      'vehicle_tech_sheets': techSheets,
      'procedures':
          (await db.getProcedures()).map((p) => p.toMap()).toList(),
    };
  }

  Future<File> _writeToTempFile(Map<String, dynamic> data) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${backupFileName()}');
    await file.writeAsBytes(utf8.encode(jsonEncode(data)), flush: true);
    return file;
  }

  /// Genera el respaldo y abre el selector para compartirlo/guardarlo.
  Future<void> exportAndShare() async {
    final data = await _buildBackupMap();
    final file = await _writeToTempFile(data);
    await _markBackedUpNow();
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/json')],
      text: 'Respaldo P.A.B.P — '
          '${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
    );
  }

  /// Respaldo silencioso: se llama desde la tarea en segundo plano
  /// cada 3 horas. No abre ningún selector. Guarda una copia local y,
  /// si hay nube conectada, también la sube a Firebase Storage.
  Future<void> runAutoBackup() async {
    try {
      final data = await _buildBackupMap();
      final jsonStr = jsonEncode(data);

      final docsDir = await getApplicationDocumentsDirectory();
      final localFile = File('${docsDir.path}/$kBackupBaseName ultimo.json');
      await localFile.writeAsBytes(utf8.encode(jsonStr), flush: true);

      if (SyncService.instance.isCloudEnabled) {
        try {
          final storage = FirebaseStorage.instance;
          await storage
              .ref('backups/$kBackupBaseName ultimo.json')
              .putString(jsonStr, format: PutStringFormat.raw);
          await storage
              .ref('backups/${backupFileName()}')
              .putString(jsonStr, format: PutStringFormat.raw);
        } catch (_) {
          // Sin conexión en el momento del respaldo automático: la
          // copia local ya quedó guardada, se reintenta la próxima vez.
        }
      }
      // Copia en el Google Drive del admin (si está configurado). Si
      // falla (sin internet, sesión vencida), no afecta al resto.
      try {
        await backupToDrive();
      } catch (_) {}
      await _markBackedUpNow();
    } catch (_) {
      // Un respaldo fallido nunca debe interrumpir el resto de la app.
    }
  }

  /// Sube el respaldo completo al Google Drive que eligió el admin
  /// (si este dispositivo ya tiene una cuenta elegida). El archivo es
  /// privado, solo del admin.
  Future<bool> backupToDrive({bool interactive = false}) async {
    final data = await _buildBackupMap();
    return DriveBackupService.instance
        .uploadBackup(jsonEncode(data), interactive: interactive);
  }

  /// Abre el selector de guardado del sistema para elegir DÓNDE guardar el
  /// respaldo: el celular, Google Drive u otra app de archivos. Devuelve
  /// false si se canceló.
  Future<bool> saveWithPicker() async {
    final data = await _buildBackupMap();
    final bytes = Uint8List.fromList(utf8.encode(jsonEncode(data)));
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Guardar respaldo',
      fileName: backupFileName(),
      bytes: bytes,
    );
    if (path == null) return false;
    await _markBackedUpNow();
    return true;
  }

  Future<void> _markBackedUpNow() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kLastBackupAtKey, DateTime.now().toIso8601String());
  }

  Future<DateTime?> getLastBackupAt() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(kLastBackupAtKey);
    return value == null ? null : DateTime.tryParse(value);
  }

  /// Respaldo automático "inteligente": solo corre si pasaron al
  /// menos [minInterval] desde el último respaldo (por defecto, 3
  /// horas). Se llama desde la tarea en segundo plano cada 15
  /// minutos (mínimo técnico de Android para tareas periódicas), pero
  /// el respaldo en sí solo se ejecuta de verdad cada 3 horas.
  Future<void> runAutoBackupIfDue({
    Duration minInterval = const Duration(hours: 3),
  }) async {
    final last = await getLastBackupAt();
    if (last != null && DateTime.now().difference(last) < minInterval) {
      return;
    }
    await runAutoBackup();
  }

  /// Restaura un respaldo JSON como el que genera [exportAndShare].
  /// No borra nada que ya esté cargado: hace upsert (inserta o
  /// reemplaza por id) de todo lo que venga en el archivo.
  ///
  /// Con [smart] = true (lo usa la actualización desde Google Drive)
  /// se aplican reglas más cuidadosas, porque ese respaldo puede ser
  /// más viejo que lo que ya hay en el dispositivo:
  /// - un vehículo/chofer solo se pisa si el del respaldo tiene fecha
  ///   de edición MÁS NUEVA que el local;
  /// - nada de lo que se borró definitivamente vuelve a aparecer;
  /// - un registro huérfano o dañado se saltea sin cortar el resto.
  Future<void> restoreFromJsonString(String jsonStr,
      {bool smart = false}) async {
    final data = jsonDecode(jsonStr) as Map<String, dynamic>;
    final db = DatabaseHelper.instance;

    if (smart) {
      await _restoreSmart(data, db);
      return;
    }

    for (final raw in (data['vehicles'] as List? ?? [])) {
      await db.insertVehicle(Vehicle.fromMap(raw as Map<String, dynamic>));
    }
    for (final raw in (data['drivers'] as List? ?? [])) {
      await db.insertDriver(Driver.fromMap(raw as Map<String, dynamic>));
    }
    for (final raw in (data['common_users'] as List? ?? [])) {
      final user = UserAccount.fromMap(raw as Map<String, dynamic>);
      if (user.role == UserRole.common) await db.insertUser(user);
    }
    for (final raw in (data['maintenance_records'] as List? ?? [])) {
      await db.insertMaintenanceRecord(
          MaintenanceRecord.fromMap(raw as Map<String, dynamic>));
    }
    for (final raw in (data['fuel_logs'] as List? ?? [])) {
      await db.insertFuelLog(FuelLog.fromMap(raw as Map<String, dynamic>));
    }
    for (final raw in (data['vehicle_tech_sheets'] as List? ?? [])) {
      await db.insertTechSheetEntry(
          TechSheetEntry.fromMap(raw as Map<String, dynamic>));
    }
    for (final raw in (data['procedures'] as List? ?? [])) {
      await db.insertProcedure(Procedure.fromMap(raw as Map<String, dynamic>));
    }
  }

  Future<void> _restoreSmart(
      Map<String, dynamic> data, DatabaseHelper db) async {
    final tomb = <String>{
      for (final t in await db.getTombstones()) '${t['type']}:${t['id']}'
    };
    final localVehicles = {
      for (final v in await db.getVehicles(includeArchived: true)) v.id: v
    };
    final localDrivers = {
      for (final d in await db.getDrivers(includeArchived: true)) d.id: d
    };

    for (final raw in (data['vehicles'] as List? ?? [])) {
      try {
        final v = Vehicle.fromMap(raw as Map<String, dynamic>);
        if (tomb.contains('vehicle:${v.id}')) continue;
        final local = localVehicles[v.id];
        if (local != null && !v.updatedAt.isAfter(local.updatedAt)) continue;
        await db.insertVehicle(v);
      } catch (_) {}
    }
    for (final raw in (data['drivers'] as List? ?? [])) {
      try {
        final d = Driver.fromMap(raw as Map<String, dynamic>);
        if (tomb.contains('driver:${d.id}')) continue;
        final local = localDrivers[d.id];
        if (local != null && !d.updatedAt.isAfter(local.updatedAt)) continue;
        await db.insertDriver(d);
      } catch (_) {}
    }
    for (final raw in (data['common_users'] as List? ?? [])) {
      try {
        final user = UserAccount.fromMap(raw as Map<String, dynamic>);
        if (tomb.contains('user:${user.id}')) continue;
        if (user.role == UserRole.common) await db.insertUser(user);
      } catch (_) {}
    }

    bool orphan(Map<String, dynamic> raw) =>
        tomb.contains('vehicle:${raw['vehicle_id']}');

    for (final raw in (data['maintenance_records'] as List? ?? [])) {
      try {
        final m = raw as Map<String, dynamic>;
        if (orphan(m)) continue;
        await db.insertMaintenanceRecord(MaintenanceRecord.fromMap(m));
      } catch (_) {}
    }
    for (final raw in (data['fuel_logs'] as List? ?? [])) {
      try {
        final m = raw as Map<String, dynamic>;
        if (orphan(m)) continue;
        await db.insertFuelLog(FuelLog.fromMap(m));
      } catch (_) {}
    }
    for (final raw in (data['vehicle_tech_sheets'] as List? ?? [])) {
      try {
        final m = raw as Map<String, dynamic>;
        if (orphan(m)) continue;
        await db.insertTechSheetEntry(TechSheetEntry.fromMap(m));
      } catch (_) {}
    }

    final localProcedures = {
      for (final p in await db.getProcedures()) p.id: p
    };
    for (final raw in (data['procedures'] as List? ?? [])) {
      try {
        final p = Procedure.fromMap(raw as Map<String, dynamic>);
        if (tomb.contains('procedure:${p.id}')) continue;
        final local = localProcedures[p.id];
        if (local != null && !p.updatedAt.isAfter(local.updatedAt)) continue;
        await db.insertProcedure(p);
      } catch (_) {}
    }
  }
}
