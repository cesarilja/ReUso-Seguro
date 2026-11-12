import 'package:flutter/material.dart';

import '../formato.dart';
import '../models/boveda.dart';
import '../models/pedido.dart';
import '../services/administracion_service.dart';
import '../services/pedido_service.dart';
import '../tema.dart';
import '../widgets/avisos.dart';
import '../widgets/navegacion.dart';
import '../widgets/pagina_base.dart';
import '../widgets/pedido_widgets.dart';
import '../widgets/pegatina.dart';

const Color _verde = Color(0xFF1F7A44);
const Color _rojo = Color(0xFFB3261E);
const Color _ambar = Color(0xFF6B4500);

/// HU09: la bóveda escrow, solo para el administrador.
///
/// Al abrirla (y con «Revisar ahora») el servidor hace el cuadre y lo deja
/// registrado. Cuando cambia un pedido en vivo se vuelve a revisar sola.
class BovedaScreen extends StatefulWidget {
  const BovedaScreen({super.key});

  @override
  State<BovedaScreen> createState() => _BovedaScreenState();
}

class _BovedaScreenState extends State<BovedaScreen> {
  late Future<EstadoBoveda> _estado = AdministracionService.instancia.revisarBoveda();
  bool _revisando = false;

  @override
  void initState() {
    super.initState();
    PedidoService.instancia.addListener(_alCambiarPedidos);
  }

  @override
  void dispose() {
    PedidoService.instancia.removeListener(_alCambiarPedidos);
    super.dispose();
  }

  /// Un pedido cambió en vivo: se revisa sin registrar (los descuadres sí
  /// se registran solos en el servidor).
  void _alCambiarPedidos() {
    if (!mounted) return;
    setState(() {
      _estado = AdministracionService.instancia.revisarBoveda(registrar: false);
    });
  }

  Future<void> _revisarAhora() async {
    if (_revisando) return;
    setState(() => _revisando = true);
    final futuro = AdministracionService.instancia.revisarBoveda();
    setState(() => _estado = futuro);
    try {
      final estado = await futuro;
      if (mounted) {
        mostrarAviso(
          context,
          estado.cuadrada
              ? 'Revisión lista: la bóveda está cuadrada.'
              : 'Revisión lista: hay ${estado.descuadres.length} '
                  '${estado.descuadres.length == 1 ? 'pedido' : 'pedidos'} con descuadre.',
        );
      }
    } catch (_) {
      // El error ya se muestra en la pantalla.
    } finally {
      if (mounted) setState(() => _revisando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PaginaBase(
      seccion: Seccion.boveda,
      anchoContenido: 900,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: BotonVolver(texto: 'Volver al inicio'),
          ),
          const SizedBox(height: 20),
          const Text('Bóveda escrow', style: Tipos.titulo),
          const SizedBox(height: 6),
          Text(
            'El dinero que ReUso Seguro guarda mientras el Hub revisa cada '
            'equipo, y si cuadra con los pedidos. Pagos simulados.',
            style: Tipos.cuerpo,
          ),
          const SizedBox(height: 24),
          FutureBuilder<EstadoBoveda>(
            future: _estado,
            builder: (context, resultado) {
              if (resultado.connectionState != ConnectionState.done &&
                  !resultado.hasData) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(
                    child: CircularProgressIndicator(color: ColoresApp.orquidea),
                  ),
                );
              }
              if (resultado.hasError) {
                final error = resultado.error;
                return RecuadroInfo(
                  icono: Icons.error_outline,
                  color: const Color(0xFFFBE9E8),
                  colorIcono: _rojo,
                  texto: error is ErrorDeAdministracion
                      ? error.mensaje
                      : 'No pudimos revisar la bóveda.',
                  hijo: TextButton.icon(
                    onPressed: _revisarAhora,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reintentar'),
                  ),
                );
              }
              return PanelBoveda(
                estado: resultado.data!,
                revisando: _revisando,
                alRevisar: _revisarAhora,
              );
            },
          ),
        ],
      ),
    );
  }
}

/// El contenido de la bóveda. Va aparte para poder probarlo con pruebas de
/// widget: cuadrada, con descuadre y vacía.
class PanelBoveda extends StatelessWidget {
  const PanelBoveda({
    super.key,
    required this.estado,
    required this.alRevisar,
    this.revisando = false,
  });

  final EstadoBoveda estado;
  final VoidCallback alRevisar;
  final bool revisando;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Heurística 1: el estado del cuadre siempre arriba.
        _EstadoCuadre(estado: estado, revisando: revisando, alRevisar: alRevisar),
        const SizedBox(height: 24),
        // Heurística 8: 4 totales grandes y el detalle debajo.
        _Totales(totales: estado.totales),
        if (estado.vacia) ...[
          const SizedBox(height: 20),
          const RecuadroInfo(
            icono: Icons.inbox_outlined,
            texto: 'Todavía no hay dinero en la bóveda. Cuando alguien pague un '
                'pedido, aparecerá aquí.',
          ),
        ],
        const SizedBox(height: 32),
        _Seccion(
          titulo: 'Liberaciones pendientes (${estado.liberacionesPendientes.length})',
          ayuda: 'Equipos aprobados cuyo pago al vendedor no se pudo transferir. '
              'El dinero sigue en custodia.',
          vacio: 'No hay liberaciones pendientes.',
          hijos: [
            for (final l in estado.liberacionesPendientes) _FilaLiberacion(liberacion: l),
          ],
        ),
        const SizedBox(height: 32),
        _Seccion(
          titulo: 'Pedidos por estado (${estado.totalPedidos})',
          vacio: 'Todavía no hay pedidos pagados.',
          hijos: [
            if (estado.porEstado.isNotEmpty)
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final entrada in estado.porEstado.entries)
                    _ConteoEstado(estado: entrada.key, cantidad: entrada.value),
                ],
              ),
          ],
        ),
        const SizedBox(height: 32),
        _Seccion(
          titulo: 'Descuadres registrados',
          ayuda: 'Los últimos 5 descuadres que encontró la revisión, con su fecha.',
          vacio: 'Ningún descuadre registrado.',
          hijos: [
            for (final r in estado.descuadresRegistrados)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.history, size: 18, color: ColoresApp.pizarra),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${formatearFecha(r.revisadoEn)} · ${r.pedidos} '
                        '${r.pedidos == 1 ? 'pedido' : 'pedidos'} · diferencia '
                        '${_conSigno(r.diferenciaTotal)}',
                        style: Tipos.pequeno.copyWith(fontSize: 14, color: ColoresApp.tinta),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

String _conSigno(double monto) =>
    monto < 0 ? '- ${formatearDolares(-monto)}' : '+ ${formatearDolares(monto)}';

/// Cuadrada (verde) o con descuadre (rojo), siempre con ícono, texto y qué
/// hacer, nunca solo color.
class _EstadoCuadre extends StatelessWidget {
  const _EstadoCuadre({
    required this.estado,
    required this.revisando,
    required this.alRevisar,
  });

  final EstadoBoveda estado;
  final bool revisando;
  final VoidCallback alRevisar;

  @override
  Widget build(BuildContext context) {
    final cuadrada = estado.cuadrada;
    final color = cuadrada ? _verde : _rojo;
    final cuantos = estado.descuadres.length;

    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: cuadrada ? const Color(0xFFDFF3E6) : const Color(0xFFFBE9E8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color, width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  cuadrada ? Icons.verified_user : Icons.gpp_bad,
                  color: color,
                  size: 36,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cuadrada ? 'Bóveda cuadrada' : 'Descuadre en la bóveda',
                        style: Tipos.titulo.copyWith(color: color, fontSize: 22),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        cuadrada
                            ? 'Todo el dinero retenido coincide con los pedidos.'
                            : '$cuantos ${cuantos == 1 ? 'pedido no coincide' : 'pedidos no coinciden'} '
                                'con sus movimientos. Diferencia total: '
                                '${_conSigno(estado.diferenciaTotal)}.',
                        style: Tipos.cuerpo.copyWith(color: ColoresApp.tinta, fontSize: 15),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Última revisión: ${formatearFecha(estado.revisadaEn)}',
                        style: Tipos.pequeno,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: revisando ? null : alRevisar,
                  icon: Icon(revisando ? Icons.hourglass_top : Icons.refresh),
                  label: Text(revisando ? 'Revisando…' : 'Revisar ahora'),
                ),
              ],
            ),
            if (!cuadrada) ...[
              const SizedBox(height: 14),
              Text(
                'Qué hacer: no liberes ni reembolses estos pedidos a mano. Revisa '
                'sus movimientos y avisa al equipo técnico. El descuadre quedó '
                'registrado con su fecha.',
                style: Tipos.pequeno.copyWith(
                  fontSize: 14,
                  color: ColoresApp.tinta,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              for (final d in estado.descuadres) _FilaDescuadre(descuadre: d),
            ],
          ],
        ),
      ),
    );
  }
}

class _FilaDescuadre extends StatelessWidget {
  const _FilaDescuadre({required this.descuadre});

  final Descuadre descuadre;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Pedido ${descuadre.codigo} · ${descuadre.titulo}',
                  style: Tipos.subtitulo.copyWith(fontSize: 15),
                ),
              ),
              EtiquetaPedido(estado: descuadre.estado),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 18,
            runSpacing: 4,
            children: [
              Text('Debería haber: ${formatearDolares(descuadre.esperado)}',
                  style: Tipos.pequeno.copyWith(fontSize: 14)),
              Text('Hay: ${formatearDolares(descuadre.real)}',
                  style: Tipos.pequeno.copyWith(fontSize: 14)),
              Text(
                'Diferencia: ${_conSigno(descuadre.diferencia)}',
                style: Tipos.pequeno.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _rojo,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(descuadre.explicacion, style: Tipos.pequeno),
        ],
      ),
    );
  }
}

class _Totales extends StatelessWidget {
  const _Totales({required this.totales});

  final TotalesBoveda totales;

  @override
  Widget build(BuildContext context) {
    final tarjetas = [
      _Total(
        titulo: 'En custodia',
        monto: totales.enCustodia,
        icono: Icons.lock_outline,
        ayuda: 'Retenido ahora',
      ),
      _Total(
        titulo: 'Liberado',
        monto: totales.liberado,
        icono: Icons.payments_outlined,
        ayuda: 'Pagado a vendedores',
      ),
      _Total(
        titulo: 'Reembolsado',
        monto: totales.reembolsado,
        icono: Icons.undo,
        ayuda: 'Devuelto a compradores',
      ),
      _Total(
        titulo: 'Comisiones',
        monto: totales.comisiones,
        icono: Icons.savings_outlined,
        ayuda: '8 % de ventas aprobadas',
      ),
    ];
    return LayoutBuilder(
      builder: (context, medidas) {
        final columnas = medidas.maxWidth >= 720 ? 4 : 2;
        final ancho = (medidas.maxWidth - 12 * (columnas - 1)) / columnas;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [for (final t in tarjetas) SizedBox(width: ancho, child: t)],
        );
      },
    );
  }
}

class _Total extends StatelessWidget {
  const _Total({
    required this.titulo,
    required this.monto,
    required this.icono,
    required this.ayuda,
  });

  final String titulo;
  final double monto;
  final IconData icono;
  final String ayuda;

  @override
  Widget build(BuildContext context) {
    return Pegatina(
      sombra: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icono, size: 20, color: ColoresApp.tinta),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(titulo, style: Tipos.subtitulo.copyWith(fontSize: 15)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(formatearDolares(monto), style: Tipos.precio),
            ),
            Text(ayuda, style: Tipos.pequeno.copyWith(fontSize: 12.5)),
          ],
        ),
      ),
    );
  }
}

class _Seccion extends StatelessWidget {
  const _Seccion({
    required this.titulo,
    required this.vacio,
    required this.hijos,
    this.ayuda,
  });

  final String titulo;
  final String vacio;
  final String? ayuda;
  final List<Widget> hijos;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(titulo, style: Tipos.subtitulo),
        if (ayuda != null) ...[
          const SizedBox(height: 2),
          Text(ayuda!, style: Tipos.pequeno),
        ],
        const SizedBox(height: 12),
        if (hijos.isEmpty) Text(vacio, style: Tipos.cuerpo) else ...hijos,
      ],
    );
  }
}

class _FilaLiberacion extends StatelessWidget {
  const _FilaLiberacion({required this.liberacion});

  final LiberacionPendiente liberacion;

  @override
  Widget build(BuildContext context) {
    final ultimo = liberacion.ultimoIntento;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4D6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _ambar, width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.sync_problem, color: _ambar),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pedido ${liberacion.codigo} · ${liberacion.titulo}',
                  style: Tipos.subtitulo.copyWith(fontSize: 15),
                ),
                Text(
                  'Motivo: ${liberacion.motivo.titulo}',
                  style: Tipos.pequeno.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _ambar,
                  ),
                ),
                Text(
                  'Vendedor: ${liberacion.vendedor} · ${formatearDolares(liberacion.monto)} '
                  'en custodia · ${liberacion.intentos} '
                  '${liberacion.intentos == 1 ? 'intento' : 'intentos'}'
                  '${ultimo == null ? '' : ' (último: ${formatearFecha(ultimo)})'}',
                  style: Tipos.pequeno.copyWith(fontSize: 13.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ConteoEstado extends StatelessWidget {
  const _ConteoEstado({required this.estado, required this.cantidad});

  final EstadoPedido estado;
  final int cantidad;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 12, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: ColoresApp.nube, width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          EtiquetaPedido(estado: estado),
          const SizedBox(width: 8),
          Text(
            '$cantidad',
            style: Tipos.subtitulo.copyWith(fontSize: 16),
          ),
        ],
      ),
    );
  }
}
