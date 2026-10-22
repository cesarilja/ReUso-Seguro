import 'equipo.dart';

/// Estados de un pedido, con los mismos nombres del Sprint Planning.
///
/// En el Sprint 1 solo se usa "Pendiente de pago" (HU12). Los demás llegan
/// con el pago protegido (HU01), el Hub (HU02, HU05 y HU08), la liberación
/// (HU06) y el reembolso (HU13).
enum EstadoPedido {
  pendienteDePago('Pendiente de pago'),
  pagoEnCustodia('Pago en custodia'),
  recibidoEnHub('Recibido en Hub'),
  enDiagnostico('En diagnóstico'),
  aprobado('Aprobado'),
  pagoLiberado('Pago liberado'),
  enCamino('En camino'),
  rechazado('Rechazado'),
  reembolsado('Reembolsado');

  const EstadoPedido(this.nombre);

  /// Texto que se le muestra al usuario.
  final String nombre;
}

/// Un pedido: un comprador compra un solo equipo (HU12).
class Pedido {
  const Pedido({
    required this.id,
    required this.equipo,
    required this.compradorId,
    required this.creadoEn,
    this.estado = EstadoPedido.pendienteDePago,
  });

  final String id;
  final Equipo equipo;
  final String compradorId;
  final DateTime creadoEn;
  final EstadoPedido estado;
}
