import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/reputacion.dart';

/// Reputación de los vendedores (HU20, «control» ReputacionService).
///
/// La calcula el servidor (`reputacion_vendedor` y `reputaciones_vendedores`
/// en supabase/16_reputacion.sql). Aquí se guarda en memoria para que el
/// catálogo la pida una sola vez y no una por tarjeta. Patrón Singleton y
/// Observer: las tarjetas se redibujan cuando llega.
class ReputacionService extends ChangeNotifier {
  ReputacionService._();

  static final ReputacionService instancia = ReputacionService._();

  /// Cada cuánto se vuelve a pedir la lista completa.
  static const Duration _vigencia = Duration(minutes: 2);

  SupabaseClient get _cliente => Supabase.instance.client;

  final Map<String, Reputacion> _porVendedor = {};
  DateTime? _cargadaEn;
  bool _cargando = false;

  /// La reputación de un vendedor, si ya se cargó. Los equipos de
  /// demostración no tienen vendedor y responden null.
  Reputacion? de(String? vendedorId) =>
      vendedorId == null ? null : _porVendedor[vendedorId];

  /// Pide la reputación de todos los vendedores. Si falla, el catálogo se
  /// sigue viendo igual, solo que sin sellos.
  Future<void> cargar({bool forzar = false}) async {
    final reciente = _cargadaEn != null &&
        DateTime.now().difference(_cargadaEn!) < _vigencia;
    if (_cargando || (reciente && !forzar)) return;
    _cargando = true;
    try {
      final respuesta = await _cliente.rpc('reputaciones_vendedores');
      if (respuesta is List) {
        for (final dato in respuesta) {
          if (dato is Map) {
            final reputacion =
                Reputacion.desdeJson(dato.cast<String, dynamic>());
            _porVendedor[reputacion.vendedorId] = reputacion;
          }
        }
      }
      _cargadaEn = DateTime.now();
      notifyListeners();
    } catch (error) {
      debugPrint('[ReputacionService] cargar: $error');
    } finally {
      _cargando = false;
    }
  }

  /// La reputación de un vendedor, pedida al servidor en ese momento.
  Future<Reputacion?> deVendedor(String vendedorId) async {
    try {
      final respuesta = await _cliente.rpc(
        'reputacion_vendedor',
        params: {'p_vendedor': vendedorId},
      );
      if (respuesta is Map) {
        final reputacion = Reputacion.desdeJson(respuesta.cast<String, dynamic>());
        _porVendedor[vendedorId] = reputacion;
        notifyListeners();
        return reputacion;
      }
    } catch (error) {
      debugPrint('[ReputacionService] deVendedor: $error');
    }
    return null;
  }

  /// La reputación de quien inició sesión (para Mis ventas y Publicar).
  Future<Reputacion?> mia() async {
    try {
      final usuario = _cliente.auth.currentUser?.id;
      if (usuario == null) return null;
      return await deVendedor(usuario);
    } catch (error) {
      debugPrint('[ReputacionService] mia: $error');
      return null;
    }
  }
}
