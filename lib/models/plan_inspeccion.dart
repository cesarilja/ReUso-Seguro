/// Planes de inspección que paga el vendedor (HU16 y HU17).
///
/// Los mismos números están en el servidor (`costo_inspeccion` en
/// supabase/15_planes_y_escala.sql): el precio que vale es el del servidor,
/// este solo sirve para mostrarlo antes de publicar y de pagar.
enum PlanInspeccion {
  basica(
    clave: 'basica',
    nombre: 'Básica',
    porcentaje: 0.04,
    minimo: 5,
    maximo: 30,
    tiempo: '1 a 2 días',
    diasReclamo: 3,
    incluye: [
      'Checklist de su tipo de equipo, calificado del 1 al 4',
      'Fotos de cómo llegó al Hub',
      'Certificado técnico',
    ],
  ),
  detallada(
    clave: 'detallada',
    nombre: 'Detallada',
    porcentaje: 0.08,
    minimo: 10,
    maximo: 60,
    tiempo: '2 a 3 días',
    diasReclamo: 7,
    incluye: [
      'Todo lo de la Básica',
      'Una observación escrita del inspector en cada punto',
      'Sello «Inspección detallada» en el catálogo',
      'El comprador tiene 7 días para reclamar (en vez de 3)',
    ],
  );

  const PlanInspeccion({
    required this.clave,
    required this.nombre,
    required this.porcentaje,
    required this.minimo,
    required this.maximo,
    required this.tiempo,
    required this.diasReclamo,
    required this.incluye,
  });

  /// Cómo se guarda en la base de datos.
  final String clave;
  final String nombre;

  /// Parte del precio de venta que cuesta (0.04 = 4 %).
  final double porcentaje;

  /// Lo mínimo y lo máximo que se cobra, en dólares.
  final double minimo;
  final double maximo;

  /// Cuánto tarda el Hub sin Express.
  final String tiempo;

  /// HU18: días que tiene el comprador para reclamar.
  final int diasReclamo;

  final List<String> incluye;

  /// Cuánto cuesta inspeccionar un equipo de [precio] dólares.
  double costo(double precio, {bool express = false}) {
    final base = (precio * porcentaje).clamp(minimo, maximo).toDouble();
    return _redondear(base + (express ? ReglasPlan.precioExpress : 0));
  }

  /// Texto corto del precio, por ejemplo: «4 % (mín. $5, máx. $30)».
  String get tarifa =>
      '${(porcentaje * 100).round()} % (mín. \$${minimo.round()}, máx. \$${maximo.round()})';

  static PlanInspeccion desde(String? valor) =>
      valor == detallada.clave ? detallada : basica;
}

/// Reglas de dinero del Sprint 4 (iguales a las del servidor).
class ReglasPlan {
  const ReglasPlan._();

  /// HU16: lo que se suma por pedir la inspección Express.
  static const double precioExpress = 8;
  static const String tiempoExpress = 'menos de 24 h';

  /// HU17: la comisión por venta bajó del 8 % al 5 %.
  static const double tasaComision = 0.05;

  /// Comisión de una venta de [precio] dólares.
  static double comision(double precio) => _redondear(precio * tasaComision);
}

double _redondear(double valor) => (valor * 100).round() / 100;
