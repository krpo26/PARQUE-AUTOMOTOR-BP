import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Hash de contraseñas con PBKDF2-HMAC-SHA256 + sal aleatoria.
///
/// Formato guardado:  pbkdf2-sha256$<iteraciones>$<sal base64>$<hash base64>
///
/// Compatibilidad: los hashes viejos (SHA-256 sin sal, 64 caracteres
/// hexadecimales) se siguen aceptando al verificar, y [needsUpgrade]
/// avisa que hay que regenerarlos con el formato nuevo la próxima vez
/// que la persona inicia sesión con su contraseña correcta.
///
/// Es Dart puro (sin Flutter) para poder usarlo también desde
/// tool/gen_admin_hash.dart. El cálculo corre en un isolate aparte
/// para no trabar la pantalla.
class PasswordHasher {
  PasswordHasher._();

  static const int kIterations = 100000;
  static const int _kMaxIterations = 1000000; // tope anti-DoS (hash plantado)
  static const int _kSaltBytes = 16;
  static const int _kKeyBytes = 32;
  static const String _kPrefix = 'pbkdf2-sha256';

  static bool isLegacy(String stored) => !stored.startsWith('$_kPrefix\$');

  static bool needsUpgrade(String stored) {
    if (isLegacy(stored)) return true;
    final parts = stored.split('\$');
    final it = parts.length == 4 ? int.tryParse(parts[1]) : null;
    return it == null || it < kIterations;
  }

  static Future<String> hash(String password) async {
    final salt = _randomBytes(_kSaltBytes);
    final pw = utf8.encode(password);
    final key = await Isolate.run(
        () => pbkdf2Sha256(pw, salt, kIterations, _kKeyBytes));
    return '$_kPrefix\$$kIterations\$${base64.encode(salt)}\$${base64.encode(key)}';
  }

  static Future<bool> verify(String password, String stored) async {
    if (isLegacy(stored)) {
      final legacy = sha256.convert(utf8.encode(password)).toString();
      return _constantTimeEquals(utf8.encode(legacy), utf8.encode(stored));
    }
    final parts = stored.split('\$');
    if (parts.length != 4) return false;
    final iterations = int.tryParse(parts[1]);
    if (iterations == null || iterations < 1 || iterations > _kMaxIterations) {
      return false;
    }
    final salt = _tryDecode(parts[2]);
    final expected = _tryDecode(parts[3]);
    if (salt == null || expected == null) return false;
    if (expected.isEmpty) return false;
    final pw = utf8.encode(password);
    final key = await Isolate.run(
        () => pbkdf2Sha256(pw, salt, iterations, expected.length));
    return _constantTimeEquals(key, expected);
  }

  /// PBKDF2 (RFC 8018) con HMAC-SHA256. Público para los tests.
  static Uint8List pbkdf2Sha256(
      List<int> password, List<int> salt, int iterations, int length) {
    final hmac = Hmac(sha256, password);
    const hLen = 32;
    final blocks = (length + hLen - 1) ~/ hLen;
    final out = BytesBuilder();
    for (var i = 1; i <= blocks; i++) {
      final input = Uint8List(salt.length + 4)
        ..setAll(0, salt)
        ..[salt.length] = (i >> 24) & 0xff
        ..[salt.length + 1] = (i >> 16) & 0xff
        ..[salt.length + 2] = (i >> 8) & 0xff
        ..[salt.length + 3] = i & 0xff;
      var u = hmac.convert(input).bytes;
      final t = List<int>.from(u);
      for (var c = 1; c < iterations; c++) {
        u = hmac.convert(u).bytes;
        for (var j = 0; j < hLen; j++) {
          t[j] ^= u[j];
        }
      }
      out.add(t);
    }
    return Uint8List.fromList(out.toBytes().sublist(0, length));
  }

  static Uint8List? _tryDecode(String b64) {
    try {
      return base64.decode(b64);
    } on FormatException {
      return null;
    }
  }

  static Uint8List _randomBytes(int n) {
    final r = Random.secure();
    return Uint8List.fromList(List<int>.generate(n, (_) => r.nextInt(256)));
  }

  static bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}
