// Genera la constante para el código de activación de admin.
//
// Uso (en tu computadora, desde la carpeta fleet_app):
//   dart run tool/gen_admin_hash.dart
// Escribí el código cuando lo pida (no se muestra en pantalla) y
// copiá la línea resultante en lib/screens/auth/admin_access_screen.dart
// (constante _kActivationCodeHash). Elegí 12 o más caracteres.
import 'dart:io';

import '../lib/services/password_hasher.dart';

Future<void> main() async {
  stdout.write('Código de activación (12+ caracteres, no se muestra): ');
  stdin.echoMode = false;
  final a = stdin.readLineSync() ?? '';
  stdin.echoMode = true;
  stdout.writeln();
  stdout.write('Repetilo: ');
  stdin.echoMode = false;
  final b = stdin.readLineSync() ?? '';
  stdin.echoMode = true;
  stdout.writeln();
  if (a != b) {
    stderr.writeln('No coinciden.');
    exit(1);
  }
  if (a.trim().length < 12) {
    stderr.writeln('Muy corto: usá 12 o más caracteres.');
    exit(1);
  }
  final h = await PasswordHasher.hash(a.trim());
  stdout.writeln('\nPegá esto en admin_access_screen.dart:\n');
  // Cadena cruda (r'...'): el hash contiene el símbolo $.
  stdout.writeln("  static const _kActivationCodeHash =\n      r'$h';");
}
