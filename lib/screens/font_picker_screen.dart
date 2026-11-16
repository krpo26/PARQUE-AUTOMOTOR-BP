import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';

/// Lista de letras con buscador. Cada letra se muestra con su propio
/// estilo, pero solo se carga cuando aparece en pantalla (las de Google
/// se bajan de internet la primera vez que se ven).
class FontPickerScreen extends StatefulWidget {
  const FontPickerScreen({super.key});

  @override
  State<FontPickerScreen> createState() => _FontPickerScreenState();
}

class _FontPickerScreenState extends State<FontPickerScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final q = _query.trim().toLowerCase();
    final fonts = AppFont.values
        .where((f) => q.isEmpty || f.label.toLowerCase().contains(q))
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Tipografía')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Buscar letra',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Text(
              'Las letras con nombre de Google se descargan la primera vez '
              'que se usan (hace falta internet); después quedan guardadas.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
          Expanded(
            child: fonts.isEmpty
                ? const Center(child: Text('No hay letras con ese nombre.'))
                : ListView.builder(
                    itemCount: fonts.length,
                    itemBuilder: (context, i) {
                      final f = fonts[i];
                      return RadioListTile<AppFont>(
                        value: f,
                        groupValue: settings.font,
                        onChanged: (v) {
                          if (v != null) settings.setFont(v);
                        },
                        title: Text(f.label,
                            style: textThemeForFont(f)?.titleMedium),
                        subtitle: Text(
                          'Parque Automotor Benjamín Paz 6185 · 0123456789',
                          style: textThemeForFont(f)?.bodySmall,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
