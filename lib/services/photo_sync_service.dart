import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Comparte TODAS las fotos de la app (trámites, choferes, carnets,
/// documentos y fotos de vehículos, observaciones, mantenimiento y
/// tickets de combustible) entre todos los dispositivos (admin y
/// usuarios comunes) usando Cloud Firestore, sin Firebase Storage y
/// sin Google Drive.
///
/// Cada foto (ya comprimida por [ImagePickerService]) se guarda como un
/// documento de la colección `shared_photos`, con el contenido en
/// base64. El nombre del archivo (un UUID) es el id del documento. Queda bajo las MISMAS reglas de seguridad que el resto de
/// los datos (ver firestore.rules). Límite: ~650 KB por foto, porque un
/// documento de Firestore no puede pasar de 1 MB.
///
/// Los registros (vehículo, chofer, etc.) siguen guardando la ruta de
/// la foto; en cada celular se usa solo el NOMBRE del archivo ([resolve])
/// para ubicarla en su propia carpeta `fotos/`, y la foto se descarga
/// si todavía no está. Todo es "mejor esfuerzo": sin internet falla en
/// silencio y se reintenta en la próxima sincronización.
class PhotoSyncService {
  PhotoSyncService._internal();
  static final PhotoSyncService instance = PhotoSyncService._internal();

  static const String _kCollection = 'shared_photos';
  // Colección de una versión anterior (solo trámites): se sigue leyendo.
  static const String _kLegacyCollection = 'procedure_photos';
  static const String _kMissKey = 'shared_photos_missing';
  static const Duration _kRetryMissing = Duration(hours: 6);

  static String? _dir;

  /// Se llama una vez al arrancar la app (main.dart).
  Future<void> init() async {
    try {
      _dir = await photosDirPath();
    } catch (_) {}
  }

  /// Ruta de la foto en ESTE dispositivo a partir de lo que guarda el
  /// registro (que puede ser una ruta de otro celular): usa solo el
  /// nombre del archivo y lo busca en la carpeta local `fotos/`.
  static String? resolve(String? stored) {
    if (stored == null || stored.isEmpty) return null;
    final dir = _dir;
    if (dir == null) return stored;
    return p.join(dir, p.basename(stored));
  }
  static const String _kUploadedKey = 'procedure_photos_uploaded';

  /// Tamaño máximo (bytes) de una foto para poder compartirla.
  static const int kMaxPhotoBytes = 650 * 1024;

  static const Duration _kTimeout = Duration(seconds: 20);

  Future<String> photosDirPath() async {
    final appDir = await getApplicationDocumentsDirectory();
    return p.join(appDir.path, 'fotos');
  }

  /// Ruta local que le corresponde a una foto en ESTE dispositivo.
  Future<String> localPathFor(String nameOrPath) async =>
      p.join(await photosDirPath(), p.basename(nameOrPath));

  /// Sube la foto si todavía no se subió. true = ya está en la nube.
  /// Las fotos que pasan de [kMaxPhotoBytes] no se comparten.
  Future<bool> uploadIfMissing(String storedPath, [String? ownerId]) async {
    try {
      final localPath = resolve(storedPath) ?? storedPath;
      final file = File(localPath);
      if (!file.existsSync()) return false;
      final name = p.basename(localPath);

      final prefs = await SharedPreferences.getInstance();
      final done = (prefs.getStringList(_kUploadedKey) ?? <String>[]).toSet();
      if (done.contains(name)) return true;

      final bytes = await file.readAsBytes();
      if (bytes.length > kMaxPhotoBytes) return false;

      await FirebaseFirestore.instance
          .collection(_kCollection)
          .doc(name)
          .set({
        'id': name,
        if (ownerId != null) 'owner_id': ownerId,
        'data_b64': base64Encode(bytes),
        'created_at': DateTime.now().toIso8601String(),
      }).timeout(_kTimeout);

      done.add(name);
      await prefs.setStringList(_kUploadedKey, done.toList());
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Se asegura de que la foto exista en este dispositivo: si no está,
  /// la baja de la nube. Devuelve la ruta local (exista o no el
  /// archivo todavía), para guardarla igual y reintentar más tarde.
  Future<String> ensureLocal(String nameOrPath) async {
    final path = await localPathFor(nameOrPath);
    final file = File(path);
    if (file.existsSync()) return path;
    final name = p.basename(path);

    // Si hace poco se buscó y no estaba en la nube, no se insiste en
    // cada sincronización (ahorra lecturas).
    final prefs = await SharedPreferences.getInstance();
    final misses = _readMisses(prefs);
    final last = misses[name];
    if (last != null &&
        DateTime.now().millisecondsSinceEpoch - last <
            _kRetryMissing.inMilliseconds) {
      return path;
    }

    var found = false;
    try {
      for (final collection in [_kCollection, _kLegacyCollection]) {
        final doc = await FirebaseFirestore.instance
            .collection(collection)
            .doc(name)
            .get()
            .timeout(_kTimeout);
        final b64 = doc.data()?['data_b64'];
        if (b64 is String && b64.isNotEmpty) {
          await Directory(p.dirname(path)).create(recursive: true);
          await file.writeAsBytes(base64Decode(b64), flush: true);
          found = true;
          break;
        }
      }
    } catch (_) {
      try {
        if (file.existsSync()) file.deleteSync();
      } catch (_) {}
      return path; // error de red: se reintenta en la próxima
    }
    if (found) {
      misses.remove(name);
    } else {
      misses[name] = DateTime.now().millisecondsSinceEpoch;
    }
    await prefs.setString(_kMissKey, jsonEncode(misses));
    return path;
  }

  Map<String, int> _readMisses(SharedPreferences prefs) {
    try {
      final raw = prefs.getString(_kMissKey);
      if (raw == null) return {};
      return (jsonDecode(raw) as Map)
          .map((k, v) => MapEntry(k as String, v as int));
    } catch (_) {
      return {};
    }
  }

  /// Sincroniza una foto de un registro: si está en este celular la
  /// sube (si faltaba en la nube); si no está, la descarga.
  Future<void> syncPath(String? stored) async {
    if (stored == null || stored.isEmpty) return;
    final local = resolve(stored) ?? stored;
    if (File(local).existsSync()) {
      await uploadIfMissing(local);
    } else {
      await ensureLocal(stored);
    }
  }

  /// Sube las fotos indicadas (las que existan en este celular).
  Future<void> uploadAll(Iterable<String?> stored) async {
    for (final s in stored) {
      if (s == null || s.isEmpty) continue;
      await uploadIfMissing(s);
    }
  }

  /// Borra varias fotos de la nube (borrado definitivo de un vehículo
  /// o chofer).
  Future<void> deleteRemoteMany(Iterable<String?> stored) async {
    for (final s in stored) {
      if (s == null || s.isEmpty) continue;
      await deleteRemote(s);
    }
  }

  /// Borra la foto de la nube (al quitarla de un trámite o al borrar
  /// el trámite).
  Future<void> deleteRemote(String nameOrPath) async {
    final name = p.basename(nameOrPath);
    try {
      for (final collection in [_kCollection, _kLegacyCollection]) {
        await FirebaseFirestore.instance
            .collection(collection)
            .doc(name)
            .delete()
            .timeout(_kTimeout);
      }
      final prefs = await SharedPreferences.getInstance();
      final done = (prefs.getStringList(_kUploadedKey) ?? <String>[])
        ..remove(name);
      await prefs.setStringList(_kUploadedKey, done);
    } catch (_) {}
  }
}
