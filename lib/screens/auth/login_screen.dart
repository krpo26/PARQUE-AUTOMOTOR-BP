import '../../widgets/app_logo.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../main.dart';
import '../../providers/auth_provider.dart';
import 'admin_access_screen.dart';

class LoginScreen extends StatefulWidget {
  final bool justCreated;
  const LoginScreen({super.key, this.justCreated = false});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _obscure = true;

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    // La navegación posterior al login la decide AuthGate según el
    // estado (login → términos legales → inicio). Acá NO se empuja
    // ninguna pantalla: antes se hacía con pushAndRemoveUntil y el
    // "onAccepted" usaba un context de una pantalla ya destruida, por
    // eso al aceptar los términos nunca avanzaba.
    final nav = Navigator.of(context);
    final ok = await context
        .read<AuthProvider>()
        .login(_userCtrl.text.trim(), _passCtrl.text);

    if (ok) {
      nav.popUntil((route) => route.isFirst);
      return;
    }
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = 'Usuario o contraseña incorrectos';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(
                      child: AppLogo(height: 100, kind: AppLogoKind.login)),
                  const SizedBox(height: 12),
                  const Text(
                    kAppTitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  if (widget.justCreated) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Usuario creado con éxito. Iniciá sesión para continuar.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.green),
                    ),
                  ],
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _userCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Usuario',
                        prefixIcon: Icon(Icons.person_outline),
                        border: OutlineInputBorder()),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Campo obligatorio'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passCtrl,
                    obscureText: _obscure,
                    decoration: InputDecoration(
                      labelText: 'Contraseña',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(_obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Campo obligatorio' : null,
                    onFieldSubmitted: (_) => _login(),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _loading ? null : _login,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: _loading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Ingresar'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const AdminAccessScreen()),
                    ),
                    icon: const Icon(Icons.admin_panel_settings_outlined,
                        size: 18),
                    label: const Text('Acceso administrador'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
