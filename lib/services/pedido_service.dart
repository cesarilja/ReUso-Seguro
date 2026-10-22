import '../models/equipo.dart';
import '../models/pedido.dart';

/// Error con un mensaje listo para mostrarle al comprador.
class ErrorDePedido implements Exception {
  const ErrorDePedido(this.mensaje);

  final String mensaje;
}

/// Crea los pedidos de compra (HU12).
///
/// Por ahora los guarda en memoria mientras la app está abierta, igual que
/// el catálogo usa datos de prueba. Cuando se conecte la tabla de pedidos
/// en Supabase, solo cambia este archivo: las pantallas no se enteran
/// (patrón Repository).
class PedidoService {
  PedidoService._();

  static final PedidoService instancia = PedidoService._();

  final List<Pedido> _pedidos = <Pedido>[];
  int _contador = 0;

  /// Crea un pedido en "Pendiente de pago".
  ///
  /// Solo se pueden comprar equipos "Disponible". Si el comprador ya tenía
  /// un pedido pendiente de ese mismo equipo, se reutiliza.
  Pedido crearPedido({required Equipo equipo, required String compradorId}) {
    if (!equipo.estaDisponible) {
      throw const ErrorDePedido(
        'Este equipo ya no está disponible: otro comprador lo reservó.',
      );
    }

    for (final pedido in _pedidos) {
      if (pedido.compradorId == compradorId &&
          pedido.equipo.id == equipo.id &&
          pedido.estado == EstadoPedido.pendienteDePago) {
        return pedido;
      }
    }

    _contador++;
    final nuevo = Pedido(
      id: 'P-${1000 + _contador}',
      equipo: equipo,
      compradorId: compradorId,
      creadoEn: DateTime.now(),
    );
    _pedidos.add(nuevo);
    return nuevo;
  }
}
