import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Comparte las fotos de los trámites entre TODOS los dispositivos
/// (admin y usuarios comunes) usando Cloud Firestore, sin Firebase
/// Storage y sin Google Drive.
///
/// Cada foto (ya comprimida por [ImagePickerService]) se guarda como un
/// documento de la colección `procedure_photos`, con el contenido en
/// base64. Queda bajo las MISMAS reglas de seguridad que el resto de
/// los datos (ver firestore.rules). Límite: ~650 KB por foto, porque un
/// documento de Firestore no puede pasar de 1 MB.
///
/// A la nube de cada trámite solo viaja el NOMBRE del archivo de la
/// foto; cada celular arma su propia ruta local y descarga la foto si
/// todavía no la tiene. Todo es "mejor esfuerzo": sin internet falla en
/// silencio y se reintenta en la próxima sincronización.
class PhotoSyncService {
  PhotoSyncService._internal();
  static final PhotoSyncService instance = PhotoSyncService._internal();

  static const String _kCollection = 'procedure_photos';
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
  Future<bool> uploadIfMissing(String localPath, String procedureId) async {
    try {
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
        'procedure_id': procedureId,
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
    try {
      final doc = await FirebaseFirestore.instance
          .collection(_kCollection)
          .doc(p.basename(path))
          .get()
          .timeout(_kTimeout);
      final b64 = doc.data()?['data_b64'];
      if (b64 is String && b64.isNotEmpty) {
        await Directory(p.dirname(path)).create(recursive: true);
        await file.writeAsBytes(base64Decode(b64), flush: true);
      }
    } catch (_) {
      try {
        if (file.existsSync()) file.deleteSync();
      } catch (_) {}
    }
    return path;
  }

  /// Borra la foto de la nube (al quitarla de un trámite o al borrar
  /// el trámite).
  Future<void> deleteRemote(String nameOrPath) async {
    final name = p.basename(nameOrPath);
    try {
      await FirebaseFirestore.instance
          .collection(_kCollection)
          .doc(name)
          .delete()
          .timeout(_kTimeout);
      final prefs = await SharedPreferences.getInstance();
      final done = (prefs.getStringList(_kUploadedKey) ?? <String>[])
        ..remove(name);
      await prefs.setStringList(_kUploadedKey, done);
    } catch (_) {}
  }
}
