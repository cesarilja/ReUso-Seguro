import 'package:flutter/material.dart';

import '../models/equipo.dart';
import '../tema.dart';
import 'pegatina.dart';

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

/// Tarjeta de un equipo dentro de la cuadrícula del catálogo.
class TarjetaEquipo extends StatelessWidget {
  const TarjetaEquipo({
    super.key,
    required this.equipo,
    required this.alTocar,
  });

  final Equipo equipo;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    return Pegatina(
      alTocar: alTocar,
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
                  child: Image.asset(
                    equipo.imagen,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.medium,
                  ),
                ),
                Positioned(
                  left: 12,
                  top: 12,
                  child: EtiquetaEstado(estado: equipo.estado),
                ),
              ],
            ),
          ),
          Container(height: 2, color: ColoresApp.tinta),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Alto fijo de dos líneas para que todas las tarjetas
                // queden alineadas, tengan el título corto o largo.
                SizedBox(
                  height: 42,
                  child: Text(
                    equipo.titulo,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15.5,
                      height: 1.3,
                      fontWeight: FontWeight.w500,
                      color: ColoresApp.tinta,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(equipo.precioFormateado, style: Tipos.precio),
                const SizedBox(height: 2),
                Text(
                  'Vende ${equipo.vendedor}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
