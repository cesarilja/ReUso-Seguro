import 'package:flutter/material.dart';

import '../formato.dart';
import '../models/pedido.dart';
import '../models/reclamo.dart';
import '../services/inspeccion_service.dart';
import '../tema.dart';
import 'pedido_widgets.dart';

const Color _ambar = Color(0xFF6B4500);

/// HU05, escenario 2: las fotos de cómo llegó el equipo al Hub, con su
/// fecha. Es el respaldo imparcial del vendedor y no se pueden cambiar.
class FotosRecepcion extends StatelessWidget {
  const FotosRecepcion({super.key, required this.recepcion, this.paraVendedor = false});

  final Recepcion recepcion;
  final bool paraVendedor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ColoresApp.nube,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.photo_camera_outlined, color: ColoresApp.tinta, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  paraVendedor ? 'Tu respaldo: así llegó al Hub' : 'Así llegó el equipo al Hub',
                  style: Tipos.subtitulo.copyWith(fontSize: 15),
                ),
              ),
              const Icon(Icons.lock_outline, size: 16, color: ColoresApp.pizarra),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'Fotos del ${formatearFecha(recepcion.creadaEn)} · no se pueden cambiar ni borrar',
            style: Tipos.pequeno.copyWith(fontSize: 12.5),
          ),
          if (recepcion.nota.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Nota del Hub: «${recepcion.nota}»',
              style: Tipos.pequeno.copyWith(fontSize: 13.5, color: ColoresApp.tinta),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final ruta in recepcion.fotos) _Miniatura(url: InspeccionService.urlEvidencia(ruta)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Miniatura extends StatelessWidget {
  const _Miniatura({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Ver foto de recepción en grande',
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => showDialog<void>(
          context: context,
          builder: (contexto) => Dialog(
            child: Stack(
              children: [
                InteractiveViewer(child: Image.network(url, fit: BoxFit.contain)),
                Positioned(
                  right: 4,
                  top: 4,
                  child: IconButton.filled(
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.of(contexto).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ),
              ],
            ),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.network(
            url,
            width: 84,
            height: 84,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const SizedBox(
              width: 84,
              height: 84,
              child: Icon(Icons.broken_image_outlined),
            ),
          ),
        ),
      ),
    );
  }
}

/// HU05: el reclamo ya abierto, para el comprador o el vendedor.
class TarjetaReclamo extends StatelessWidget {
  const TarjetaReclamo({super.key, required this.reclamo, this.paraVendedor = false});

  final Reclamo reclamo;
  final bool paraVendedor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4D6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _ambar, width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.report_outlined, color: _ambar),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  paraVendedor
                      ? 'El comprador abrió un reclamo'
                      : 'Reclamo ${reclamo.abierto ? 'abierto' : 'resuelto'}',
                  style: Tipos.subtitulo.copyWith(fontSize: 15, color: _ambar),
                ),
                Text(
                  'El ${formatearFecha(reclamo.creadoEn)}: «${reclamo.descripcion}»',
                  style: Tipos.pequeno.copyWith(fontSize: 14, color: ColoresApp.tinta),
                ),
                const SizedBox(height: 4),
                Text(
                  paraVendedor
                      ? 'Las fotos de recepción del Hub y el checklist son tu '
                          'respaldo: se comparan con lo que dice el comprador.'
                      : 'Lo revisamos comparando las fotos de cómo llegó al Hub '
                          'con el checklist del inspector.',
                  style: Tipos.pequeno.copyWith(fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// HU05, escenarios 3 y 4: qué puede hacer el comprador con su equipo ya
/// enviado. Explica el plazo antes de reclamar (heurística 5).
class PlazoReclamo extends StatelessWidget {
  const PlazoReclamo({
    super.key,
    required this.pedido,
    required this.alConfirmarRecibido,
    required this.alReclamar,
    this.ahora,
  });

  final Pedido pedido;
  final VoidCallback alConfirmarRecibido;
  final VoidCallback alReclamar;

  /// Para las pruebas.
  final DateTime? ahora;

  @override
  Widget build(BuildContext context) {
    final situacion = ReglasReclamo.situacion(pedido, ahora);
    final vence = ReglasReclamo.venceEn(pedido);

    switch (situacion) {
      case SituacionReclamo.noAplica:
      case SituacionReclamo.reclamado:
        return const SizedBox.shrink();
      case SituacionReclamo.porConfirmar:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const RecuadroInfo(
              icono: Icons.local_shipping_outlined,
              texto: 'Cuando tengas el equipo en tus manos, confírmalo. Desde ese '
                  'momento tienes ${ReglasReclamo.plazoDias} días para reclamar si '
                  'algo no está bien.',
            ),
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: alConfirmarRecibido,
              icon: const Icon(Icons.inventory_2_outlined),
              label: const Text('Ya recibí mi equipo'),
            ),
          ],
        );
      case SituacionReclamo.enPlazo:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RecuadroInfo(
              icono: Icons.schedule,
              texto: 'Recibiste tu equipo. Si encuentras un problema, puedes '
                  'reclamar hasta el ${formatearFecha(vence!)}.',
            ),
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: alReclamar,
              icon: const Icon(Icons.report_outlined),
              label: const Text('Tengo un problema con el equipo'),
            ),
          ],
        );
      case SituacionReclamo.fueraDePlazo:
        return RecuadroInfo(
          icono: Icons.event_busy_outlined,
          texto: 'El plazo de ${ReglasReclamo.plazoDias} días para reclamar terminó '
              'el ${formatearFecha(vence!)}. Si necesitas ayuda, escríbenos.',
        );
    }
  }
}
