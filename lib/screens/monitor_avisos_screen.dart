import 'package:flutter/material.dart';

import '../formato.dart';
import '../models/aviso.dart';
import '../services/avisos_service.dart';
import '../tema.dart';
import '../widgets/navegacion.dart';
import '../widgets/pagina_base.dart';
import '../widgets/pedido_widgets.dart';
import '../widgets/pegatina.dart';

const Color _verde = Color(0xFF1F7A44);
const Color _ambar = Color(0xFF6B4500);

/// HU10: el administrador comprueba que cada cambio de estado le llegue al
/// comprador y al vendedor. Se actualiza solo, en tiempo real.
class MonitorAvisosScreen extends StatefulWidget {
  const MonitorAvisosScreen({super.key});

  @override
  State<MonitorAvisosScreen> createState() => _MonitorAvisosScreenState();
}

class _MonitorAvisosScreenState extends State<MonitorAvisosScreen> {
  late Future<List<Aviso>> _avisos = AvisosService.instancia.monitor();

  @override
  void initState() {
    super.initState();
    AvisosService.instancia.addListener(_recargar);
  }

  @override
  void dispose() {
    AvisosService.instancia.removeListener(_recargar);
    super.dispose();
  }

  void _recargar() {
    if (!mounted) return;
    setState(() => _avisos = AvisosService.instancia.monitor());
  }

  @override
  Widget build(BuildContext context) {
    return PaginaBase(
      seccion: Seccion.monitor,
      anchoContenido: 900,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: BotonVolver(texto: 'Volver al inicio'),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Expanded(child: Text('Monitor de avisos', style: Tipos.titulo)),
              IconButton(
                tooltip: 'Actualizar',
                onPressed: _recargar,
                icon: const Icon(Icons.refresh, color: ColoresApp.tinta),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Cada vez que cambia el estado de un pedido, el comprador y el '
            'vendedor reciben un aviso. Aquí ves cuándo pasó y si ya lo vio cada '
            'uno. Se actualiza solo.',
            style: Tipos.cuerpo,
          ),
          const SizedBox(height: 24),
          FutureBuilder<List<Aviso>>(
            future: _avisos,
            builder: (context, resultado) {
              if (resultado.connectionState != ConnectionState.done && !resultado.hasData) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator(color: ColoresApp.orquidea)),
                );
              }
              if (resultado.hasError) {
                return RecuadroInfo(
                  icono: Icons.error_outline,
                  texto: '${resultado.error}'.replaceFirst('Exception: ', ''),
                  hijo: TextButton.icon(
                    onPressed: _recargar,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reintentar'),
                  ),
                );
              }
              return ListaMonitor(avisos: resultado.data ?? const []);
            },
          ),
        ],
      ),
    );
  }
}

/// La lista del monitor. Va aparte para probarla con pruebas de widget.
class ListaMonitor extends StatelessWidget {
  const ListaMonitor({super.key, required this.avisos});

  final List<Aviso> avisos;

  @override
  Widget build(BuildContext context) {
    if (avisos.isEmpty) {
      return const RecuadroInfo(
        icono: Icons.notifications_none,
        texto: 'Todavía no hay avisos. Aparecerán cuando un pedido cambie de estado.',
      );
    }
    final sinVer = avisos.where((a) => !a.vistoPorAmbos).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Heurística 1: el resumen siempre arriba.
        Row(
          children: [
            Icon(
              sinVer == 0 ? Icons.mark_email_read_outlined : Icons.mark_email_unread_outlined,
              color: sinVer == 0 ? _verde : _ambar,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                sinVer == 0
                    ? 'Los ${avisos.length} avisos ya los vieron el comprador y el vendedor.'
                    : '$sinVer de ${avisos.length} avisos todavía no los ha visto alguien.',
                style: Tipos.subtitulo.copyWith(fontSize: 15.5),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        for (final aviso in avisos) ...[
          _FilaAviso(aviso: aviso),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _FilaAviso extends StatelessWidget {
  const _FilaAviso({required this.aviso});

  final Aviso aviso;

  @override
  Widget build(BuildContext context) {
    return Pegatina(
      sombra: 2,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${aviso.codigo}${aviso.titulo == null ? '' : ' · ${aviso.titulo}'}',
                    style: Tipos.subtitulo.copyWith(fontSize: 15),
                  ),
                ),
                EtiquetaPedido(estado: aviso.estado),
              ],
            ),
            Text(formatearFecha(aviso.creadoEn), style: Tipos.pequeno.copyWith(fontSize: 12.5)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                _Visto(quien: 'Comprador', vistoEn: aviso.compradorVistoEn),
                _Visto(quien: 'Vendedor', vistoEn: aviso.vendedorVistoEn),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// «Visto» en verde o «Sin ver» en ámbar, siempre con ícono y texto.
class _Visto extends StatelessWidget {
  const _Visto({required this.quien, required this.vistoEn});

  final String quien;
  final DateTime? vistoEn;

  @override
  Widget build(BuildContext context) {
    final visto = vistoEn != null;
    final color = visto ? _verde : _ambar;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: visto ? const Color(0xFFDFF3E6) : const Color(0xFFFFF4D6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(visto ? Icons.done_all : Icons.schedule, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            visto ? '$quien: visto ${formatearFecha(vistoEn!)}' : '$quien: sin ver',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }
}
