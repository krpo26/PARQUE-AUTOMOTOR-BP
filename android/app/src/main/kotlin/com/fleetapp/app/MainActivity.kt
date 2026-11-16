package com.fleetapp.app

import android.content.ContentValues
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream

/// Además de la actividad normal de Flutter, expone un canal para que la
/// app pueda usar un MP3 elegido por la persona como sonido de las
/// notificaciones: el sistema operativo solo puede leer sonidos que
/// estén en la carpeta de media del celular, no en la de la app.
class MainActivity : FlutterActivity() {
    private val channelName = "com.fleetapp.app/notification_sound"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "install" -> {
                        val path = call.argument<String>("path")
                        val name = call.argument<String>("name")
                        val mime = call.argument<String>("mime") ?: "audio/mpeg"
                        if (path == null || name == null) {
                            result.error("ARGS", "Faltan datos del archivo", null)
                        } else {
                            try {
                                result.success(installSound(path, name, mime))
                            } catch (e: Exception) {
                                result.error("INSTALL", e.message, null)
                            }
                        }
                    }
                    "remove" -> {
                        val uri = call.argument<String>("uri")
                        try {
                            if (uri != null) removeSound(uri)
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /// Copia el MP3 a los sonidos de notificación del celular y devuelve
    /// la dirección (URI) con la que el sistema lo puede reproducir.
    private fun installSound(path: String, name: String, mime: String): String {
        val source = File(path)
        if (!source.exists()) throw IllegalStateException("El archivo no existe")

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val values = ContentValues().apply {
                put(MediaStore.Audio.Media.DISPLAY_NAME, name)
                put(MediaStore.Audio.Media.MIME_TYPE, mime)
                put(MediaStore.Audio.Media.RELATIVE_PATH, Environment.DIRECTORY_NOTIFICATIONS)
                put(MediaStore.Audio.Media.IS_NOTIFICATION, 1)
                put(MediaStore.Audio.Media.IS_PENDING, 1)
            }
            val resolver = contentResolver
            val uri = resolver.insert(MediaStore.Audio.Media.EXTERNAL_CONTENT_URI, values)
                ?: throw IllegalStateException("No se pudo crear el sonido")
            val out = resolver.openOutputStream(uri)
                ?: throw IllegalStateException("No se pudo escribir el sonido")
            out.use { o -> FileInputStream(source).use { input -> input.copyTo(o) } }
            val done = ContentValues().apply { put(MediaStore.Audio.Media.IS_PENDING, 0) }
            resolver.update(uri, done, null, null)
            return uri.toString()
        }

        // Android 9 o anterior: carpeta de la app en el almacenamiento
        // externo, legible por el sistema.
        val dir = getExternalFilesDir(Environment.DIRECTORY_NOTIFICATIONS)
            ?: throw IllegalStateException("No hay almacenamiento disponible")
        dir.mkdirs()
        val dest = File(dir, name)
        source.copyTo(dest, overwrite = true)
        return Uri.fromFile(dest).toString()
    }

    private fun removeSound(uriString: String) {
        val uri = Uri.parse(uriString)
        when (uri.scheme) {
            "content" -> contentResolver.delete(uri, null, null)
            "file" -> uri.path?.let { File(it).delete() }
        }
    }
}
