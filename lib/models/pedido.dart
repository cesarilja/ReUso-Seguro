import '../formato.dart';
import 'dictamen.dart';
import 'equipo.dart';
import 'inspeccion.dart';

/// Estados de un pedido, con los mismos nombres del Sprint Planning.
///
/// En este sprint se usan Pendiente de pago, Pago en custodia y Cancelado.
/// Los demás llegan con el Hub (HU02, HU05, HU07 y HU08), la liberación
/// (HU06) y el reembolso (HU13).
enum EstadoPedido {
  pendienteDePago('pendiente_de_pago', 'Pendiente de pago'),
  pagoEnCustodia('pago_en_custodia', 'Pago en custodia'),
  recibidoEnHub('recibido_en_hub', 'Recibido en Hub'),
  enDiagnostico('en_diagnostico', 'En diagnóstico'),
  aprobado('aprobado', 'Aprobado'),
  pagoLiberado('pago_liberado', 'Pago liberado'),
  enCamino('en_camino', 'En camino'),
  rechazado('rechazado', 'Rechazado'),
  reembolsado('reembolsado', 'Reembolsado'),
  cancelado('cancelado', 'Cancelado');

  const EstadoPedido(this.clave, this.nombre);

  /// Cómo se guarda en la base de datos.
  final String clave;

  /// Texto que se le muestra al usuario.
  final String nombre;

  static EstadoPedido desde(String? valor) => EstadoPedido.values.firstWhere(
        (estado) => estado.clave == valor,
        orElse: () => EstadoPedido.pendienteDePago,
      );
}

/// Formas de pago del MVP. Todas son SIMULADAS: no se mueve dinero real.
enum MetodoPago {
  tarjeta('tarjeta', 'Tarjeta de débito o crédito'),
  pagoMovil('pago_movil', 'Pago Móvil'),
  zelle('zelle', 'Zelle');

  const MetodoPago(this.clave, this.nombre);

  final String clave;
  final String nombre;

  static MetodoPago? desde(String? valor) {
    for (final metodo in MetodoPago.values) {
      if (metodo.clave == valor) return metodo;
    }
    return null;
  }
}

/// Un pedido: un comprador compra un solo equipo (HU12 y HU01).
class Pedido {
  const Pedido({
    required this.id,
    required this.numero,
    required this.equipo,
    required this.compradorId,
    required this.monto,
    required this.creadoEn,
    this.estado = EstadoPedido.pendienteDePago,
    this.metodo,
    this.referencia,
    this.pagadoEn,
    this.inspeccion,
    this.dictamen,
    this.comision,
    this.montoVendedor,
    this.liberadoEn,
    this.montoReembolsado,
    this.reembolsadoEn,
    this.referenciaReembolso,
    this.pagoDetalle,
    this.recibidoEn,
    this.diagnosticoEn,
  });

  /// Crea un pedido a partir de una fila de la tabla `pedidos`.
  factory Pedido.desdeFila(Map<String, dynamic> fila, Equipo equipo) {
    final pagado = fila['pagado_en'] as String?;
    final liberado = fila['liberado_en'] as String?;
    final reembolsado = fila['reembolsado_en'] as String?;
    DateTime? fecha(String columna) {
      final valor = fila[columna] as String?;
      return valor == null ? null : DateTime.parse(valor).toLocal();
    }
    return Pedido(
      id: fila['id'] as String,
      numero: (fila['numero'] as num).toInt(),
      equipo: equipo,
      compradorId: fila['comprador_id'] as String,
      monto: (fila['monto'] as num).toDouble(),
      creadoEn: DateTime.parse(fila['creado_en'] as String).toLocal(),
      estado: EstadoPedido.desde(fila['estado'] as String?),
      metodo: MetodoPago.desde(fila['metodo_pago'] as String?),
      referencia: fila['referencia'] as String?,
      pagadoEn: pagado == null ? null : DateTime.parse(pagado).toLocal(),
      inspeccion: Inspeccion.desdeRelacion(fila['inspecciones']),
      dictamen: Dictamen.desdeRelacion(fila['dictamenes']),
      comision: (fila['comision'] as num?)?.toDouble(),
      montoVendedor: (fila['monto_vendedor'] as num?)?.toDouble(),
      liberadoEn: liberado == null ? null : DateTime.parse(liberado).toLocal(),
      montoReembolsado: (fila['monto_reembolsado'] as num?)?.toDouble(),
      reembolsadoEn:
          reembolsado == null ? null : DateTime.parse(reembolsado).toLocal(),
      referenciaReembolso: fila['referencia_reembolso'] as String?,
      pagoDetalle: fila['pago_detalle'] as String?,
      recibidoEn: fecha('recibido_en'),
      diagnosticoEn: fecha('diagnostico_en'),
    );
  }

  final String id;

  /// Número corto que ve el usuario, por ejemplo 1001 (se muestra P-1001).
  final int numero;
  final Equipo equipo;
  final String compradorId;

  /// Lo que paga el comprador: el precio publicado. La comisión se le
  /// descuenta al vendedor, no al comprador (HU04).
  final double monto;
  final DateTime creadoEn;
  final EstadoPedido estado;
  final MetodoPago? metodo;

  /// Número del comprobante del pago simulado.
  final String? referencia;

  /// Con qué se pagó, sin datos sensibles: «Visa •••• 4242» o
  /// «Banesco · Ref. 123456» (ReUso Pay).
  final String? pagoDetalle;

  /// Cuándo quedó el pago en custodia. Es null mientras no se pague.
  final DateTime? pagadoEn;

  /// HU02: cuándo llegó al Hub y cuándo pasó a diagnóstico. Las anota el
  /// servidor (supabase/11_rastreo_y_certificado.sql).
  final DateTime? recibidoEn;
  final DateTime? diagnosticoEn;

  /// El checklist del Hub (HU07), si ya se hizo y la consulta lo trajo.
  final Inspeccion? inspeccion;

  /// El dictamen técnico (HU08), si ya se emitió.
  final Dictamen? dictamen;

  /// HU06: comisión de la plataforma (8 %) y lo que recibe el vendedor.
  /// Se calculan en el servidor cuando se libera el pago.
  final double? comision;
  final double? montoVendedor;

  /// Cuándo se le liberó el pago al vendedor.
  final DateTime? liberadoEn;

  /// HU13: cuánto se le devolvió al comprador, cuándo y con qué número de
  /// comprobante. Los pone el servidor cuando el equipo se rechaza.
  final double? montoReembolsado;
  final DateTime? reembolsadoEn;
  final String? referenciaReembolso;

  /// La comisión que se usará, aunque todavía no se haya liberado.
  static const double tasaComision = 0.08;

  /// El equipo no pasó la inspección (con o sin el reembolso ya hecho).
  bool get noPasoInspeccion =>
      estado == EstadoPedido.rechazado || estado == EstadoPedido.reembolsado;

  /// HU13: el reembolso ya se hizo.
  bool get fueReembolsado => estado == EstadoPedido.reembolsado;

  /// Si el equipo se rechaza no se cobra comisión (HU13).
  double get comisionEstimada => noPasoInspeccion
      ? 0.0
      : comision ?? (monto * tasaComision * 100).round() / 100;

  /// Si el equipo se rechaza el vendedor no recibe nada (HU13).
  double get recibeVendedor =>
      noPasoInspeccion ? 0.0 : montoVendedor ?? monto - comisionEstimada;

  /// HU13: lo que se le devuelve al comprador, siempre el 100 % del pago.
  double get montoADevolver => montoReembolsado ?? monto;

  bool get pagoLiberado => liberadoEn != null;

  String get codigo => 'P-$numero';

  String get montoFormateado => formatearDolares(monto);

  bool get estaPendiente => estado == EstadoPedido.pendienteDePago;

  /// Minutos para pagar un pedido (igual que en el servidor, ReUso Pay).
  static const int minutosParaPagar = 15;

  /// Hasta cuándo se puede pagar. Después el pedido vence y se cancela.
  DateTime get expiraEn => creadoEn.add(const Duration(minutes: minutosParaPagar));

  /// Cuánto tiempo queda para pagar (cero si ya venció).
  Duration tiempoRestante([DateTime? ahora]) {
    final queda = expiraEn.difference(ahora ?? DateTime.now());
    return queda.isNegative ? Duration.zero : queda;
  }

  /// Pendiente, pero se acabó el tiempo para pagar.
  bool vencido([DateTime? ahora]) =>
      estaPendiente && tiempoRestante(ahora) == Duration.zero;

  bool get estaCancelado => estado == EstadoPedido.cancelado;

  /// Ya se pagó y el dinero está retenido o siguió su camino.
  bool get estaPagado => !estaPendiente && !estaCancelado;
}
