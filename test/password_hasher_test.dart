import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:parque_automotor_benjamin_paz/services/password_hasher.dart';

String _hex(List<int> b) =>
    b.map((e) => e.toRadixString(16).padLeft(2, '0')).join();

void main() {
  test('PBKDF2-HMAC-SHA256 coincide con vectores de referencia', () {
    final pw = utf8.encode('password');
    final salt = utf8.encode('salt');
    expect(_hex(PasswordHasher.pbkdf2Sha256(pw, salt, 1, 32)),
        '120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b');
    expect(_hex(PasswordHasher.pbkdf2Sha256(pw, salt, 2, 32)),
        'ae4d0c95af6b46d32d0adff928f06dd02a303f8ef3c251dfd6e2d85a95474c43');
    expect(_hex(PasswordHasher.pbkdf2Sha256(pw, salt, 4096, 32)),
        'c5e478d59288c841aa530db6845c4c8d962893a001ce4e11a4963873aa98134a');
  });

  test('hash nuevo verifica y rechaza contraseña incorrecta', () async {
    final h = await PasswordHasher.hash('clave-larga-123');
    expect(await PasswordHasher.verify('clave-larga-123', h), isTrue);
    expect(await PasswordHasher.verify('otra', h), isFalse);
    expect(PasswordHasher.needsUpgrade(h), isFalse);
  });

  test('hash viejo SHA-256 sigue verificando y pide actualización', () async {
    const legacy =
        '5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8';
    expect(await PasswordHasher.verify('password', legacy), isTrue);
    expect(await PasswordHasher.verify('x', legacy), isFalse);
    expect(PasswordHasher.needsUpgrade(legacy), isTrue);
  });
}
