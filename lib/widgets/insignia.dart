import 'package:flutter/material.dart';

/// Círculo con un número, por ejemplo las ventas nuevas en «Mis ventas»
/// (HU04, heurística 1: visibilidad del estado del sistema).
///
/// Con 0 no se muestra. Los lectores de pantalla leen «3 ventas nuevas».
class InsigniaContador extends StatelessWidget {
  const InsigniaContador({
    super.key,
    required this.cantidad,
    this.descripcion = 'nuevas',
  });

  final int cantidad;

  /// Qué cuenta, para los lectores de pantalla.
  final String descripcion;

  @override
  Widget build(BuildContext context) {
    if (cantidad <= 0) return const SizedBox.shrink();
    final texto = cantidad > 9 ? '9+' : '$cantidad';
    return Semantics(
      label: '$cantidad $descripcion',
      child: ExcludeSemantics(
        child: Container(
          constraints: const BoxConstraints(minWidth: 20),
          height: 20,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            // Rojo oscuro con texto blanco: contraste WCAG AA.
            color: const Color(0xFFB3261E),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            texto,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}
