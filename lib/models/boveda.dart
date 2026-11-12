import 'pedido.dart';

double _dinero(Object? valor) => (valor as num?)?.toDouble() ?? 0;

DateTime? _fecha(Object? valor) =>
    valor is String ? DateTime.parse(valor).toLocal() : null;

/// Los 4 totales de la bóveda (HU09, escenario 1).
class TotalesBoveda {
  const TotalesBoveda({
    this.enCustodia = 0,
    this.liberado = 0,
    this.reembolsado = 0,
    this.comisiones = 0,
  });

  factory TotalesBoveda.desdeJson(Map<String, dynamic>? json) => TotalesBoveda(
        enCustodia: _dinero(json?['en_custodia']),
        liberado: _dinero(json?['liberado']),
        reembolsado: _dinero(json?['reembolsado']),
        comisiones: _dinero(json?['comisiones']),
      );

  /// Lo que hay retenido ahora mismo.
  final double enCustodia;

  /// Lo que ya se les pagó a los vendedores.
  final double liberado;

  /// Lo que se les devolvió a los compradores.
  final double reembolsado;

  /// Lo que ganó la plataforma (8 % de cada venta aprobada).
  final double comisiones;

  /// Todo el dinero que entró alguna vez a la bóveda.
  double get totalIngresado => enCustodia + liberado + reembolsado + comisiones;
}

/// Un pedido cuyo dinero no coincide con sus movimientos (escenario 3).
class Descuadre {
  const Descuadre({
    required this.pedidoId,
    required this.numero,
    required this.titulo,
    required this.estado,
    required this.esperado,
    required this.real,
  });

  factory Descuadre.desdeJson(Map<String, dynamic> json) => Descuadre(
        pedidoId: json['pedido_id'] as String,
        numero: (json['numero'] as num).toInt(),
        titulo: json['titulo'] as String? ?? 'Equipo',
        estado: EstadoPedido.desde(json['estado'] as String?),
        esperado: _dinero(json['esperado']),
        real: _dinero(json['real']),
      );

  final String pedidoId;
  final int numero;
  final String titulo;
  final EstadoPedido estado;

  /// Lo que debería estar en custodia según el estado del pedido.
  final double esperado;

  /// Lo que dicen los movimientos que está en custodia.
  final double real;

  String get codigo => 'P-$numero';

  /// Negativo: salió más dinero del que debía (por ejemplo, un pago
  /// liberado dos veces). Positivo: sobra dinero en custodia.
  double get diferencia => real - esperado;

  /// En palabras sencillas, qué pasó con este pedido.
  String get explicacion => diferencia < 0
      ? 'Salió más dinero del que debía (posible pago repetido).'
      : 'Hay más dinero retenido del que corresponde a su estado.';
}

/// Una liberación que falló (HU06, escenario 3: el administrador la ve).
class LiberacionPendiente {
  const LiberacionPendiente({
    required this.numero,
    required this.titulo,
    required this.vendedor,
    required this.monto,
    required this.motivo,
    required this.intentos,
    this.ultimoIntento,
  });

  factory LiberacionPendiente.desdeJson(Map<String, dynamic> json) => LiberacionPendiente(
        numero: (json['numero'] as num).toInt(),
        titulo: json['titulo'] as String? ?? 'Equipo',
        vendedor: json['vendedor'] as String? ?? '',
        monto: _dinero(json['monto']),
        motivo: MotivoLiberacion.desde(json['motivo'] as String?) ??
            MotivoLiberacion.desconocido,
        intentos: (json['intentos'] as num?)?.toInt() ?? 0,
        ultimoIntento: _fecha(json['ultimo_intento']),
      );

  final int numero;
  final String titulo;
  final String vendedor;
  final double monto;
  final MotivoLiberacion motivo;
  final int intentos;
  final DateTime? ultimoIntento;

  String get codigo => 'P-$numero';
}

/// Un descuadre que quedó registrado antes.
class DescuadreRegistrado {
  const DescuadreRegistrado({
    required this.revisadoEn,
    required this.diferenciaTotal,
    required this.pedidos,
  });

  factory DescuadreRegistrado.desdeJson(Map<String, dynamic> json) => DescuadreRegistrado(
        revisadoEn: _fecha(json['revisado_en']) ?? DateTime.now(),
        diferenciaTotal: _dinero(json['diferencia_total']),
        pedidos: (json['pedidos'] as num?)?.toInt() ?? 0,
      );

  final DateTime revisadoEn;
  final double diferenciaTotal;
  final int pedidos;
}

/// Lo que devuelve el servidor al revisar la bóveda (HU09). El cuadre lo
/// calcula el servidor; la app solo lo muestra.
class EstadoBoveda {
  const EstadoBoveda({
    required this.revisadaEn,
    required this.cuadrada,
    required this.totales,
    this.diferenciaTotal = 0,
    this.descuadres = const [],
    this.porEstado = const {},
    this.liberacionesPendientes = const [],
    this.descuadresRegistrados = const [],
  });

  factory EstadoBoveda.desdeJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> lista(String clave) =>
        ((json[clave] as List?) ?? const []).whereType<Map<String, dynamic>>().toList();
    final porEstado = <EstadoPedido, int>{};
    final crudo = (json['por_estado'] as Map?)?.cast<String, dynamic>() ?? {};
    for (final entrada in crudo.entries) {
      porEstado[EstadoPedido.desde(entrada.key)] = (entrada.value as num).toInt();
    }
    return EstadoBoveda(
      revisadaEn: _fecha(json['revisado_en']) ?? DateTime.now(),
      cuadrada: json['cuadrada'] as bool? ?? false,
      diferenciaTotal: _dinero(json['diferencia_total']),
      totales: TotalesBoveda.desdeJson((json['totales'] as Map?)?.cast<String, dynamic>()),
      descuadres: [for (final d in lista('descuadres')) Descuadre.desdeJson(d)],
      porEstado: porEstado,
      liberacionesPendientes: [
        for (final l in lista('liberaciones_pendientes')) LiberacionPendiente.desdeJson(l),
      ],
      descuadresRegistrados: [
        for (final r in lista('descuadres_registrados')) DescuadreRegistrado.desdeJson(r),
      ],
    );
  }

  final DateTime revisadaEn;
  final bool cuadrada;
  final double diferenciaTotal;
  final TotalesBoveda totales;
  final List<Descuadre> descuadres;
  final Map<EstadoPedido, int> porEstado;
  final List<LiberacionPendiente> liberacionesPendientes;
  final List<DescuadreRegistrado> descuadresRegistrados;

  /// Todavía no se ha pagado ningún pedido.
  bool get vacia => totales.totalIngresado == 0 && porEstado.isEmpty;

  int get totalPedidos => porEstado.values.fold(0, (suma, n) => suma + n);
}
