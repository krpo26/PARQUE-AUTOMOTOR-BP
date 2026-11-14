import 'package:flutter/material.dart';

/// Pide confirmación para dar de baja un móvil o un chofer, con un
/// motivo opcional. Devuelve el motivo escrito ('' si lo dejó vacío) o
/// `null` si canceló.
Future<String?> showDeactivateDialog(
  BuildContext context, {
  required String title,
  required String message,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _DeactivateDialog(title: title, message: message),
  );
}

class _DeactivateDialog extends StatefulWidget {
  final String title;
  final String message;
  const _DeactivateDialog({required this.title, required this.message});

  @override
  State<_DeactivateDialog> createState() => _DeactivateDialogState();
}

class _DeactivateDialogState extends State<_DeactivateDialog> {
  final _reasonCtrl = TextEditingController();

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.message),
          const SizedBox(height: 12),
          TextField(
            controller: _reasonCtrl,
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Motivo (opcional)',
              hintText: 'Ej: venta, siniestro, jubilación…',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _reasonCtrl.text.trim()),
          child: const Text('Dar de baja'),
        ),
      ],
    );
  }
}
