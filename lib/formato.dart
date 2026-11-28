// Funciones para mostrar montos siempre de la misma forma.

/// Monto en dólares con punto decimal, por ejemplo: $500.00
String formatearDolares(double monto) => '\$${monto.toStringAsFixed(2)}';

/// Monto en bolívares con separador de miles y punto decimal,
/// por ejemplo: Bs. 463,179.60
String formatearBolivares(double montoBs) {
  final negativo = montoBs < 0;
  final partes = montoBs.abs().toStringAsFixed(2).split('.');
  final enteros = partes[0];
  final decimales = partes[1];
  final conMiles = enteros.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  return '${negativo ? '-' : ''}Bs. $conMiles.$decimales';
}

/// Fecha y hora, por ejemplo: 27/10/2026, 18:35
String formatearFecha(DateTime fecha) {
  String dos(int numero) => numero.toString().padLeft(2, '0');
  return '${dos(fecha.day)}/${dos(fecha.month)}/${fecha.year}, '
      '${dos(fecha.hour)}:${dos(fecha.minute)}';
}
