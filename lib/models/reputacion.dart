import 'plan_inspeccion.dart';

/// Nivel del vendedor (HU20). Sale de sus inspecciones, no de reseñas.
///
/// Las reglas son las mismas del servidor (`reputacion_vendedor` en
/// supabase/16_reputacion.sql): el nivel que vale es el del servidor.
enum NivelVendedor {
  nuevo('nuevo', 'Vendedor nuevo', 'Todavía tiene menos de 3 ventas inspeccionadas.'),
  vendedor('vendedor', 'Vendedor', 'Tiene historial, pero todavía no llega a Confiable.'),
  confiable(
    'confiable',
    'Confiable',
    'Casi todos sus equipos pasan la inspección y declara con honestidad.',
  ),
  destacado(
    'destacado',
    'Destacado',
    'Muchas ventas aprobadas, declara con honestidad y entrega rápido.',
  );

  const NivelVendedor(this.clave, this.nombre, this.descripcion);

  final String clave;
  final String nombre;
  final String descripcion;

  /// Confiable y Destacado pagan menos comisión.
  bool get tieneBeneficio => this == confiable || this == destacado;

  static NivelVendedor desde(String? valor) => NivelVendedor.values.firstWhere(
        (n) => n.clave == valor,
        orElse: () => nuevo,
      );
}

/// Reglas de la reputación (iguales a las del servidor).
class ReglasReputacion {
  const ReglasReputacion._();

  static const int minimoVentas = 3;

  /// Porcentajes enteros, para comparar sin errores de redondeo.
  static const int porcentajeConfiable = 90;

  static const int ventasDestacado = 10;
  static const int porcentajeDestacado = 95;
  static const double diasDestacado = 2;

  /// Cuántas ventas recientes se miran para las declaraciones inexactas.
  static const int ventasRecientes = 5;

  /// La comisión de los niveles Confiable y Destacado.
  static const double tasaConBeneficio = 0.04;

  static NivelVendedor nivel({
    required int ventas,
    required int aprobadas,
    required int inexactasRecientes,
    double? diasEntrega,
  }) {
    if (ventas < minimoVentas) return NivelVendedor.nuevo;
    // Igual que en SQL: se compara con enteros (aprobadas × 100 contra
    // ventas × 90) para no tener problemas de redondeo.
    final honesto = inexactasRecientes == 0;
    if (ventas >= ventasDestacado &&
        aprobadas * 100 >= ventas * porcentajeDestacado &&
        honesto &&
        diasEntrega != null &&
        diasEntrega <= diasDestacado) {
      return NivelVendedor.destacado;
    }
    if (aprobadas * 100 >= ventas * porcentajeConfiable && honesto) {
      return NivelVendedor.confiable;
    }
    return NivelVendedor.vendedor;
  }

  static double tasaComision(NivelVendedor nivel) =>
      nivel.tieneBeneficio ? tasaConBeneficio : ReglasPlan.tasaComision;
}

/// La reputación de un vendedor («entity» Reputacion).
class Reputacion {
  const Reputacion({
    required this.vendedorId,
    this.ventas = 0,
    this.aprobadas = 0,
    this.inexactasRecientes = 0,
    this.diasEntrega,
    this.nivel = NivelVendedor.nuevo,
  });

  /// Un vendedor sin ventas inspeccionadas.
  const Reputacion.sinVentas(this.vendedorId)
      : ventas = 0,
        aprobadas = 0,
        inexactasRecientes = 0,
        diasEntrega = null,
        nivel = NivelVendedor.nuevo;

  factory Reputacion.desdeJson(Map<String, dynamic> json) => Reputacion(
        vendedorId: json['vendedor_id'] as String,
        ventas: (json['ventas'] as num?)?.toInt() ?? 0,
        aprobadas: (json['aprobadas'] as num?)?.toInt() ?? 0,
        inexactasRecientes: (json['inexactas_recientes'] as num?)?.toInt() ?? 0,
        diasEntrega: (json['dias_entrega'] as num?)?.toDouble(),
        nivel: NivelVendedor.desde(json['nivel'] as String?),
      );

  final String vendedorId;

  /// Ventas que ya tienen dictamen.
  final int ventas;
  final int aprobadas;

  /// Declaraciones inexactas en sus últimas 5 ventas (HU19).
  final int inexactasRecientes;

  /// Días promedio entre el pago del comprador y la entrega en el Hub.
  final double? diasEntrega;
  final NivelVendedor nivel;

  /// Porcentaje de equipos aprobados (0 a 100), sin decimales.
  int get porcentajeAprobadas =>
      ventas == 0 ? 0 : (aprobadas * 100 / ventas).round();

  double get tasaComision => ReglasReputacion.tasaComision(nivel);

  /// Texto sencillo, por ejemplo «9 de 10 equipos aprobados».
  String get textoAprobadas =>
      '$aprobadas de $ventas ${ventas == 1 ? 'equipo aprobado' : 'equipos aprobados'}';

  /// Texto de los días de entrega, por ejemplo «1,5 días».
  String? get textoEntrega {
    final dias = diasEntrega;
    if (dias == null) return null;
    final texto = dias.toStringAsFixed(1).replaceAll('.', ',');
    return '$texto ${dias == 1 ? 'día' : 'días'}';
  }

  /// HU20, escenario 3: lo que le falta para el siguiente nivel, o null si
  /// ya es Destacado.
  String? get queFalta {
    switch (nivel) {
      case NivelVendedor.destacado:
        return null;
      case NivelVendedor.nuevo:
        final faltan = ReglasReputacion.minimoVentas - ventas;
        return 'Te ${faltan == 1 ? 'falta 1 venta inspeccionada' : 'faltan $faltan ventas inspeccionadas'} '
            'para que se calcule tu nivel.';
      case NivelVendedor.vendedor:
        final motivos = <String>[
          if (inexactasRecientes > 0)
            'que ninguna de tus últimas ${ReglasReputacion.ventasRecientes} '
                'ventas tenga declaración inexacta (hoy '
                '${inexactasRecientes == 1 ? 'hay 1' : 'hay $inexactasRecientes'})',
          if (aprobadas * 100 < ventas * ReglasReputacion.porcentajeConfiable)
            'que el 90 % de tus equipos se aprueben (hoy es el $porcentajeAprobadas %)',
        ];
        return 'Para ser Confiable necesitas ${motivos.join(' y ')}.';
      case NivelVendedor.confiable:
        return 'Para ser Destacado necesitas 10 ventas, el 95 % aprobadas y '
            'entregar en el Hub en 2 días o menos en promedio.';
    }
  }
}
