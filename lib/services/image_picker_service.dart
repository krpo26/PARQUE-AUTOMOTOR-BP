import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Elige una foto (cámara o galería) y la copia a una carpeta propia
/// de la app (`fotos/`), devolviendo la ruta local guardada. Se usa
/// tanto para la foto de perfil de un chofer como para las fotos de
/// documentos de un vehículo (cédula verde, título, VTV, seguro).
class ImagePickerService {
  static final _picker = ImagePicker();

  static Future<String?> pickAndSave({
    required bool fromCamera,
    double maxWidth = 1280,
    int imageQuality = 60,
  }) async {
    final XFile? picked = await _picker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: maxWidth,
      imageQuality: imageQuality,
    );
    if (picked == null) return null;

    final appDir = await getApplicationDocumentsDirectory();
    final photosDir = Directory(p.join(appDir.path, 'fotos'));
    if (!await photosDir.exists()) {
      await photosDir.create(recursive: true);
    }

    final ext = p.extension(picked.path).isNotEmpty
        ? p.extension(picked.path)
        : '.jpg';
    final newPath = p.join(photosDir.path, '${const Uuid().v4()}$ext');
    await File(picked.path).copy(newPath);
    // La copia temporal que deja el selector/cámara se borra: la
    // única copia de la foto queda en la carpeta privada de la app.
    try {
      await File(picked.path).delete();
    } catch (_) {}
    return newPath;
  }

  /// Muestra un menú simple para elegir entre cámara y galería.
  /// Se usa desde los formularios con un BuildContext.
}
