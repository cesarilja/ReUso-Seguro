import 'package:flutter/material.dart';

import '../formato.dart';
import '../models/pedido.dart';
import '../models/rastreo.dart';
import '../services/pedido_service.dart';
import '../services/sesion_service.dart';
import '../tema.dart';
import '../widgets/avisos.dart';
import '../widgets/dictamen_widgets.dart';
import '../widgets/imagen_equipo.dart';
import '../widgets/navegacion.dart';
import '../widgets/pagina_base.dart';
import '../widgets/pedido_widgets.dart';
import '../widgets/pegatina.dart';
import 'certificado_screen.dart';
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
  late Future<List<Pedido>> _pedidos = _cargar();

  /// Estado de cada pedido en la última carga, para avisar cuando cambia
  /// de fase en vivo (HU02, escenario 2).
  final Map<String, EstadoPedido> _estadosAnteriores = {};

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
    setState(() => _pedidos = _cargar());
  }

  /// Carga los pedidos y, si alguno avanzó de fase desde la última vez,
  /// lo avisa: «Tu equipo pasó a: En diagnóstico».
  Future<List<Pedido>> _cargar() async {
    final pedidos = await PedidoService.instancia.misPedidos();
    final primeraCarga = _estadosAnteriores.isEmpty;
    final avisos = <String>[];
    for (final pedido in pedidos) {
      final antes = _estadosAnteriores[pedido.id];
      if (!primeraCarga && antes != null && antes != pedido.estado) {
        final aviso = Rastreo.avisoDeCambio(antes, pedido);
        if (aviso != null) avisos.add(aviso);
      }
      _estadosAnteriores[pedido.id] = pedido.estado;
    }
    if (avisos.isNotEmpty && mounted) mostrarAviso(context, avisos.join('\n'));
    return pedidos;
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
              if (pedido.estaPendiente) ...[
                // ReUso Pay: cada pedido tiene un tiempo límite para pagarse.
                if (pedido.vencido())
                  const RecuadroInfo(
                    icono: Icons.timer_off_outlined,
                    texto: 'Se acabó el tiempo para pagar este pedido. No se '
                        'te cobró nada.',
                  )
                else
                  RecuadroInfo(
                    icono: Icons.timer_outlined,
                    texto: 'Tienes hasta el ${formatearFecha(pedido.expiraEn)} '
                        'para pagar. Después el pedido vence.',
                  ),
                const SizedBox(height: 12),
                BotonPegatina(
                  texto: pedido.vencido() ? 'Volver a intentarlo' : 'Pagar ahora',
                  icono: pedido.vencido() ? Icons.refresh : Icons.lock_outline,
                  expandido: true,
                  alTocar: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => PagoScreen(pedido: pedido),
                    ),
                  ),
                ),
              ]
              else if (pedido.estaCancelado)
                const RecuadroInfo(
                  icono: Icons.block,
                  texto: 'Este pedido se canceló. No se te cobró nada.',
                )
              else ...[
                // HU08: el resultado de la inspección, con color y texto.
                if (pedido.dictamen != null) ...[
                  TarjetaDictamen(dictamen: pedido.dictamen!),
                  const SizedBox(height: 12),
                ],
                // HU02: dónde está el dinero, siempre a la vista.
                DondeEstaTuDinero(pedido: pedido),
                const SizedBox(height: 12),
                // HU13: si no pasó, el comprobante del reembolso.
                if (pedido.noPasoInspeccion) ...[
                  ComprobanteReembolso(pedido: pedido),
                  const SizedBox(height: 12),
                ],
                _Seguimiento(pedido: pedido),
                const SizedBox(height: 12),
                // HU03: el certificado técnico del inspector.
                BotonPegatina(
                  texto: 'Ver certificado técnico',
                  icono: pedido.dictamen == null
                      ? Icons.hourglass_top
                      : Icons.workspace_premium_outlined,
                  principal: false,
                  expandido: true,
                  alTocar: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => CertificadoScreen(pedido: pedido),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// HU02: la línea de tiempo plegable, con la fase actual en el título.
class _Seguimiento extends StatelessWidget {
  const _Seguimiento({required this.pedido});

  final Pedido pedido;

  String _titulo() {
    final rastreo = Rastreo.de(pedido);
    final fase = rastreo.faseActual;
    if (fase == null) return 'Mira en qué va tu pedido.';
    return 'Fase ${rastreo.indiceActual + 1} de ${Rastreo.totalFases}: '
        '${fase.titulo}';
  }

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
          // Se abre solo mientras el pedido sigue en camino o en el Hub.
          initiallyExpanded: Rastreo.de(pedido).indiceActual < 3,
          title: Text(
            _titulo(),
            style: Tipos.pequeno.copyWith(
              fontSize: 14.5,
              color: ColoresApp.tinta,
            ),
          ),
          children: [LineaDeTiempo(pedido: pedido)],
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
          texto: 'Aún no tienes compras. Cuando compres un equipo, aquí '
              'verás en qué fase va y dónde está tu dinero.',
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
