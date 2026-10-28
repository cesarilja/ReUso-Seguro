import 'package:flutter/material.dart';

import '../formato.dart';
import '../models/pedido.dart';
import '../services/inspeccion_service.dart';
import '../tema.dart';
import '../widgets/avisos.dart';
import '../widgets/imagen_equipo.dart';
import '../widgets/pagina_base.dart';
import '../widgets/pedido_widgets.dart';
import '../widgets/pegatina.dart';
import 'inspeccion_screen.dart';

/// Panel del inspector técnico del Hub (HU07).
///
/// Muestra los pedidos pagados en tres grupos, en el orden en que se
/// trabajan: por recibir, por inspeccionar e inspeccionados.
class PanelHubScreen extends StatefulWidget {
  const PanelHubScreen({super.key});

  @override
  State<PanelHubScreen> createState() => _PanelHubScreenState();
}

class _PanelHubScreenState extends State<PanelHubScreen> {
  late Future<List<PedidoHub>> _pedidos =
      InspeccionService.instancia.pedidosDelHub();
  final Set<String> _recibiendo = {};

  @override
  void initState() {
    super.initState();
    InspeccionService.instancia.addListener(_recargar);
  }

  @override
  void dispose() {
    InspeccionService.instancia.removeListener(_recargar);
    super.dispose();
  }

  void _recargar() {
    if (!mounted) return;
    setState(() => _pedidos = InspeccionService.instancia.pedidosDelHub());
  }

  Future<void> _recibir(Pedido pedido) async {
    setState(() => _recibiendo.add(pedido.id));
    try {
      await InspeccionService.instancia.recibirEnHub(pedido);
      if (mounted) {
        mostrarAviso(context, 'Registramos la llegada del pedido ${pedido.codigo}.');
      }
    } on ErrorDeInspeccion catch (error) {
      if (mounted) mostrarAviso(context, error.mensaje);
    } finally {
      if (mounted) setState(() => _recibiendo.remove(pedido.id));
    }
  }

  void _inspeccionar(PedidoHub item) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => InspeccionScreen(
          pedido: item.pedido,
          inspeccion: item.inspeccion,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!InspeccionService.instancia.soyInspector) {
      return const PaginaBase(
        child: RecuadroInfo(
          icono: Icons.lock_outline,
          texto: 'Esta sección es solo para inspectores técnicos del Hub.',
        ),
      );
    }

    return PaginaBase(
      anchoContenido: 860,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BotonVolver(texto: 'Volver'),
          const SizedBox(height: 20),
          Row(
            children: [
              const Expanded(
                child: Text('Panel del Hub', style: Tipos.titulo),
              ),
              IconButton(
                tooltip: 'Actualizar',
                onPressed: _recargar,
                icon: const Icon(Icons.refresh, color: ColoresApp.tinta),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Registra la llegada de cada equipo y revísalo con el checklist. '
            'Los más antiguos aparecen primero.',
            style: Tipos.cuerpo,
          ),
          const SizedBox(height: 24),
          FutureBuilder<List<PedidoHub>>(
            future: _pedidos,
            builder: (context, resultado) {
              if (resultado.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: CircularProgressIndicator(color: ColoresApp.orquidea),
                  ),
                );
              }
              if (resultado.hasError) {
                final error = resultado.error;
                return RecuadroInfo(
                  icono: Icons.wifi_off_outlined,
                  texto: error is ErrorDeInspeccion
                      ? error.mensaje
                      : 'No pudimos cargar los pedidos.',
                  hijo: TextButton.icon(
                    onPressed: _recargar,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reintentar'),
                  ),
                );
              }

              final todos = resultado.data ?? const <PedidoHub>[];
              final porRecibir = todos
                  .where((i) => i.pedido.estado == EstadoPedido.pagoEnCustodia)
                  .toList();
              final porInspeccionar = todos
                  .where((i) =>
                      i.pedido.estado == EstadoPedido.recibidoEnHub ||
                      (i.pedido.estado == EstadoPedido.enDiagnostico &&
                          !(i.inspeccion?.completa ?? false)))
                  .toList();
              final listos = todos
                  .where((i) =>
                      i.pedido.estado == EstadoPedido.enDiagnostico &&
                      (i.inspeccion?.completa ?? false))
                  .toList();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Resumen(
                    porRecibir: porRecibir.length,
                    porInspeccionar: porInspeccionar.length,
                    listos: listos.length,
                  ),
                  const SizedBox(height: 28),
                  _Grupo(
                    titulo: '1. Por recibir',
                    vacio: 'No hay equipos en camino al Hub.',
                    items: porRecibir,
                    accion: (item) => BotonPegatina(
                      texto: _recibiendo.contains(item.pedido.id)
                          ? 'Registrando…'
                          : 'Registrar llegada',
                      icono: Icons.move_to_inbox_outlined,
                      principal: false,
                      alTocar: _recibiendo.contains(item.pedido.id)
                          ? () {}
                          : () => _recibir(item.pedido),
                    ),
                  ),
                  const SizedBox(height: 28),
                  _Grupo(
                    titulo: '2. Por inspeccionar',
                    vacio: 'No hay equipos esperando revisión.',
                    items: porInspeccionar,
                    accion: (item) => BotonPegatina(
                      texto: 'Abrir checklist',
                      icono: Icons.fact_check_outlined,
                      alTocar: () => _inspeccionar(item),
                    ),
                  ),
                  const SizedBox(height: 28),
                  _Grupo(
                    titulo: '3. Inspeccionados',
                    vacio: 'Todavía no hay checklists guardados.',
                    items: listos,
                    accion: (item) => BotonPegatina(
                      texto: 'Ver o corregir',
                      icono: Icons.edit_note,
                      principal: false,
                      alTocar: () => _inspeccionar(item),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Tres contadores arriba, para ver de un vistazo cuánto trabajo hay.
class _Resumen extends StatelessWidget {
  const _Resumen({
    required this.porRecibir,
    required this.porInspeccionar,
    required this.listos,
  });

  final int porRecibir;
  final int porInspeccionar;
  final int listos;

  @override
  Widget build(BuildContext context) {
    Widget contador(String texto, int numero, IconData icono) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: ColoresApp.nube,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(icono, color: ColoresApp.tinta),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$numero', style: Tipos.precio),
                      Text(texto, style: Tipos.pequeno),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );

    return Row(
      children: [
        contador('Por recibir', porRecibir, Icons.local_shipping_outlined),
        const SizedBox(width: 12),
        contador('Por inspeccionar', porInspeccionar, Icons.fact_check_outlined),
        const SizedBox(width: 12),
        contador('Inspeccionados', listos, Icons.task_alt),
      ],
    );
  }
}

class _Grupo extends StatelessWidget {
  const _Grupo({
    required this.titulo,
    required this.vacio,
    required this.items,
    required this.accion,
  });

  final String titulo;
  final String vacio;
  final List<PedidoHub> items;
  final Widget Function(PedidoHub item) accion;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$titulo (${items.length})', style: Tipos.subtitulo),
        const SizedBox(height: 12),
        if (items.isEmpty)
          Text(vacio, style: Tipos.cuerpo)
        else
          for (final item in items) ...[
            _TarjetaHub(item: item, accion: accion(item)),
            const SizedBox(height: 14),
          ],
      ],
    );
  }
}

class _TarjetaHub extends StatelessWidget {
  const _TarjetaHub({required this.item, required this.accion});

  final PedidoHub item;
  final Widget accion;

  @override
  Widget build(BuildContext context) {
    final pedido = item.pedido;
    final pagadoEn = pedido.pagadoEn;
    final inspeccion = item.inspeccion;
    final ancha = MediaQuery.sizeOf(context).width >= 700;

    final datos = Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EtiquetaPedido(estado: pedido.estado),
          const SizedBox(height: 6),
          Text(
            pedido.equipo.titulo,
            style: Tipos.subtitulo,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            'Pedido ${pedido.codigo} · Vende ${pedido.equipo.vendedor}',
            style: Tipos.pequeno.copyWith(color: ColoresApp.tinta),
          ),
          if (pagadoEn != null)
            Text('Pagado el ${formatearFecha(pagadoEn)}', style: Tipos.pequeno),
          if (inspeccion != null && inspeccion.completa)
            Text(
              inspeccion.fallas == 0
                  ? 'Checklist: sin fallas'
                  : 'Checklist: ${inspeccion.fallas} '
                      '${inspeccion.fallas == 1 ? 'falla' : 'fallas'}',
              style: Tipos.pequeno.copyWith(
                fontWeight: FontWeight.w700,
                color: inspeccion.fallas == 0
                    ? const Color(0xFF1F7A44)
                    : const Color(0xFFB3261E),
              ),
            ),
        ],
      ),
    );

    final foto = ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 72,
        height: 72,
        child: ImagenEquipo(equipo: pedido.equipo),
      ),
    );

    return Pegatina(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ancha
            ? Row(
                children: [
                  foto,
                  const SizedBox(width: 14),
                  datos,
                  const SizedBox(width: 14),
                  accion,
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [foto, const SizedBox(width: 14), datos]),
                  const SizedBox(height: 12),
                  accion,
                ],
              ),
      ),
    );
  }
}
