import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'avisos_service.dart';
import 'catalogo_service.dart';
import 'inspeccion_service.dart';
import 'pedido_service.dart';
import 'sesion_service.dart';

/// Actualiza la app sola cuando algo cambia en la base de datos
/// (Supabase Realtime, patrón Observer).
///
/// Escucha las tablas `equipos`, `pedidos`, `inspecciones` y `dictamenes`.
/// Cuando otra persona compra, publica, guarda un checklist o emite un
/// dictamen, avisa a los servicios y las pantallas que los escuchan se
/// vuelven a cargar, sin tener que recargar la página.
///
/// Supabase solo envía los cambios que esa persona tiene permiso de ver
/// (las mismas reglas RLS de siempre).
class TiempoRealService {
  TiempoRealService._();

  static final TiempoRealService instancia = TiempoRealService._();

  static const List<String> _tablas = [
    'equipos',
    'pedidos',
    'inspecciones',
    'dictamenes',
    // HU05 y HU10 (supabase/14_reclamos_y_avisos.sql)
    'avisos',
    'recepciones',
    'reclamos',
  ];

  SupabaseClient get _cliente => Supabase.instance.client;

  RealtimeChannel? _canal;
  Timer? _espera;
  String? _usuarioConectado;
  bool _iniciado = false;
  final Set<String> _tablasCambiadas = {};

  /// HU10, escenario 3: true cuando la conexión en vivo lleva unos
  /// segundos caída. La barra muestra «Sin conexión en vivo, reintentando…»
  /// y el aviso desaparece solo al reconectar.
  final ValueNotifier<bool> sinConexion = ValueNotifier<bool>(false);
  Timer? _esperaDesconexion;
  Timer? _reintento;

  void _alCambiarEstado(RealtimeChannel canal, RealtimeSubscribeStatus estado, Object? error) {
    if (!identical(canal, _canal)) return; // es un canal viejo
    if (error != null) debugPrint('[TiempoReal] $estado: $error');
    if (estado == RealtimeSubscribeStatus.subscribed) {
      _esperaDesconexion?.cancel();
      _esperaDesconexion = null;
      sinConexion.value = false;
      return;
    }
    // Se esperan 3 segundos antes de mostrarlo, para no asustar por un corte
    // de un instante.
    _esperaDesconexion ??= Timer(const Duration(seconds: 3), () {
      sinConexion.value = true;
    });
    // Reintenta solo cada 5 segundos hasta que vuelva.
    _reintento?.cancel();
    _reintento = Timer(const Duration(seconds: 5), _conectar);
  }

  /// Se llama una vez al arrancar la app (main.dart).
  void iniciar() {
    if (_iniciado) return;
    _iniciado = true;
    _conectar();
    // Al entrar o salir de una cuenta cambian los permisos: se reconecta
    // para recibir los cambios que le tocan a la nueva persona.
    SesionService.instancia.addListener(() {
      final usuario = _cliente.auth.currentUser?.id;
      if (usuario != _usuarioConectado) _conectar();
    });
  }

  Future<void> _conectar() async {
    final anterior = _canal;
    _canal = null;
    if (anterior != null) {
      try {
        await _cliente.removeChannel(anterior);
      } catch (_) {}
    }

    _usuarioConectado = _cliente.auth.currentUser?.id;
    var canal = _cliente.channel('reuso-seguro-cambios');
    for (final tabla in _tablas) {
      canal = canal.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: tabla,
        callback: (_) => _alCambiar(tabla),
      );
    }
    _canal = canal;
    canal.subscribe((estado, error) => _alCambiarEstado(canal, estado, error));
  }

  /// Junta varios cambios seguidos (por ejemplo, el dictamen y la
  /// liberación del pago) en una sola recarga.
  void _alCambiar(String tabla) {
    _tablasCambiadas.add(tabla);
    _espera?.cancel();
    _espera = Timer(const Duration(milliseconds: 400), () {
      final tablas = Set<String>.of(_tablasCambiadas);
      _tablasCambiadas.clear();

      if (tablas.contains('equipos')) CatalogoService.avisarCambio();
      if (tablas.contains('pedidos') || tablas.contains('dictamenes')) {
        PedidoService.instancia.avisarCambio();
      }
      if (tablas.any((t) => t != 'equipos')) {
        InspeccionService.instancia.avisarCambio();
      }
      if (tablas.contains('recepciones') || tablas.contains('reclamos')) {
        PedidoService.instancia.avisarCambio();
      }
      if (tablas.contains('avisos')) AvisosService.instancia.avisarCambio();
    });
  }
}
