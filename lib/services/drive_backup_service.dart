import 'dart:async';
import 'dart:convert';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_account.dart';
import 'auth_service.dart';
import 'backup_service.dart';

const _kAdminEmailKey = 'drive_admin_email';
const _kFolderIdKey = 'drive_folder_id';
const _kFileIdKey = 'drive_file_id';
const _kLastUploadAtKey = 'drive_last_upload_at';
const _kLastPullAtKey = 'drive_last_pull_at';

const _kFolderName = 'Parque Automotor - Respaldo';
// Nombre con el que se guardaban los respaldos antes (se sigue
// reconociendo al restaurar). Los nuevos se llaman
// "respaldo P.A.B.P <fecha y hora de carga>.json" (ver backupFileName).
// ignore: unused_element
const _kLegacyFileName = 'respaldo_parque_automotor.json';

enum DrivePullResult { updated, notFound, notConfigured, failed }

/// Respaldo en el Google Drive del ADMINISTRADOR.
///
/// - SOLO el admin (usuario god) usa Drive: elige la cuenta de Google,
///   y desde ahí sube y baja el respaldo. Los usuarios comunes no
///   ven ni usan nada de esto; ellos reciben los datos por la
///   sincronización normal de la app (Firestore).
/// - La app crea en ese Drive la carpeta `Parque Automotor - Respaldo`
///   con un único archivo que se va ACTUALIZANDO (Drive guarda el
///   historial de versiones por su cuenta). El archivo es PRIVADO:
///   no se comparte con nadie.
/// - Permiso: solo `drive.file` (archivos creados por esta app, nunca
///   el resto del Drive). Funciona en cualquier celular donde el
///   admin inicie sesión con la misma cuenta.
class DriveBackupService {
  DriveBackupService._internal();
  static final DriveBackupService instance = DriveBackupService._internal();

  final GoogleSignIn _googleSignIn =
      GoogleSignIn(scopes: [drive.DriveApi.driveFileScope]);

  Future<String?> adminEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kAdminEmailKey);
  }

  /// true en el dispositivo donde el admin ya eligió la cuenta de Drive.
  Future<bool> isConfigured() async => (await adminEmail()) != null;

  Future<DateTime?> lastUploadAt() => _readDate(_kLastUploadAtKey);
  Future<DateTime?> lastPullAt() => _readDate(_kLastPullAtKey);

  Future<DateTime?> _readDate(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(key);
    return v == null ? null : DateTime.tryParse(v);
  }

  Future<bool> _currentUserIsAdmin() async {
    final user = await AuthService.instance.currentUser();
    return user?.role == UserRole.god;
  }

  /// Abre el selector de cuentas de Google. Devuelve el mail elegido,
  /// o null si el admin canceló.
  Future<String?> chooseAccount() async {
    try {
      // Cerrar la sesión previa fuerza a que aparezca SIEMPRE el
      // selector de cuentas.
      await _googleSignIn.signOut();
    } catch (_) {}
    final account = await _googleSignIn.signIn();
    if (account == null) return null;

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_kAdminEmailKey) != account.email) {
      await prefs.remove(_kFolderIdKey);
      await prefs.remove(_kFileIdKey);
    }
    await prefs.setString(_kAdminEmailKey, account.email);
    return account.email;
  }

  /// Deja de usar Drive en este dispositivo (no borra nada de Drive).
  Future<void> disconnect() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kAdminEmailKey);
    await prefs.remove(_kFolderIdKey);
    await prefs.remove(_kFileIdKey);
  }

  Future<dynamic> _authClient() async {
    final account =
        _googleSignIn.currentUser ?? await _googleSignIn.signInSilently();
    if (account == null) return null;
    return _googleSignIn.authenticatedClient();
  }

  /// Sube (o actualiza) el respaldo en el Drive del admin.
  Future<bool> uploadBackup(String jsonStr, {bool retry = true}) async {
    if (!await isConfigured()) return false;
    final client = await _authClient();
    if (client == null) return false;

    final prefs = await SharedPreferences.getInstance();
    try {
      final api = drive.DriveApi(client);
      final bytes = utf8.encode(jsonStr);
      drive.Media media() => drive.Media(
            Stream<List<int>>.value(bytes),
            bytes.length,
            contentType: 'application/json',
          );

      var folderId = prefs.getString(_kFolderIdKey);
      var fileId = prefs.getString(_kFileIdKey);

      if (folderId == null) {
        final folder = await api.files.create(
          drive.File()
            ..name = _kFolderName
            ..mimeType = 'application/vnd.google-apps.folder',
          $fields: 'id',
        );
        folderId = folder.id;
        await prefs.setString(_kFolderIdKey, folderId!);
      }

      if (fileId != null) {
        try {
          await api.files.update(
            drive.File()..name = backupFileName(),
            fileId,
            uploadMedia: media(),
          );
        } on drive.DetailedApiRequestError catch (e) {
          if (e.status == 404) {
            fileId = null; // lo borraron desde Drive: se crea de nuevo
          } else {
            rethrow;
          }
        }
      }

      if (fileId == null) {
        final created = await api.files.create(
          drive.File()
            ..name = backupFileName()
            ..mimeType = 'application/json'
            ..parents = [folderId!],
          uploadMedia: media(),
          $fields: 'id',
        );
        await prefs.setString(_kFileIdKey, created.id!);
      }

      await prefs.setString(
          _kLastUploadAtKey, DateTime.now().toIso8601String());
      return true;
    } on drive.DetailedApiRequestError catch (e) {
      if (e.status == 404 && retry) {
        // La carpeta o el archivo ya no existen: se arma todo de nuevo.
        await prefs.remove(_kFolderIdKey);
        await prefs.remove(_kFileIdKey);
        return uploadBackup(jsonStr, retry: false);
      }
      rethrow;
    } finally {
      try {
        client.close();
      } catch (_) {}
    }
  }

  /// Baja el respaldo del Drive del admin y lo aplica sin pisar nada
  /// más nuevo que ya tenga este dispositivo. Si el celular no tiene
  /// guardado el ID del archivo (por ejemplo, es un celular nuevo), lo
  /// busca por nombre en el Drive.
  Future<DrivePullResult> pullLatest() async {
    if (!await isConfigured()) return DrivePullResult.notConfigured;
    final client = await _authClient();
    if (client == null) return DrivePullResult.failed;

    final prefs = await SharedPreferences.getInstance();
    try {
      final api = drive.DriveApi(client);
      var fileId = prefs.getString(_kFileIdKey);

      if (fileId == null) {
        // Se busca la carpeta del respaldo y, adentro, el archivo más
        // reciente (el nombre ahora lleva la fecha, así que no se
        // puede buscar por nombre exacto).
        final folders = await api.files.list(
          q: "mimeType = 'application/vnd.google-apps.folder' and "
              "name = '$_kFolderName' and trashed = false",
          pageSize: 1,
          $fields: 'files(id)',
        );
        final folderFiles = folders.files ?? [];
        if (folderFiles.isEmpty || folderFiles.first.id == null) {
          return DrivePullResult.notFound;
        }
        final list = await api.files.list(
          q: "'${folderFiles.first.id}' in parents and trashed = false and "
              "mimeType = 'application/json'",
          orderBy: 'modifiedTime desc',
          pageSize: 1,
          $fields: 'files(id)',
        );
        final files = list.files ?? [];
        if (files.isEmpty || files.first.id == null) {
          return DrivePullResult.notFound;
        }
        fileId = files.first.id;
        await prefs.setString(_kFileIdKey, fileId!);
      }

      final media = await api.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;
      final body = await media.stream.transform(utf8.decoder).join();

      await BackupService.instance.restoreFromJsonString(body, smart: true);
      await prefs.setString(_kLastPullAtKey, DateTime.now().toIso8601String());
      return DrivePullResult.updated;
    } on drive.DetailedApiRequestError catch (e) {
      if (e.status == 404) {
        await prefs.remove(_kFileIdKey);
        return DrivePullResult.notFound;
      }
      rethrow;
    } finally {
      try {
        client.close();
      } catch (_) {}
    }
  }

  /// Se llama al abrir la app y al volver a primer plano. Solo hace
  /// algo si hay una cuenta de Drive elegida en este dispositivo y el
  /// usuario logueado es el admin: sube un respaldo nuevo si pasaron
  /// más de 15 minutos desde el último. Bajar datos es siempre una
  /// acción manual del admin (botón), para no pisar nada por error.
  Future<void> autoSync() async {
    try {
      if (!await isConfigured()) return;
      if (!await _currentUserIsAdmin()) return;
      final last = await lastUploadAt();
      if (last == null ||
          DateTime.now().difference(last) > const Duration(minutes: 15)) {
        await BackupService.instance.backupToDrive();
      }
    } catch (_) {}
  }
}
