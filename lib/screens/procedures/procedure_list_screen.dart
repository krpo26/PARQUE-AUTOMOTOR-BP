import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/procedure.dart';
import '../../providers/auth_provider.dart';
import '../../providers/procedure_provider.dart';
import '../../providers/vehicle_provider.dart';
import '../../widgets/status_badge.dart';
import 'procedure_form_screen.dart';

/// Reporte de trámites en formato de tabla: una columna para el
/// trámite (pedido de service, de compras, de arreglo…), el móvil
/// asociado, la fecha de inicio y de finalización, el estado y el
/// número de expediente (opcional).
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
    final vehiclesById = {
      for (final v in context.watch<VehicleProvider>().vehicles) v.id: v,
    };
    String movilLabel(Procedure p) {
      final id = p.vehicleId;
      if (id == null) return '—';
      final v = vehiclesById[id];
      return v == null ? 'No disponible' : 'N° ${v.internalNumber} · ${v.plate}';
    }

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
                      : LayoutBuilder(
                          builder: (context, constraints) =>
                              SingleChildScrollView(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                    minWidth: constraints.maxWidth),
                                child: DataTable(
                                  showCheckboxColumn: false,
                                  columnSpacing: 20,
                                  columns: const [
                                    DataColumn(label: Text('Trámite')),
                                    DataColumn(label: Text('Móvil')),
                                    DataColumn(label: Text('Inicio')),
                                    DataColumn(label: Text('Finalización')),
                                    DataColumn(label: Text('Estado')),
                                    DataColumn(label: Text('Expediente')),
                                    DataColumn(label: Text('Presentado en')),
                                  ],
                                  rows: items
                                      .map(
                                        (p) => DataRow(
                                          onSelectChanged: (_) =>
                                              _open(p, !isGod),
                                          cells: [
                                            DataCell(Text(p.type)),
                                            DataCell(Text(movilLabel(p))),
                                            DataCell(
                                                Text(_dateFmt.format(p.startDate))),
                                            DataCell(Text(p.endDate == null
                                                ? '—'
                                                : _dateFmt.format(p.endDate!))),
                                            DataCell(StatusBadge(
                                              label: p.status,
                                              color: ProcedureListScreen
                                                  .statusColor(p.status),
                                            )),
                                            DataCell(Text(p.fileNumber.isEmpty
                                                ? '—'
                                                : p.fileNumber)),
                                            DataCell(Text(p.presentedAt.isEmpty
                                                ? '—'
                                                : p.presentedAt)),
                                          ],
                                        ),
                                      )
                                      .toList(),
                                ),
                              ),
                            ),
                          ),
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
