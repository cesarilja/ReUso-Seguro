import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/pedido.dart';
import '../models/venta.dart';
import 'pedido_service.dart';
import 'sesion_service.dart';

/// Todo lo del vendedor después de vender (HU04 y HU06), patrón Singleton.
///
/// - Cuenta las ventas nuevas para la insignia de «Mis ventas» y avisa en
///   vivo cuando le compran, cuando se libera su pago o cuando la
///   transferencia falla (patrón Observer: escucha a PedidoService, que a
///   su vez escucha Supabase Realtime).
/// - Llama a las funciones del servidor: marcar_entregado,
///   marcar_ventas_vistas, guardar_cuenta_cobro y reintentar_liberacion
///   (supabase/12_vendedor_y_liberacion.sql). El navegador no decide nada.
class VendedorService extends ChangeNotifier {
  VendedorService._();

  static final VendedorService instancia = VendedorService._();

  SupabaseClient get _cliente => Supabase.instance.client;

  bool _iniciado = false;
  int _ventasNuevas = 0;
  Map<String, EstadoPedido>? _estadosAnteriores;
  String? _usuario;

  /// Número de la insignia de «Mis ventas» en la barra.
  int get ventasNuevas => _ventasNuevas;

  final StreamController<String> _avisos = StreamController<String>.broadcast();

  /// Avisos para mostrar en cualquier pantalla («Te compraron…»). Los
  /// muestra main.dart; el servicio no sabe de pantallas.
  Stream<String> get avisos => _avisos.stream;

  /// Se llama una vez al arrancar la app (main.dart).
  void iniciar() {
    if (_iniciado) return;
    _iniciado = true;
    PedidoService.instancia.addListener(_revisar);
    SesionService.instancia.addListener(_revisar);
    _revisar();
  }

  /// Vuelve a mirar las ventas: actualiza la insignia y avisa los cambios.
  Future<void> _revisar() async {
    final usuario = _cliente.auth.currentUser?.id;
    if (usuario != _usuario) {
      // Otra cuenta: se empieza de cero, sin avisos viejos.
      _usuario = usuario;
      _estadosAnteriores = null;
    }
    if (usuario == null) {
      _cambiarNuevas(0);
      return;
    }
    try {
      final ventas = await PedidoService.instancia.misVentas();
      if (_cliente.auth.currentUser?.id != usuario) return;
      for (final aviso in ReglasVenta.avisosDeCambio(_estadosAnteriores, ventas)) {
        _avisos.add(aviso);
      }
      _estadosAnteriores = {for (final v in ventas) v.id: v.estado};
      _cambiarNuevas(ReglasVenta.contarNuevas(ventas));
    } catch (error) {
      debugPrint('[VendedorService] No se pudieron revisar las ventas: $error');
    }
  }

  void _cambiarNuevas(int cantidad) {
    if (cantidad == _ventasNuevas) return;
    _ventasNuevas = cantidad;
    notifyListeners();
  }

  /// HU04: el vendedor abrió «Mis ventas», así que ya no son nuevas.
  Future<void> marcarVentasVistas() async {
    if (_ventasNuevas == 0) return;
    try {
      await _cliente.rpc('marcar_ventas_vistas');
      _cambiarNuevas(0);
    } catch (error) {
      debugPrint('[VendedorService] marcar_ventas_vistas: $error');
    }
  }

  /// HU04: «Ya entregué el equipo».
  Future<Pedido> marcarEntregado(Pedido venta) async {
    final fila = await _llamar('marcar_entregado', {'p_pedido': venta.id});
    PedidoService.instancia.avisarCambio();
    return Pedido.desdeFila(fila, venta.equipo);
  }

  /// HU06: pide otra vez la transferencia de una liberación pendiente.
  Future<Pedido> reintentarLiberacion(Pedido venta) async {
    final fila = await _llamar('reintentar_liberacion', {'p_pedido': venta.id});
    PedidoService.instancia.avisarCambio();
    return Pedido.desdeFila(fila, venta.equipo);
  }

  /// HU06: la cuenta de cobro del vendedor, o null si no tiene.
  Future<CuentaCobro?> miCuenta() async {
    final usuario = _cliente.auth.currentUser?.id;
    if (usuario == null) return null;
    try {
      final fila = await _cliente
          .from('cuentas_cobro')
          .select()
          .eq('vendedor_id', usuario)
          .maybeSingle();
      return fila == null ? null : CuentaCobro.desdeFila(fila);
    } catch (error) {
      debugPrint('[VendedorService] miCuenta: $error');
      throw const ErrorDePedido('No pudimos cargar tu cuenta para cobrar.');
    }
  }

  /// HU06: guarda la cuenta y responde cuántas liberaciones pendientes se
  /// pudieron completar al reintentarlas.
  Future<int> guardarCuenta({
    required String banco,
    required String telefono,
    required String cedula,
    required String titular,
  }) async {
    final respuesta = await _llamar('guardar_cuenta_cobro', {
      'p_banco': banco,
      'p_telefono': telefono,
      'p_cedula': cedula,
      'p_titular': titular,
    });
    PedidoService.instancia.avisarCambio();
    return (respuesta['liberados'] as num?)?.toInt() ?? 0;
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
      throw const ErrorDePedido(_generico);
    } on PostgrestException catch (error) {
      debugPrint('[VendedorService] $funcion: ${error.code} ${error.message}');
      if (error.code == 'PGRST202' ||
          error.message.contains('Could not find the function')) {
        throw const ErrorDePedido(
          'Falta activar esta función en el servidor: corre '
          'supabase/12_vendedor_y_liberacion.sql en Supabase.',
        );
      }
      throw ErrorDePedido(_traducir(error.message));
    } on ErrorDePedido {
      rethrow;
    } catch (error) {
      debugPrint('[VendedorService] $funcion: $error');
      throw const ErrorDePedido(
        'No pudimos conectarnos. Revisa tu conexión a internet.',
      );
    }
  }

  static const String _generico =
      'No pudimos completar la operación. Vuelve a intentarlo en un momento.';

  static String _traducir(String mensaje) {
    if (mensaje.contains('NO_VENDEDOR')) {
      return 'Solo el vendedor de este equipo puede hacer esto.';
    }
    if (mensaje.contains('ESTADO')) {
      return 'Esta venta cambió de estado. Actualiza la página.';
    }
    if (mensaje.contains('TELEFONO')) {
      return 'Escribe un teléfono móvil completo, por ejemplo 0414 123 4567.';
    }
    if (mensaje.contains('CEDULA')) {
      return 'Escribe la cédula con la letra, por ejemplo V12345678.';
    }
    if (mensaje.contains('TITULAR')) {
      return 'Escribe el nombre y el apellido del titular de la cuenta.';
    }
    if (mensaje.contains('FALTA_BANCO')) return 'Elige tu banco.';
    if (mensaje.contains('SIN_SESION')) {
      return 'Tu sesión se cerró. Inicia sesión otra vez.';
    }
    return _generico;
  }
}
