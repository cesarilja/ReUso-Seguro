import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/equipo.dart';
import '../models/pedido.dart';
import 'catalogo_service.dart';
import 'pasarela.dart';

/// Error con un mensaje listo para mostrarle al comprador.
class ErrorDePedido implements Exception {
  const ErrorDePedido(this.mensaje);

  final String mensaje;
}

/// Lo que respondió ReUso Pay a un intento de pago.
class ResultadoPago {
  const ResultadoPago({
    required this.respuesta,
    required this.pedido,
    this.intentosRestantes = 0,
  });

  final RespuestaBanco respuesta;

  /// El pedido como quedó después del intento.
  final Pedido pedido;

  /// Cuántos intentos rechazados más se permiten antes de cancelarlo.
  final int intentosRestantes;

  bool get aprobado => respuesta == RespuestaBanco.aprobado;
}

/// Crea los pedidos, registra su pago y los lista (HU12 y HU01).
///
/// El pago es SIMULADO: no se mueve dinero real. Como pide la arquitectura,
/// el navegador no cambia estados: llama a las funciones del servidor
/// `crear_pedido`, `procesar_pago` (ReUso Pay, supabase/10) y
/// `cancelar_pedido` (supabase/04), que revisan cada regla.
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

  /// HU01 con ReUso Pay: envía los datos del pago al servidor, que hace
  /// de banco y responde si lo aprueba o lo rechaza (y por qué).
  ///
  /// Si se aprueba, el dinero queda en custodia y el equipo pasa a
  /// «Reservado». Si se rechaza, no se cobra nada. Todo es SIMULADO.
  Future<ResultadoPago> pagar(
    Pedido pedido, {
    required MetodoPago metodo,
    required Map<String, dynamic> datos,
  }) async {
    final inicio = DateTime.now();
    final respuesta = await _llamar('procesar_pago', {
      'p_pedido': pedido.id,
      'p_metodo': metodo.clave,
      'p_datos': datos,
    });
    // Un banco real tarda unos segundos; así se ven los pasos del proceso.
    final espera = const Duration(milliseconds: 2400) -
        DateTime.now().difference(inicio);
    if (!espera.isNegative) await Future<void>.delayed(espera);

    final fila = respuesta['pedido'];
    final actualizado = fila is Map<String, dynamic>
        ? Pedido.desdeFila(fila, pedido.equipo)
        : pedido;
    final resultado = ResultadoPago(
      respuesta: RespuestaBanco.desde(respuesta['codigo'] as String?),
      pedido: actualizado,
      intentosRestantes: (respuesta['intentos_restantes'] as num?)?.toInt() ?? 0,
    );
    if (resultado.aprobado || !actualizado.estaPendiente) {
      CatalogoService.avisarCambio(); // el equipo ahora sale «Reservado»
      notifyListeners();
    }
    return resultado;
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
          .select('*, equipos(*), inspecciones(*), dictamenes(*)')
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

  /// HU06: las ventas de la persona que inició sesión (pedidos pagados de
  /// los equipos que publicó), de la más nueva a la más vieja.
  Future<List<Pedido>> misVentas() async {
    final usuario = _cliente.auth.currentUser;
    if (usuario == null) return const [];
    try {
      final filas = await _cliente
          .from('pedidos')
          .select('*, equipos!inner(*), inspecciones(*), dictamenes(*)')
          .eq('equipos.vendedor_id', usuario.id)
          .order('pagado_en', ascending: false);
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
      ].where((pedido) => pedido.estaPagado).toList(growable: false);
    } on PostgrestException catch (error) {
      debugPrint('[PedidoService] misVentas: ${error.message}');
      throw const ErrorDePedido(
        'No pudimos cargar tus ventas. Vuelve a intentarlo en un momento.',
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
        throw ErrorDePedido(
          funcion == 'procesar_pago'
              ? 'El servidor todavía no tiene activado ReUso Pay. Falta '
                  'correr supabase/10_pasarela_simulada.sql en Supabase.'
              : 'El servidor todavía no tiene activado el pago protegido. '
                  'Falta correr supabase/04_pago_protegido.sql en Supabase.',
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
