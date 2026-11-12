import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/aviso.dart';
import 'sesion_service.dart';

/// HU10: los avisos de cada cambio de estado (patrón Singleton + Observer).
///
/// - Al entrar, la persona ve los avisos que le llegaron mientras no estaba
///   («Mientras no estabas…») y quedan marcados como vistos.
/// - Con la página abierta, cada aviso nuevo se muestra al momento.
/// - El administrador lee todos los avisos en el «Monitor de avisos», con
///   la hora y si el comprador y el vendedor ya los vieron.
///
/// Los avisos los crea el servidor (supabase/14_reclamos_y_avisos.sql); la
/// app solo los muestra y marca cuáles vio cada uno.
class AvisosService extends ChangeNotifier {
  AvisosService._();

  static final AvisosService instancia = AvisosService._();

  SupabaseClient get _cliente => Supabase.instance.client;

  final StreamController<String> _avisos = StreamController<String>.broadcast();

  /// Textos para mostrar en cualquier pantalla. Los muestra main.dart.
  Stream<String> get avisos => _avisos.stream;

  bool _iniciado = false;
  String? _usuario;
  bool _primeraRevision = true;
  bool _revisando = false;
  bool _otraVez = false;

  /// Se llama una vez al arrancar la app (main.dart).
  void iniciar() {
    if (_iniciado) return;
    _iniciado = true;
    SesionService.instancia.addListener(revisar);
    revisar();
  }

  /// Busca los avisos sin ver de la persona, los muestra y los marca.
  /// La llama el tiempo real cuando llega un aviso nuevo.
  Future<void> revisar() async {
    if (_revisando) {
      _otraVez = true;
      return;
    }
    _revisando = true;
    try {
      final usuario = _cliente.auth.currentUser?.id;
      if (usuario != _usuario) {
        _usuario = usuario;
        _primeraRevision = true;
      }
      if (usuario == null) return;

      final filas = await _cliente
          .from('avisos')
          .select('*, pedidos!inner(numero, comprador_id, equipos!inner(titulo, vendedor_id))')
          .or('comprador_visto_en.is.null,vendedor_visto_en.is.null')
          .order('creado_en')
          .limit(100);
      final avisos = [for (final fila in filas) Aviso.desdeFila(fila)];
      final pendientes = ReglasAvisos.pendientesDe(usuario, avisos);

      final texto = ReglasAvisos.resumen(pendientes.mensajes, alVolver: _primeraRevision);
      _primeraRevision = false;
      if (texto != null) _avisos.add(texto);
      if (pendientes.ids.isNotEmpty) {
        await _cliente.rpc('marcar_avisos_vistos', params: {'p_avisos': pendientes.ids});
      }
      notifyListeners(); // el monitor del administrador se actualiza
    } catch (error) {
      // Si falta el script 14 o no hay conexión, simplemente no se avisa.
      debugPrint('[AvisosService] revisar: $error');
    } finally {
      _revisando = false;
      if (_otraVez) {
        _otraVez = false;
        unawaited(revisar());
      }
    }
  }

  /// Lo usa el tiempo real cuando cambia la tabla de avisos.
  void avisarCambio() {
    notifyListeners();
    unawaited(revisar());
  }

  /// HU10, escenario 1: los últimos avisos de todos los pedidos (solo los
  /// puede leer el administrador, por las reglas RLS).
  Future<List<Aviso>> monitor({int limite = 50}) async {
    try {
      final filas = await _cliente
          .from('avisos')
          .select('*, pedidos(numero, comprador_id, equipos(titulo, vendedor_id))')
          .order('creado_en', ascending: false)
          .limit(limite);
      return [for (final fila in filas) Aviso.desdeFila(fila)];
    } on PostgrestException catch (error) {
      debugPrint('[AvisosService] monitor: ${error.message}');
      throw Exception(
        'No pudimos cargar los avisos. Revisa que se haya corrido '
        'supabase/14_reclamos_y_avisos.sql.',
      );
    }
  }
}
