/// Funciones para mostrar montos siempre de la misma forma.

/// Monto en dólares, por ejemplo: $180,00
String formatearDolares(double monto) =>
    '\$${monto.toStringAsFixed(2).replaceAll('.', ',')}';

/// Fecha y hora, por ejemplo: 27/10/2026, 18:35
String formatearFecha(DateTime fecha) {
  String dos(int numero) => numero.toString().padLeft(2, '0');
  return '${dos(fecha.day)}/${dos(fecha.month)}/${fecha.year}, '
      '${dos(fecha.hour)}:${dos(fecha.minute)}';
}
