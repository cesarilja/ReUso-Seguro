import 'package:flutter/material.dart';

import '../models/equipo.dart';
import '../services/reputacion_service.dart';
import '../tema.dart';
import 'imagen_equipo.dart';
import 'pegatina.dart';
import 'plan_widgets.dart';
import 'reputacion_widgets.dart';

/// Etiqueta con el estado de la publicación: Disponible o Reservado.
class EtiquetaEstado extends StatelessWidget {
  const EtiquetaEstado({super.key, required this.estado});

  final EstadoPublicacion estado;

  @override
  Widget build(BuildContext context) {
    final disponible = estado == EstadoPublicacion.disponible;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: disponible ? Colors.white : ColoresApp.tinta,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: ColoresApp.tinta, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (disponible) ...[
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: ColoresApp.verde,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            estado.nombre,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.3,
              fontWeight: FontWeight.w700,
              color: disponible ? ColoresApp.tinta : Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta de un equipo dentro del catálogo o de una vitrina horizontal.
///
/// Al pasar el cursor encima:
/// - si tiene más de una foto, muestra la segunda foto automáticamente;
/// - resalta el indicador «Ver →» para dejar claro que se puede abrir.
class TarjetaEquipo extends StatefulWidget {
  const TarjetaEquipo({
    super.key,
    required this.equipo,
    required this.alTocar,
    this.esNuevo = false,
  });

  final Equipo equipo;
  final VoidCallback alTocar;

  /// Muestra una etiqueta «NUEVO» (usada en el carrusel de últimos publicados).
  final bool esNuevo;

  @override
  State<TarjetaEquipo> createState() => _TarjetaEquipoState();
}

class _TarjetaEquipoState extends State<TarjetaEquipo> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final equipo = widget.equipo;
    final tieneMasFotos = equipo.fotos.length > 1;
    final indiceFoto = (_hover && tieneMasFotos) ? 1 : 0;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Pegatina(
        alTocar: widget.alTocar,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // La imagen ocupa todo el espacio que deja el texto.
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Opacity(
                    // Los reservados se ven apagados.
                    opacity: equipo.estaDisponible ? 1.0 : 0.45,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: ImagenEquipo(
                        key: ValueKey('${equipo.id}-$indiceFoto'),
                        equipo: equipo,
                        indice: indiceFoto,
                      ),
                    ),
                  ),
                  // Estado (arriba izquierda) + etiqueta NUEVO si aplica
                  Positioned(
                    left: 10,
                    top: 10,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        EtiquetaEstado(estado: equipo.estado),
                        if (widget.esNuevo && equipo.estaDisponible) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: ColoresApp.orquidea,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: ColoresApp.tinta,
                                width: 1.5,
                              ),
                            ),
                            child: const Text(
                              'NUEVO',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // HU16: sello de la inspección detallada y puntaje (HU15).
                  if (equipo.inspeccionDetallada ||
                      equipo.puntajeInspeccion != null)
                    Positioned(
                      right: 10,
                      top: 10,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (equipo.inspeccionDetallada)
                            const SelloDetallada(compacto: true),
                          if (equipo.inspeccionDetallada &&
                              equipo.puntajeInspeccion != null)
                            const SizedBox(height: 6),
                          if (equipo.puntajeInspeccion != null)
                            EtiquetaPuntaje(
                              puntaje: equipo.puntajeInspeccion!,
                              compacta: true,
                            ),
                        ],
                      ),
                    ),
                  // Badge Express 24h (abajo izquierda)
                  if (equipo.express && equipo.estaDisponible)
                    Positioned(
                      left: 10,
                      bottom: 10,
                      child: Tooltip(
                        message: 'Inspección Express: revisado en menos de 24 h',
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: ColoresApp.tinta,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.bolt,
                                size: 13,
                                color: Color(0xFFFFD54F),
                              ),
                              SizedBox(width: 3),
                              Text(
                                'Express 24h',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  // Indicador de varias fotos (abajo derecha)
                  if (tieneMasFotos)
                    Positioned(
                      right: 10,
                      bottom: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: ColoresApp.tinta.withAlpha(180),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (var i = 0; i < equipo.fotos.length.clamp(0, 4); i++)
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 160),
                                margin: const EdgeInsets.symmetric(horizontal: 2),
                                width: i == indiceFoto ? 10 : 5,
                                height: 5,
                                decoration: BoxDecoration(
                                  color: i == indiceFoto
                                      ? Colors.white
                                      : Colors.white.withAlpha(120),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Container(height: 2, color: ColoresApp.tinta),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (equipo.categoria != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        equipo.categoria!.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.7,
                          color: ColoresApp.vinca,
                        ),
                      ),
                    ),
                  // Alto fijo de dos líneas para alinear todas las tarjetas.
                  SizedBox(
                    height: 40,
                    child: Text(
                      equipo.titulo,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                        color: ColoresApp.tinta,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          equipo.precioFormateado,
                          style: Tipos.precio.copyWith(fontSize: 22),
                        ),
                      ),
                      AnimatedOpacity(
                        duration: const Duration(milliseconds: 150),
                        opacity: _hover ? 1.0 : 0.0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: ColoresApp.lila,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Ver',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: ColoresApp.tinta,
                                ),
                              ),
                              SizedBox(width: 2),
                              Icon(
                                Icons.arrow_forward,
                                size: 13,
                                color: ColoresApp.tinta,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  // HU20: el sello del vendedor si es Confiable o Destacado.
                  ListenableBuilder(
                    listenable: ReputacionService.instancia,
                    builder: (context, _) {
                      final nivel = ReputacionService.instancia
                          .de(equipo.vendedorId)
                          ?.nivel;
                      return Row(
                        children: [
                          Flexible(
                            child: Text(
                              'Vende ${equipo.vendedor}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Tipos.pequeno.copyWith(fontSize: 12.5),
                            ),
                          ),
                          if (nivel != null && nivel.tieneBeneficio) ...[
                            const SizedBox(width: 6),
                            SelloVendedor(nivel: nivel, compacto: true),
                          ],
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
