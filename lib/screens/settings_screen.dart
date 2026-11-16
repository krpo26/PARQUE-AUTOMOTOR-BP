import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import 'admin/logo_settings_screen.dart';
import 'notification_settings_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final isGod = context.watch<AuthProvider>().isGod;

    return Scaffold(
      appBar: AppBar(title: const Text('Apariencia')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (isGod) ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.image_outlined),
              title: const Text('Logos de la app'),
              subtitle: const Text('Logo de inicio y logo de la interfaz'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LogoSettingsScreen()),
              ),
            ),
            const Divider(),
            const SizedBox(height: 8),
          ],
          const Text('Temas listos',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: kThemePresets.map((p) {
              final selected = settings.colorIndex == p.colorIndex &&
                  settings.themeMode == p.mode &&
                  settings.amoled == p.amoled;
              final dark = p.mode == ThemeMode.dark;
              return GestureDetector(
                onTap: () => settings.applyPreset(p),
                child: Container(
                  width: 104,
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                  decoration: BoxDecoration(
                    color: p.amoled
                        ? Colors.black
                        : (dark ? const Color(0xFF1E1E22) : Colors.white),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected ? p.color : Colors.grey.shade400,
                      width: selected ? 3 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        height: 22,
                        decoration: BoxDecoration(
                          color: p.color,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        p.name,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: dark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 28),
          const Text('Tema',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(
                  value: ThemeMode.light,
                  label: Text('Claro'),
                  icon: Icon(Icons.light_mode_outlined)),
              ButtonSegment(
                  value: ThemeMode.dark,
                  label: Text('Oscuro'),
                  icon: Icon(Icons.dark_mode_outlined)),
              ButtonSegment(
                  value: ThemeMode.system,
                  label: Text('Automático'),
                  icon: Icon(Icons.brightness_auto_outlined)),
            ],
            selected: {settings.themeMode},
            onSelectionChanged: (selection) =>
                settings.setThemeMode(selection.first),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Fondo negro puro (modo oscuro)'),
            subtitle: const Text('Ahorra batería en pantallas OLED'),
            value: settings.amoled,
            onChanged: settings.setAmoled,
          ),
          const SizedBox(height: 20),
          const Text('Tamaño de letra',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          Row(
            children: [
              const Text('A', style: TextStyle(fontSize: 12)),
              Expanded(
                child: Slider(
                  min: 0.85,
                  max: 1.4,
                  divisions: 11,
                  value: settings.textScale,
                  label: '${(settings.textScale * 100).round()} %',
                  onChanged: settings.setTextScale,
                ),
              ),
              const Text('A', style: TextStyle(fontSize: 22)),
            ],
          ),
          const SizedBox(height: 8),
          const Text('Color institucional',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: List.generate(kColorOptions.length, (i) {
              final option = kColorOptions[i];
              final selected = settings.colorIndex == i;
              return GestureDetector(
                onTap: () => settings.setColorIndex(i),
                child: Column(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: option.color,
                        shape: BoxShape.circle,
                        border: selected
                            ? Border.all(color: Colors.black, width: 3)
                            : null,
                      ),
                      child: selected
                          ? const Icon(Icons.check, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(height: 4),
                    Text(option.name, style: const TextStyle(fontSize: 11)),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 28),
          const Text('Tipografía',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...AppFont.values.map(
            (f) => RadioListTile<AppFont>(
              contentPadding: EdgeInsets.zero,
              title: Text(f.label, style: textThemeForFont(f)?.bodyLarge),
              value: f,
              groupValue: settings.font,
              onChanged: (v) => settings.setFont(v!),
            ),
          ),
          const SizedBox(height: 16),
          const Divider(),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.notifications_active_outlined),
            title: const Text('Notificaciones'),
            subtitle: const Text(
                'Sonido (MP3), barra superior y frecuencia de cada aviso'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const NotificationSettingsScreen()),
            ),
          ),
        ],
      ),
    );
  }
}
