import 'package:flutter/material.dart';

import '../models/reputacion.dart';
import '../tema.dart';

/// Widgets de la HU20. El nivel siempre va con ícono y texto, nunca solo
/// con color.

/// Ícono y colores de cada nivel.
extension EstiloNivel on NivelVendedor {
  IconData get icono => switch (this) {
        NivelVendedor.nuevo => Icons.fiber_new_outlined,
        NivelVendedor.vendedor => Icons.person_outline,
        NivelVendedor.confiable => Icons.verified_user_outlined,
        NivelVendedor.destacado => Icons.military_tech_outlined,
      };

  Color get color => switch (this) {
        NivelVendedor.nuevo => ColoresApp.pizarra,
        NivelVendedor.vendedor => ColoresApp.tinta,
        NivelVendedor.confiable => const Color(0xFF1F7A44),
        NivelVendedor.destacado => const Color(0xFF6A2C7A),
      };

  Color get fondo => switch (this) {
        NivelVendedor.nuevo => const Color(0xFFEDEEF2),
        NivelVendedor.vendedor => ColoresApp.nube,
        NivelVendedor.confiable => const Color(0xFFDFF3E6),
        NivelVendedor.destacado => ColoresApp.lila,
      };
}

/// Sello del nivel, por ejemplo «Confiable».
class SelloVendedor extends StatelessWidget {
  const SelloVendedor({super.key, required this.nivel, this.compacto = false});

  final NivelVendedor nivel;
  final bool compacto;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Nivel del vendedor: ${nivel.nombre}',
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compacto ? 6 : 10,
          vertical: compacto ? 2 : 5,
        ),
        decoration: BoxDecoration(
          color: nivel.fondo,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(nivel.icono, size: compacto ? 14 : 18, color: nivel.color),
            const SizedBox(width: 4),
            Text(
              nivel.nombre,
              style: Tipos.pequeno.copyWith(
                fontSize: compacto ? 12 : 13.5,
                color: nivel.color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// La reputación de un vendedor con sus datos. [paraVendedor] agrega su
/// comisión y lo que le falta para el siguiente nivel (HU20, escenario 3).
class ResumenReputacion extends StatelessWidget {
  const ResumenReputacion({
    super.key,
    required this.reputacion,
    this.paraVendedor = false,
  });

  final Reputacion reputacion;
  final bool paraVendedor;

  @override
  Widget build(BuildContext context) {
    final nivel = reputacion.nivel;
    final nuevo = nivel == NivelVendedor.nuevo;
    final entrega = reputacion.textoEntrega;
    final queFalta = reputacion.queFalta;

    Widget dato(IconData icono, String texto) => Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icono, size: 18, color: ColoresApp.tinta),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  texto,
                  style: Tipos.pequeno.copyWith(fontSize: 14, color: ColoresApp.tinta),
                ),
              ),
            ],
          ),
        );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: nivel.color.withValues(alpha: 0.5), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  paraVendedor ? 'Tu reputación' : 'Reputación del vendedor',
                  style: Tipos.subtitulo.copyWith(fontSize: 15),
                ),
              ),
              SelloVendedor(nivel: nivel),
            ],
          ),
          const SizedBox(height: 4),
          Text(nivel.descripcion, style: Tipos.pequeno.copyWith(fontSize: 13.5)),
          // Escenario 1: sin porcentajes que confundan si es nuevo.
          if (nuevo)
            dato(
              Icons.inventory_2_outlined,
              reputacion.ventas == 0
                  ? 'Todavía no tiene ventas inspeccionadas.'
                  : 'Lleva ${reputacion.ventas} '
                      '${reputacion.ventas == 1 ? 'venta inspeccionada' : 'ventas inspeccionadas'}.',
            )
          else ...[
            dato(Icons.fact_check_outlined, '${reputacion.textoAprobadas} en el Hub'),
            dato(
              Icons.handshake_outlined,
              reputacion.inexactasRecientes == 0
                  ? 'Declaró con honestidad sus últimas ventas'
                  : '${reputacion.inexactasRecientes} '
                      '${reputacion.inexactasRecientes == 1 ? 'declaración inexacta' : 'declaraciones inexactas'} '
                      'en sus últimas ${ReglasReputacion.ventasRecientes} ventas',
            ),
            if (entrega != null)
              dato(Icons.local_shipping_outlined, 'Entrega en el Hub en $entrega en promedio'),
          ],
          if (paraVendedor) ...[
            const Divider(height: 22),
            dato(
              Icons.savings_outlined,
              'Tu comisión por venta: ${(reputacion.tasaComision * 100).round()} %'
              '${nivel.tieneBeneficio ? ' (beneficio por tu nivel)' : ''}',
            ),
            if (queFalta != null) dato(Icons.trending_up, queFalta),
          ],
          if (!paraVendedor) ...[
            const SizedBox(height: 8),
            Text(
              'Sale de las inspecciones del Hub, no de reseñas.',
              style: Tipos.pequeno.copyWith(fontSize: 12.5),
            ),
          ],
        ],
      ),
    );
  }
}
