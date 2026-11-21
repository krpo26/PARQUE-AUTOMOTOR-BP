import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/legal_terms_service.dart';
import 'auth/login_screen.dart';
import 'complex_home_screen.dart';
import 'legal_terms_screen.dart';

/// Punto de entrada de navegación: decide qué pantalla mostrar según
/// el estado de autenticación (login / términos / dashboard).
///
/// La app siempre arranca en el login normal (usuario y contraseña),
/// incluso en el primer uso cuando todavía no existe el usuario god:
/// para crearlo hay que entrar por el botón "Acceso administrador" de
/// la pantalla de login, que pide el código de activación.
///
/// Una vez logueado, si el usuario todavía no aceptó los Términos de
/// Uso y Confidencialidad vigentes, se le muestra esa pantalla antes
/// de dejarlo entrar al dashboard — no se puede saltear.
///
/// IMPORTANTE (arreglo del "queda dando vueltas"): antes la sesión se
/// resolvía con un FutureBuilder cuyo `future` se creaba DENTRO de
/// build(). Cada setState (por ejemplo al aceptar los términos)
/// disparaba una consulta nueva, volvía a mostrar el spinner y la
/// pantalla se reiniciaba. Ahora la sesión se resuelve UNA sola vez en
/// initState, y la aceptación legal se chequea una sola vez por
/// usuario; al aceptar se pasa directo al inicio, sin re-consultar.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _sessionResolved = false;

  // Usuario para el que ya se resolvió el estado legal, si hace falta
  // mostrar la pantalla de términos y cuál se está chequeando ahora.
  String? _legalResolvedFor;
  String? _legalCheckingFor;
  bool _needsLegal = false;

  @override
  void initState() {
    super.initState();
    _resolveSession();
  }

  Future<void> _resolveSession() async {
    // Con tope de tiempo: si algo tarda de más, no se deja la pantalla
    // girando para siempre.
    try {
      await context
          .read<AuthProvider>()
          .refresh()
          .timeout(const Duration(seconds: 8));
    } catch (_) {}
    if (!mounted) return;
    setState(() => _sessionResolved = true);
  }

  Future<void> _checkLegal(String username) async {
    var accepted = false;
    try {
      accepted = await LegalTermsService.instance
          .hasAccepted(username)
          .timeout(const Duration(seconds: 8));
    } catch (_) {
      // Ante un error se muestra la pantalla legal (lado seguro) en
      // lugar de dejar un spinner infinito.
    }
    if (!mounted) return;
    setState(() {
      _legalResolvedFor = username;
      _legalCheckingFor = null;
      _needsLegal = !accepted;
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (!_sessionResolved) return const _Loading();

    if (!auth.isLoggedIn) {
      _legalResolvedFor = null;
      _legalCheckingFor = null;
      _needsLegal = false;
      return const LoginScreen();
    }

    final username = auth.currentUser?.username ?? '';

    if (_legalResolvedFor != username) {
      if (_legalCheckingFor != username) {
        _legalCheckingFor = username;
        _checkLegal(username);
      }
      return const _Loading();
    }

    if (_needsLegal) {
      return LegalTermsScreen(
        username: username,
        onAccepted: () => setState(() => _needsLegal = false),
      );
    }

    return const ComplexHomeScreen();
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
}
