/// Funciones para mostrar montos siempre de la misma forma.

/// Monto en dólares, por ejemplo: $180,00
String formatearDolares(double monto) =>
    '\$${monto.toStringAsFixed(2).replaceAll('.', ',')}';
