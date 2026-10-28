import 'package:flutter/material.dart';

import '../formato.dart';
import '../models/equipo.dart';
import '../models/pedido.dart';
import '../services/catalogo_service.dart';
import '../services/pedido_service.dart';
import '../services/sesion_service.dart';
import '../tema.dart';
import '../widgets/dictamen_widgets.dart';
import '../widgets/imagen_equipo.dart';
import '../widgets/navegacion.dart';
import '../widgets/pagina_base.dart';
import '../widgets/pedido_widgets.dart';
import '../widgets/pegatina.dart';
import 'detalle_equipo_screen.dart';

/// Las ventas del vendedor y en qué estado está cada pago (HU06).
///
/// Cuando el inspector aprueba el equipo, el pago se libera solo y aquí se
/// ve cuánto recibe el vendedor después de la comisión. Todo es SIMULADO.
class MisVentasScreen extends StatefulWidget {
  const MisVentasScreen({super.key});

  @override
  State<MisVentasScreen> createState() => _MisVentasScreenState();
}

class _MisVentasScreenState extends State<MisVentasScreen> {
  late Future<List<Pedido>> _ventas = PedidoService.instancia.misVentas();
  late Future<List<Equipo>> _publicaciones =
      const CatalogoService().misPublicaciones();

  @override
  void initState() {
    super.initState();
    PedidoService.instancia.addListener(_recargar);
    SesionService.instancia.addListener(_recargar);
    CatalogoService.cambios.addListener(_recargar);
  }

  @override
  void dispose() {
    PedidoService.instancia.removeListener(_recargar);
    SesionService.instancia.removeListener(_recargar);
    CatalogoService.cambios.removeListener(_recargar);
    super.dispose();
  }

  void _recargar() {
    if (!mounted) return;
    setState(() {
      _ventas = PedidoService.instancia.misVentas();
      _publicaciones = const CatalogoService().misPublicaciones();
    });
  }

  @override
  Widget build(BuildContext context) {
    return PaginaBase(
      seccion: Seccion.ventas,
      anchoContenido: 760,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BotonVolver(texto: 'Volver al inicio'),
          const SizedBox(height: 20),
          Row(
            children: [
              const Expanded(child: Text('Mis ventas', style: Tipos.titulo)),
              IconButton(
                tooltip: 'Actualizar',
                onPressed: _recargar,
                icon: const Icon(Icons.refresh, color: ColoresApp.tinta),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Aquí ves los equipos que te compraron y cuándo recibes el dinero.',
            style: Tipos.cuerpo,
          ),
          const SizedBox(height: 28),
          FutureBuilder<List<Pedido>>(
            future: _ventas,
            builder: (context, resultado) {
              if (resultado.connectionState != ConnectionState.done &&
                  !resultado.hasData) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: CircularProgressIndicator(color: ColoresApp.orquidea),
                  ),
                );
              }
              if (resultado.hasError && !resultado.hasData) {
                final error = resultado.error;
                return RecuadroInfo(
                  icono: Icons.wifi_off_outlined,
                  texto: error is ErrorDePedido
                      ? error.mensaje
                      : 'No pudimos cargar tus ventas.',
                  hijo: TextButton.icon(
                    onPressed: _recargar,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reintentar'),
                  ),
                );
              }
              final ventas = resultado.data ?? const <Pedido>[];
              if (ventas.isEmpty) {
                return const RecuadroInfo(
                  icono: Icons.storefront_outlined,
                  texto: 'Todavía no te han comprado ningún equipo. Cuando '
                      'alguien pague uno de tus equipos, aparecerá aquí.',
                );
              }

              final cobrado = ventas
                  .where((v) => v.pagoLiberado)
                  .fold<double>(0, (suma, v) => suma + v.recibeVendedor);
              final porCobrar = ventas
                  .where((v) => !v.pagoLiberado && v.estado != EstadoPedido.rechazado)
                  .fold<double>(0, (suma, v) => suma + v.recibeVendedor);

              return Column(
                children: [
                  Row(
                    children: [
                      _Total(
                        titulo: 'Ya recibiste',
                        monto: cobrado,
                        icono: Icons.account_balance_wallet_outlined,
                        color: const Color(0xFFDFF3E6),
                      ),
                      const SizedBox(width: 12),
                      _Total(
                        titulo: 'En custodia (por recibir)',
                        monto: porCobrar,
                        icono: Icons.lock_clock_outlined,
                        color: ColoresApp.nube,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  for (final venta in ventas) ...[
                    _TarjetaVenta(venta: venta),
                    const SizedBox(height: 18),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 40),
          const Text('Tus equipos publicados', style: Tipos.titulo),
          const SizedBox(height: 6),
          Text(
            'Todo lo que has publicado, esté disponible o ya reservado.',
            style: Tipos.cuerpo,
          ),
          const SizedBox(height: 18),
          FutureBuilder<List<Equipo>>(
            future: _publicaciones,
            builder: (context, resultado) {
              if (resultado.connectionState != ConnectionState.done &&
                  !resultado.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: ColoresApp.orquidea),
                );
              }
              if (resultado.hasError && !resultado.hasData) {
                return const RecuadroInfo(
                  icono: Icons.wifi_off_outlined,
                  texto: 'No pudimos cargar tus publicaciones.',
                );
              }
              final equipos = resultado.data ?? const <Equipo>[];
              if (equipos.isEmpty) {
                return const RecuadroInfo(
                  icono: Icons.add_a_photo_outlined,
                  texto: 'Todavía no has publicado ningún equipo. Usa el '
                      'botón «Publicar un equipo» de arriba.',
                );
              }
              return Column(
                children: [
                  for (final e in equipos) ...[
                    _FilaPublicacion(equipo: e),
                    const SizedBox(height: 10),
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

/// Un equipo publicado por la persona, con su estado.
class _FilaPublicacion extends StatelessWidget {
  const _FilaPublicacion({required this.equipo});

  final Equipo equipo;

  @override
  Widget build(BuildContext context) {
    final disponible = equipo.estaDisponible;
    return Pegatina(
      sombra: 3,
      alTocar: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => DetalleEquipoScreen(equipo: equipo),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 56,
                height: 56,
                child: ImagenEquipo(equipo: equipo),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    equipo.titulo,
                    style: Tipos.subtitulo.copyWith(fontSize: 15.5),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    equipo.precioFormateado,
                    style: Tipos.pequeno.copyWith(color: ColoresApp.tinta),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Color + ícono + texto, nunca solo color.
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: disponible ? const Color(0xFFDFF3E6) : ColoresApp.nube,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    disponible ? Icons.check_circle_outline : Icons.lock_outline,
                    size: 16,
                    color: disponible
                        ? const Color(0xFF1F7A44)
                        : ColoresApp.tinta,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    equipo.estado.nombre,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: disponible
                          ? const Color(0xFF1F7A44)
                          : ColoresApp.tinta,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, color: ColoresApp.pizarra),
          ],
        ),
      ),
    );
  }
}

class _Total extends StatelessWidget {
  const _Total({
    required this.titulo,
    required this.monto,
    required this.icono,
    required this.color,
  });

  final String titulo;
  final double monto;
  final IconData icono;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color,
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
                  Text(formatearDolares(monto), style: Tipos.precio),
                  Text(titulo, style: Tipos.pequeno),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TarjetaVenta extends StatelessWidget {
  const _TarjetaVenta({required this.venta});

  final Pedido venta;

  @override
  Widget build(BuildContext context) {
    final equipo = venta.equipo;
    final liberadoEn = venta.liberadoEn;
    final rechazado = venta.estado == EstadoPedido.rechazado;

    return Pegatina(
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
                      EtiquetaPedido(estado: venta.estado),
                      const SizedBox(height: 8),
                      Text(
                        equipo.titulo,
                        style: Tipos.subtitulo,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Pedido ${venta.codigo}',
                        style: Tipos.pequeno.copyWith(color: ColoresApp.tinta),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Desglose claro de cuánto recibe el vendedor (sin sorpresas).
            Container(height: 2, color: ColoresApp.nube),
            const SizedBox(height: 6),
            FilaDato(titulo: 'Precio de venta', valor: venta.montoFormateado),
            FilaDato(
              titulo: 'Comisión de ReUso Seguro (8 %)',
              valor: '- ${formatearDolares(venta.comisionEstimada)}',
            ),
            FilaDato(
              titulo: rechazado
                  ? 'No recibes pago'
                  : (venta.pagoLiberado ? 'Recibiste' : 'Recibirás'),
              valor: rechazado
                  ? formatearDolares(0)
                  : formatearDolares(venta.recibeVendedor),
              destacado: true,
            ),
            const SizedBox(height: 10),
            if (venta.dictamen != null) ...[
              TarjetaDictamen(dictamen: venta.dictamen!, paraVendedor: true),
              const SizedBox(height: 10),
            ],
            RecuadroInfo(
              icono: venta.pagoLiberado
                  ? Icons.check_circle_outline
                  : (rechazado ? Icons.undo : Icons.local_shipping_outlined),
              color: venta.pagoLiberado
                  ? const Color(0xFFDFF3E6)
                  : ColoresApp.nube,
              texto: _queSigue(venta.estado, liberadoEn),
            ),
          ],
        ),
      ),
    );
  }

  String _queSigue(EstadoPedido estado, DateTime? liberadoEn) {
    switch (estado) {
      case EstadoPedido.pagoEnCustodia:
        return 'El comprador ya pagó y el dinero está en custodia. Lleva el '
            'equipo a nuestro Hub para que lo revisen.';
      case EstadoPedido.recibidoEnHub:
      case EstadoPedido.enDiagnostico:
        return 'Tu equipo está en el Hub y el inspector técnico lo está '
            'revisando.';
      case EstadoPedido.aprobado:
        return 'Tu equipo fue aprobado. El pago se está liberando.';
      case EstadoPedido.pagoLiberado:
      case EstadoPedido.enCamino:
        return liberadoEn == null
            ? 'Te liberamos el pago (simulado).'
            : 'Te liberamos el pago el ${formatearFecha(liberadoEn)} '
                '(simulado, no se mueve dinero real).';
      case EstadoPedido.rechazado:
      case EstadoPedido.reembolsado:
        return 'El equipo no pasó la inspección: el comprador recibe su '
            'reembolso y te devolveremos el equipo.';
      case EstadoPedido.pendienteDePago:
      case EstadoPedido.cancelado:
        return '';
    }
  }
}
