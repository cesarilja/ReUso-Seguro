import 'package:flutter/material.dart';

import '../formato.dart';
import '../models/dictamen.dart';
import '../models/inspeccion.dart';
import '../services/inspeccion_service.dart';
import '../tema.dart';

const Color _verde = Color(0xFF1F7A44);
const Color _rojo = Color(0xFFB3261E);

/// El resultado del dictamen con color, ícono y texto (nunca solo color,
/// criterio de usabilidad de la HU08 y WCAG 1.4.1).
class TarjetaDictamen extends StatelessWidget {
  const TarjetaDictamen({super.key, required this.dictamen, this.paraVendedor = false});

  final Dictamen dictamen;

  /// Cambia el texto de ayuda según quién lo lea.
  final bool paraVendedor;

  @override
  Widget build(BuildContext context) {
    final aprobado = dictamen.aprobado;
    final color = aprobado ? _verde : _rojo;
    final ayuda = aprobado
        ? (paraVendedor
            ? 'El equipo pasó la inspección del Hub.'
            : 'Tu equipo pasó la inspección. Te lo enviaremos.')
        : (paraVendedor
            ? 'El equipo no pasó la inspección. Te lo devolveremos.'
            : 'El equipo no pasó la inspección. Te devolveremos el monto '
                'completo.');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: aprobado ? const Color(0xFFDFF3E6) : const Color(0xFFFBE9E8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color, width: 2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            aprobado ? Icons.verified : Icons.cancel_outlined,
            color: color,
            size: 30,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dictamen: ${dictamen.resultado.nombre}',
                  style: Tipos.subtitulo.copyWith(color: color),
                ),
                const SizedBox(height: 2),
                Text(
                  ayuda,
                  style: Tipos.pequeno.copyWith(
                    fontSize: 14,
                    color: ColoresApp.tinta,
                  ),
                ),
                if (dictamen.motivo.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    '«${dictamen.motivo}»',
                    style: Tipos.pequeno.copyWith(
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                      color: ColoresApp.tinta,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  'Emitido el ${formatearFecha(dictamen.emitidoEn)}',
                  style: Tipos.pequeno,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Lo que encontró el inspector en cada punto del checklist.
class ResumenChecklist extends StatelessWidget {
  const ResumenChecklist({
    super.key,
    required this.inspeccion,
    required this.categoria,
  });

  final Inspeccion inspeccion;
  final String? categoria;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final punto in PuntoChecklist.para(categoria))
          _LineaPunto(
            punto: punto,
            revision: inspeccion.puntos[punto.clave],
          ),
      ],
    );
  }
}

class _LineaPunto extends StatelessWidget {
  const _LineaPunto({required this.punto, required this.revision});

  final PuntoChecklist punto;
  final RevisionPunto? revision;

  @override
  Widget build(BuildContext context) {
    final resultado = revision?.resultado;
    final (icono, color, texto) = switch (resultado) {
      ResultadoPunto.ok => (Icons.check_circle, _verde, 'Funciona bien'),
      ResultadoPunto.falla => (Icons.warning_amber_rounded, _rojo, 'Falla'),
      ResultadoPunto.noAplica => (
          Icons.remove_circle_outline,
          ColoresApp.pizarra,
          'No aplica'
        ),
      null => (Icons.help_outline, ColoresApp.pizarra, 'Sin revisar'),
    };
    final evidencias = revision?.evidencias ?? const <String>[];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${punto.nombre}: $texto',
                  style: Tipos.pequeno.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: ColoresApp.tinta,
                  ),
                ),
                if (revision?.tieneFalla ?? false) ...[
                  Text(revision!.nota, style: Tipos.pequeno),
                  if (evidencias.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final ruta in evidencias)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              InspeccionService.urlEvidencia(ruta),
                              width: 64,
                              height: 64,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const SizedBox(
                                width: 64,
                                height: 64,
                                child: Icon(Icons.broken_image_outlined),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
