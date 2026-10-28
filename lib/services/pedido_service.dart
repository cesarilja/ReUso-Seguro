import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/equipo.dart';
import '../models/pedido.dart';
import 'catalogo_service.dart';

/// Error con un mensaje listo para mostrarle al comprador.
class ErrorDePedido implements Exception {
  const ErrorDePedido(this.mensaje);

  final String mensaje;
}

/// Crea los pedidos, registra su pago y los lista (HU12 y HU01).
///
/// El pago es SIMULADO: no se mueve dinero real ni hay pasarela. Como pide
/// la arquitectura, el navegador no cambia estados: llama a las funciones
/// del servidor `crear_pedido`, `pagar_pedido` y `cancelar_pedido`
/// (supabase/04_pago_protegido.sql), que revisan cada regla.
///
/// Avisa cada vez que un pedido cambia (patrón Observer), para que «Mis
/// compras» se actualice sola.
class PedidoService extends ChangeNotifier {
  PedidoService._();

  static final PedidoService instancia = PedidoService._();

  SupabaseClient get _cliente => Supabase.instance.client;

  /// Lo usan otros servicios (por ejemplo, el Hub) cuando cambian un pedido.
  void avisarCambio() => notifyListeners();

  /// HU12: crea el pedido en «Pendiente de pago» (o reutiliza el que ya
  /// estaba pendiente para ese equipo).
  Future<Pedido> crearPedido(Equipo equipo) async {
    final fila = await _llamar('crear_pedido', {'p_equipo': equipo.id});
    notifyListeners();
    return Pedido.desdeFila(fila, equipo);
  }

  /// HU01: paga el pedido de forma simulada. El dinero queda en custodia
  /// y el equipo pasa a «Reservado».
  ///
  /// [simularRechazo] sirve para mostrar qué pasa cuando el pago no se
  /// verifica: el pedido sigue pendiente y no se reserva nada.
  Future<Pedido> pagar(
    Pedido pedido, {
    required MetodoPago metodo,
    bool simularRechazo = false,
  }) async {
    // Simula el tiempo que tardaría en verificarse un pago real.
    await Future<void>.delayed(const Duration(milliseconds: 1200));

    final fila = await _llamar('pagar_pedido', {
      'p_pedido': pedido.id,
      'p_metodo': metodo.clave,
      'p_simular_rechazo': simularRechazo,
    });
    CatalogoService.avisarCambio(); // el equipo ahora sale «Reservado»
    notifyListeners();
    return Pedido.desdeFila(fila, pedido.equipo);
  }

  /// Cancela un pedido que todavía no se ha pagado.
  Future<Pedido> cancelar(Pedido pedido) async {
    final fila = await _llamar('cancelar_pedido', {'p_pedido': pedido.id});
    notifyListeners();
    return Pedido.desdeFila(fila, pedido.equipo);
  }

  /// Los pedidos de la persona que inició sesión, del más nuevo al más viejo.
  Future<List<Pedido>> misPedidos() async {
    final usuario = _cliente.auth.currentUser;
    if (usuario == null) return const [];
    try {
      final filas = await _cliente
          .from('pedidos')
          .select('*, equipos(*)')
          .eq('comprador_id', usuario.id)
          .order('creado_en', ascending: false);
      return [
        for (final fila in filas)
          if (fila['equipos'] is Map<String, dynamic>)
            Pedido.desdeFila(
              fila,
              Equipo.desdeFila(
                fila['equipos'] as Map<String, dynamic>,
                CatalogoService.urlDeFoto,
              ),
            ),
      ];
    } on PostgrestException {
      throw const ErrorDePedido(
        'No pudimos cargar tus compras. Vuelve a intentarlo en un momento.',
      );
    } catch (_) {
      throw const ErrorDePedido(
        'No pudimos conectarnos. Revisa tu conexión a internet.',
      );
    }
  }

  /// El pedido ya pagado de esta persona para ese equipo, si existe.
  Future<Pedido?> compraPagada(Equipo equipo) async {
    try {
      final pedidos = await misPedidos();
      for (final pedido in pedidos) {
        if (pedido.equipo.id == equipo.id && pedido.estaPagado) return pedido;
      }
    } on ErrorDePedido {
      // Si no se puede saber, la pantalla muestra el aviso general.
    }
    return null;
  }

  Future<Map<String, dynamic>> _llamar(
    String funcion,
    Map<String, dynamic> datos,
  ) async {
    try {
      final respuesta = await _cliente.rpc(funcion, params: datos);
      if (respuesta is Map<String, dynamic>) return respuesta;
      if (respuesta is List && respuesta.isNotEmpty) {
        return respuesta.first as Map<String, dynamic>;
      }
      debugPrint('[PedidoService] $funcion respondió algo inesperado: $respuesta');
      throw const ErrorDePedido(_generico);
    } on PostgrestException catch (error) {
      // Se ve en la consola de depuración de VS Code, para diagnosticar.
      debugPrint('[PedidoService] $funcion falló: ${error.code} ${error.message}');
      if (error.code == 'PGRST202' ||
          error.message.contains('Could not find the function')) {
        throw const ErrorDePedido(
          'El servidor todavía no tiene activado el pago protegido. Falta '
          'correr supabase/04_pago_protegido.sql en Supabase.',
        );
      }
      throw _traducir(error.message);
    } on ErrorDePedido {
      rethrow;
    } catch (error) {
      debugPrint('[PedidoService] $funcion: $error');
      throw const ErrorDePedido(
        'No pudimos conectarnos. Revisa tu conexión a internet y vuelve a '
        'intentarlo. No se te cobró nada.',
      );
    }
  }

  static const String _generico =
      'No pudimos completar la operación. Vuelve a intentarlo en un momento.';

  /// El servidor responde con un código corto; aquí lo pasamos a un
  /// mensaje que dice qué pasó y qué hacer.
  ErrorDePedido _traducir(String mensaje) {
    if (mensaje.contains('RECHAZADO')) {
      return const ErrorDePedido(
        'El pago no se pudo verificar. No se te cobró nada y tu pedido sigue '
        'en «Pendiente de pago». Revisa los datos de tu método de pago o '
        'elige otro, y vuelve a intentarlo.',
      );
    }
    if (mensaje.contains('YA_COMPRADO')) {
      return const ErrorDePedido(
        'Ya compraste este equipo. Míralo en «Mis compras», en el menú de '
        'tu cuenta.',
      );
    }
    if (mensaje.contains('RESERVADO')) {
      return const ErrorDePedido(
        'Otro comprador pagó este equipo antes que tú. No se te cobró nada. '
        'Mira otros equipos en el catálogo.',
      );
    }
    if (mensaje.contains('PROPIO')) {
      return const ErrorDePedido(
        'No puedes comprar un equipo que tú publicaste.',
      );
    }
    if (mensaje.contains('CANCELADO')) {
      return const ErrorDePedido(
        'Este pedido fue cancelado. Si todavía quieres el equipo, vuelve a '
        'tocar «Comprar» desde el catálogo.',
      );
    }
    if (mensaje.contains('NO_CANCELABLE')) {
      return const ErrorDePedido(
        'Este pedido ya no se puede cancelar porque el pago está en custodia.',
      );
    }
    if (mensaje.contains('SIN_SESION')) {
      return const ErrorDePedido(
        'Tu sesión se cerró. Inicia sesión otra vez para continuar.',
      );
    }
    if (mensaje.contains('NO_EXISTE')) {
      return const ErrorDePedido(
        'No encontramos este pedido o este equipo. Vuelve al catálogo.',
      );
    }
    return const ErrorDePedido(_generico);
  }
}
