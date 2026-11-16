import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import 'font_picker_screen.dart';
import 'notification_settings_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  bool _isActive(SettingsProvider s, ThemePreset p) =>
      s.themeMode == p.mode &&
      s.colorIndex == p.colorIndex &&
      s.themeStyle == p.style;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    const title = TextStyle(fontSize: 16, fontWeight: FontWeight.bold);

    return Scaffold(
      appBar: AppBar(title: const Text('Apariencia')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Temas listos', style: title),
          const SizedBox(height: 4),
          const Text(
            'Un toque cambia modo, color y estilo juntos. Después podés '
            'ajustar cada cosa por separado.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in kThemePresets)
                ChoiceChip(
                  avatar: CircleAvatar(
                    radius: 8,
                    backgroundColor: kColorOptions[p.colorIndex].color,
                  ),
                  label: Text(p.name),
                  tooltip: p.description,
                  selected: _isActive(settings, p),
                  onSelected: (_) => settings.applyPreset(p),
                ),
            ],
          ),
          const SizedBox(height: 28),
          const Text('Modo', style: title),
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
          const SizedBox(height: 28),
          const Text('Estilo', style: title),
          const SizedBox(height: 4),
          ...AppThemeStyle.values.map(
            (st) => RadioListTile<AppThemeStyle>(
              contentPadding: EdgeInsets.zero,
              title: Text(st.label),
              value: st,
              groupValue: settings.themeStyle,
              onChanged: (v) {
                if (v != null) settings.setThemeStyle(v);
              },
            ),
          ),
          const SizedBox(height: 20),
          const Text('Color institucional', style: title),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: List.generate(kColorOptions.length, (i) {
              final option = kColorOptions[i];
              final selected = settings.colorIndex == i;
              return GestureDetector(
                onTap: () => settings.setColorIndex(i),
                child: SizedBox(
                  width: 64,
                  child: Column(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: option.color,
                          shape: BoxShape.circle,
                          border: selected
                              ? Border.all(color: Colors.grey, width: 3)
                              : null,
                        ),
                        child: selected
                            ? const Icon(Icons.check, color: Colors.white)
                            : null,
                      ),
                      const SizedBox(height: 4),
                      Text(option.name,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 11)),
                    ],
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 28),
          const Text('Tipografía', style: title),
          const SizedBox(height: 4),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.text_fields),
            title: Text(settings.font.label),
            subtitle: Text(
              'Parque Automotor Benjamín Paz · 6185',
              style: textThemeForFont(settings.font)?.bodyMedium,
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FontPickerScreen()),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${AppFont.values.length} letras para elegir, con buscador.',
            style: const TextStyle(color: Colors.grey, fontSize: 12),
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
