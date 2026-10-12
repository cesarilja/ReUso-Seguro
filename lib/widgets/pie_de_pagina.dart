import 'package:flutter/material.dart';

import '../tema.dart';

/// Franja oscura al final de cada pantalla.
class PieDePagina extends StatelessWidget {
  const PieDePagina({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: ColoresApp.tinta,
      padding: EdgeInsets.symmetric(
        horizontal: margenLateral(context),
        vertical: 32,
      ),
      child: Column(
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
        ],
      ),
    );
  }
}
