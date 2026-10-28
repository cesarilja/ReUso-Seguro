import 'package:flutter/material.dart';

import '../formato.dart';
import '../models/pedido.dart';
import '../services/pedido_service.dart';
import '../services/sesion_service.dart';
import '../tema.dart';
import '../widgets/dictamen_widgets.dart';
import '../widgets/imagen_equipo.dart';
import '../widgets/navegacion.dart';
import '../widgets/pagina_base.dart';
import '../widgets/pedido_widgets.dart';
import '../widgets/pegatina.dart';
import 'pago_screen.dart';

/// Lista de pedidos del comprador, con el estado de cada pago (HU12 y HU01).
///
/// Es la base del rastreo de la HU02: cada pedido pagado ya muestra su
/// línea de tiempo, que avanzará cuando el Hub registre cada fase.
class MisComprasScreen extends StatefulWidget {
  const MisComprasScreen({super.key});

  @override
  State<MisComprasScreen> createState() => _MisComprasScreenState();
}

class _MisComprasScreenState extends State<MisComprasScreen> {
  late Future<List<Pedido>> _pedidos = PedidoService.instancia.misPedidos();

  @override
  void initState() {
    super.initState();
    // Si se paga o se cancela un pedido, la lista se vuelve a cargar sola.
    PedidoService.instancia.addListener(_recargar);
    SesionService.instancia.addListener(_recargar);
  }

  @override
  void dispose() {
    PedidoService.instancia.removeListener(_recargar);
    SesionService.instancia.removeListener(_recargar);
    super.dispose();
  }

  void _recargar() {
    if (!mounted) return;
    setState(() => _pedidos = PedidoService.instancia.misPedidos());
  }

  @override
  Widget build(BuildContext context) {
    final haySesion = SesionService.instancia.haySesion;

    return PaginaBase(
      seccion: Seccion.compras,
      anchoContenido: 760,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BotonVolver(texto: 'Volver al inicio'),
          const SizedBox(height: 20),
          const Text('Mis compras', style: Tipos.titulo),
          const SizedBox(height: 6),
          Text(
            'Aquí ves tus pedidos y en qué estado está cada pago.',
            style: Tipos.cuerpo,
          ),
          const SizedBox(height: 28),
          if (!haySesion)
            const RecuadroInfo(texto: 'Inicia sesión para ver tus compras.')
          else
            FutureBuilder<List<Pedido>>(
              future: _pedidos,
              builder: (context, resultado) {
                if (resultado.connectionState != ConnectionState.done && !resultado.hasData) {
                  return const _Cargando();
                }
                if (resultado.hasError && !resultado.hasData) {
                  final error = resultado.error;
                  return RecuadroInfo(
                    icono: Icons.wifi_off_outlined,
                    texto: error is ErrorDePedido
                        ? error.mensaje
                        : 'No pudimos cargar tus compras.',
                    hijo: TextButton.icon(
                      onPressed: _recargar,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reintentar'),
                    ),
                  );
                }
                final pedidos = resultado.data ?? const <Pedido>[];
                if (pedidos.isEmpty) return const _SinCompras();
                return Column(
                  children: [
                    for (final pedido in pedidos) ...[
                      _TarjetaPedido(pedido: pedido),
                      const SizedBox(height: 18),
                    ],
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

class _TarjetaPedido extends StatelessWidget {
  const _TarjetaPedido({required this.pedido});

  final Pedido pedido;

  @override
  Widget build(BuildContext context) {
    final equipo = pedido.equipo;
    final pagadoEn = pedido.pagadoEn;
    final detalle = pagadoEn == null
        ? 'Creado el ${formatearFecha(pedido.creadoEn)}'
        : 'Pagado el ${formatearFecha(pagadoEn)} · Ref. ${pedido.referencia}';

    return Opacity(
      // Los pedidos cancelados se ven atenuados, pero siguen en la lista.
      opacity: pedido.estaCancelado ? 0.65 : 1,
      child: Pegatina(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 76,
                      height: 76,
                      child: ImagenEquipo(equipo: equipo),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        EtiquetaPedido(estado: pedido.estado),
                        const SizedBox(height: 8),
                        Text(
                          equipo.titulo,
                          style: Tipos.subtitulo,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Pedido ${pedido.codigo} · ${pedido.montoFormateado}',
                          style: Tipos.pequeno.copyWith(color: ColoresApp.tinta),
                        ),
                        Text(detalle, style: Tipos.pequeno),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (pedido.estaPendiente)
                BotonPegatina(
                  texto: 'Pagar ahora',
                  icono: Icons.lock_outline,
                  expandido: true,
                  alTocar: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => PagoScreen(pedido: pedido),
                    ),
                  ),
                )
              else if (pedido.estaCancelado)
                const RecuadroInfo(
                  icono: Icons.block,
                  texto: 'Cancelaste este pedido. No se te cobró nada.',
                )
              else ...[
                // HU08: el resultado de la inspección, con color y texto.
                if (pedido.dictamen != null) ...[
                  TarjetaDictamen(dictamen: pedido.dictamen!),
                  const SizedBox(height: 12),
                ],
                if (pedido.estado != EstadoPedido.rechazado)
                  _Seguimiento(pedido: pedido),
                if (pedido.inspeccion != null && pedido.dictamen != null) ...[
                  const SizedBox(height: 12),
                  _ChecklistDelHub(pedido: pedido),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Línea de tiempo plegable, para no llenar la lista de información.
class _Seguimiento extends StatelessWidget {
  const _Seguimiento({required this.pedido});

  final Pedido pedido;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ColoresApp.nube,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Theme(
        // Quita las líneas que el ExpansionTile pone por defecto.
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          leading: const Icon(Icons.local_shipping_outlined,
              color: ColoresApp.tinta),
          title: Text(
            pedido.estado == EstadoPedido.pagoLiberado ||
                    pedido.estado == EstadoPedido.enCamino
                ? 'Tu equipo fue aprobado. Mira en qué va tu pedido.'
                : 'Tu dinero sigue retenido. Mira en qué va tu pedido.',
            style: Tipos.pequeno.copyWith(
              fontSize: 14.5,
              color: ColoresApp.tinta,
            ),
          ),
          children: [LineaDeTiempo(estado: pedido.estado)],
        ),
      ),
    );
  }
}

/// Transparencia: el comprador puede ver qué revisó el inspector.
class _ChecklistDelHub extends StatelessWidget {
  const _ChecklistDelHub({required this.pedido});

  final Pedido pedido;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: ColoresApp.nube, width: 2),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          leading: const Icon(Icons.fact_check_outlined, color: ColoresApp.tinta),
          title: Text(
            'Ver lo que revisó el inspector',
            style: Tipos.pequeno.copyWith(fontSize: 14.5, color: ColoresApp.tinta),
          ),
          children: [
            ResumenChecklist(
              inspeccion: pedido.inspeccion!,
              categoria: pedido.equipo.categoria,
            ),
          ],
        ),
      ),
    );
  }
}

class _Cargando extends StatelessWidget {
  const _Cargando();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: ColoresApp.orquidea,
            ),
          ),
          const SizedBox(width: 12),
          Text('Cargando tus compras…', style: Tipos.cuerpo),
        ],
      ),
    );
  }
}

class _SinCompras extends StatelessWidget {
  const _SinCompras();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const RecuadroInfo(
          icono: Icons.shopping_bag_outlined,
          texto: 'Todavía no has comprado nada. Cuando compres un equipo, '
              'aquí verás su pedido y el estado del pago.',
        ),
        const SizedBox(height: 20),
        BotonPegatina(
          texto: 'Ver equipos',
          alTocar: () =>
              Navigator.of(context).popUntil((ruta) => ruta.isFirst),
        ),
      ],
    );
  }
}
