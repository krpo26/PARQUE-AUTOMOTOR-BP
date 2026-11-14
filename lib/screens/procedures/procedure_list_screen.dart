import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/procedure.dart';
import '../../providers/auth_provider.dart';
import '../../providers/procedure_provider.dart';
import '../../widgets/status_badge.dart';
import 'procedure_form_screen.dart';

/// Reporte de trámites en formato de tabla: una columna para el
/// trámite (pedido de service, de compras, de arreglo…), otra para la
/// fecha de inicio, el estado y el número de expediente (opcional).
/// Tocar una fila abre el detalle; solo el god puede crear, editar o
/// eliminar trámites.
class ProcedureListScreen extends StatefulWidget {
  const ProcedureListScreen({super.key});

  /// Color del estado (se reusa en el formulario y en el PDF).
  static Color statusColor(String status) {
    switch (status) {
      case Procedure.statusDone:
        return Colors.green;
      case Procedure.statusRejected:
        return Colors.red;
      case Procedure.statusInProgress:
        return Colors.amber.shade800;
      default:
        return Colors.blue;
    }
  }

  @override
  State<ProcedureListScreen> createState() => _ProcedureListScreenState();
}

class _ProcedureListScreenState extends State<ProcedureListScreen> {
  static final _dateFmt = DateFormat('dd/MM/yyyy');
  String? _statusFilter; // null = todos

  void _open(Procedure? p, bool readOnly) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProcedureFormScreen(procedure: p, readOnly: readOnly),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProcedureProvider>();
    final isGod = context.watch<AuthProvider>().isGod;
    final all = provider.procedures;
    final items = _statusFilter == null
        ? all
        : all.where((p) => p.status == _statusFilter).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Trámites')),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                SizedBox(
                  height: 56,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text('Todos (${all.length})'),
                          selected: _statusFilter == null,
                          onSelected: (_) =>
                              setState(() => _statusFilter = null),
                        ),
                      ),
                      for (final s in Procedure.statuses)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(s),
                            selected: _statusFilter == s,
                            onSelected: (_) =>
                                setState(() => _statusFilter = s),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: items.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              all.isEmpty
                                  ? 'No hay trámites cargados.'
                                  : 'No hay trámites con ese estado.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 88),
                          itemCount: items.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, i) {
                            final p = items[i];
                            final lines = <String>[
                              if (p.vehicleNumber.isNotEmpty)
                                'Móvil: ${p.vehicleNumber}',
                              'Inicio: ${_dateFmt.format(p.startDate)}'
                                  '${p.endDate != null ? '  ·  Fin: ${_dateFmt.format(p.endDate!)}' : ''}',
                              if (p.fileNumber.isNotEmpty)
                                'Expediente: ${p.fileNumber}',
                              if (p.presentedAt.isNotEmpty)
                                'Presentado en: ${p.presentedAt}',
                            ];
                            return Card(
                              margin: EdgeInsets.zero,
                              child: ListTile(
                                onTap: () => _open(p, !isGod),
                                title: Text(p.type,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600)),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(lines.join('\n')),
                                ),
                                isThreeLine: lines.length > 1,
                                trailing: StatusBadge(
                                  label: p.status,
                                  color: ProcedureListScreen.statusColor(
                                      p.status),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: isGod
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.add),
              label: const Text('Nuevo trámite'),
              onPressed: () => _open(null, false),
            )
          : null,
    );
  }
}
