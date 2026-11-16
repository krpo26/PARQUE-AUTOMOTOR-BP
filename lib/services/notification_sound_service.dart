import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';

import 'notification_service.dart';

/// Permite elegir un MP3 propio como sonido de las notificaciones
/// (solo Android).
///
/// Cómo funciona: la parte nativa (MainActivity.kt) copia el MP3 a la
/// carpeta de sonidos de notificación del celular (MediaStore) y
/// devuelve una dirección que el sistema operativo sí puede leer.
/// Después [NotificationService.applyCustomSound] crea los canales de
/// notificación con ese sonido.
class NotificationSoundService {
  NotificationSoundService._internal();
  static final NotificationSoundService instance =
      NotificationSoundService._internal();

  static const _channel = MethodChannel('com.fleetapp.app/notification_sound');
  static const int kMaxBytes = 5 * 1024 * 1024; // 5 MB
  static const _kStoredBase = 'P.A.B.P alerta';

  /// Formatos que Android reproduce como sonido de notificación.
  static const Map<String, String> _mimeByExt = {
    'mp3': 'audio/mpeg',
    'm4a': 'audio/mp4',
    'aac': 'audio/aac',
    'wav': 'audio/x-wav',
    'ogg': 'audio/ogg',
    'opus': 'audio/ogg',
    'flac': 'audio/flac',
  };

  /// Abre el selector de archivos, instala el audio elegido y lo deja
  /// como sonido de las alertas. Devuelve el nombre del archivo, o
  /// null si la persona canceló. Lanza un texto legible si algo falla.
  Future<String?> pickAndApply() async {
    if (!Platform.isAndroid) {
      throw 'Elegir un sonido propio solo está disponible en Android.';
    }
    // Se muestran TODOS los archivos (no solo "mp3"): muchos audios
    // del celular son .m4a, .ogg u .opus y quedaban sin poder elegirse.
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      withData: false,
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.single;
    final path = file.path;
    if (path == null) throw 'No se pudo leer el archivo elegido.';

    final dot = file.name.lastIndexOf('.');
    final ext = (file.extension ??
            (dot >= 0 ? file.name.substring(dot + 1) : ''))
        .toLowerCase();
    final mime = _mimeByExt[ext];
    if (mime == null) {
      throw 'Ese formato no sirve como sonido. Elegí un audio MP3, M4A, '
          'OGG, WAV, AAC u OPUS.';
    }
    if (file.size > kMaxBytes) {
      throw 'El archivo pesa más de 5 MB. Elegí un audio más corto.';
    }

    final oldUri = await NotificationService.instance.getCustomSoundUri();
    String? newUri;
    try {
      newUri = await _channel.invokeMethod<String>('install', {
        'path': path,
        'name': '$_kStoredBase.$ext',
        'mime': mime,
      });
    } on PlatformException catch (e) {
      throw 'No se pudo guardar el sonido: ${e.message ?? e.code}';
    }
    if (newUri == null || newUri.isEmpty) {
      throw 'No se pudo guardar el sonido.';
    }

    await NotificationService.instance
        .applyCustomSound(uri: newUri, displayName: file.name);

    // El sonido anterior ya no se usa: se borra del celular.
    if (oldUri != null && oldUri != newUri) {
      try {
        await _channel.invokeMethod('remove', {'uri': oldUri});
      } catch (_) {}
    }
    return file.name;
  }

  /// Vuelve al sonido de notificación predeterminado del sistema.
  Future<void> reset() async {
    final oldUri = await NotificationService.instance.getCustomSoundUri();
    await NotificationService.instance.applyCustomSound(uri: null);
    if (oldUri != null && Platform.isAndroid) {
      try {
        await _channel.invokeMethod('remove', {'uri': oldUri});
      } catch (_) {}
    }
  }
}
