import 'package:flutter/material.dart';

import '../services/sesion_service.dart';
import '../tema.dart';
import 'navegacion.dart';

/// Franja oscura al final de cada pantalla, con accesos a las secciones.
class PieDePagina extends StatelessWidget {
  const PieDePagina({super.key});

  @override
  Widget build(BuildContext context) {
    final ancha = MediaQuery.sizeOf(context).width >= 760;

    final marca = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/images/logo.png', width: 32, height: 32),
            const SizedBox(width: 10),
            Text(
              'ReUso Seguro',
              style: Tipos.subtitulo.copyWith(
                fontSize: 18,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Transacciones de segunda mano, sin riesgo a estafas',
          style: TextStyle(fontSize: 14, color: ColoresApp.cielo),
        ),
        const SizedBox(height: 14),
        const Text(
          'Proyecto académico · Universidad Metropolitana · Pagos simulados',
          style: TextStyle(fontSize: 12.5, color: ColoresApp.cielo),
        ),
      ],
    );

    final enlaces = ListenableBuilder(
      listenable: SesionService.instancia,
      builder: (context, _) {
        final conSesion = SesionService.instancia.haySesion;
        return Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            for (final s in [
              Seccion.inicio,
              Seccion.comoFunciona,
              if (conSesion) Seccion.compras,
              if (conSesion) Seccion.ventas,
            ])
              TextButton.icon(
                onPressed: () => irA(context, s),
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                icon: Icon(s.icono, size: 18, color: ColoresApp.cielo),
                label: Text(s.nombre),
              ),
          ],
        );
      },
    );

    return Container(
      width: double.infinity,
      color: ColoresApp.tinta,
      padding: EdgeInsets.symmetric(
        horizontal: margenLateral(context),
        vertical: 32,
      ),
      child: ancha
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: marca),
                const SizedBox(width: 24),
                Flexible(child: enlaces),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [marca, const SizedBox(height: 18), enlaces],
            ),
    );
  }
}
