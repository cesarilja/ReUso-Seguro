import 'package:flutter/material.dart';

import '../models/equipo.dart';
import '../tema.dart';

/// Muestra una foto del equipo.
///
/// Si el equipo tiene fotos reales, las trae de Supabase Storage. Mientras
/// carga muestra un indicador (visibilidad del estado del sistema), y si la
/// foto falla o no existe usa la ilustración de respaldo.
class ImagenEquipo extends StatelessWidget {
  const ImagenEquipo({
    super.key,
    required this.equipo,
    this.indice = 0,
    this.ajuste = BoxFit.cover,
  });

  final Equipo equipo;

  /// Cuál de las fotos mostrar (0 = la principal).
  final int indice;
  final BoxFit ajuste;

  @override
  Widget build(BuildContext context) {
    if (equipo.fotos.isEmpty) return _Respaldo(equipo: equipo);

    final url = equipo.fotos[indice.clamp(0, equipo.fotos.length - 1)];
    return Container(
      color: ColoresApp.nube,
      child: Image.network(
        url,
        fit: ajuste,
        filterQuality: FilterQuality.medium,
        // Mientras la foto llega se ve un indicador de carga.
        loadingBuilder: (context, hijo, progreso) {
          if (progreso == null) return hijo;
          return const Center(
            child: SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: ColoresApp.orquidea,
              ),
            ),
          );
        },
        errorBuilder: (context, error, pila) => _Respaldo(equipo: equipo),
      ),
    );
  }
}

/// Ilustración del equipo, o un ícono si tampoco hay ilustración.
class _Respaldo extends StatelessWidget {
  const _Respaldo({required this.equipo});

  final Equipo equipo;

  @override
  Widget build(BuildContext context) {
    final ilustracion = equipo.ilustracion;
    if (ilustracion != null) {
      return Image.asset(
        ilustracion,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
      );
    }
    return Container(
      color: ColoresApp.nube,
      alignment: Alignment.center,
      child: const Icon(
        Icons.devices_other_outlined,
        size: 48,
        color: ColoresApp.pizarra,
      ),
    );
  }
}
