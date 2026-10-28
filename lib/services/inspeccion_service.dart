import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/dictamen.dart';
import '../models/equipo.dart';
import '../models/inspeccion.dart';
import '../models/pedido.dart';
import 'catalogo_service.dart';
import 'pedido_service.dart';
import 'publicacion_service.dart';
import 'sesion_service.dart';

/// Un pedido que está en el Hub, con su checklist si ya existe.
class PedidoHub {
  const PedidoHub({required this.pedido, this.inspeccion});

  final Pedido pedido;
  final Inspeccion? inspeccion;
}

/// Lo que el inspector va llenando en un punto antes de guardar.
class BorradorPunto {
  BorradorPunto({
    this.resultado,
    this.nota = '',
    List<String>? guardadas,
    List<FotoElegida>? nuevas,
  })  : guardadas = guardadas ?? [],
        nuevas = nuevas ?? [];

  factory BorradorPunto.desde(RevisionPunto? revision) => BorradorPunto(
        resultado: revision?.resultado,
        nota: revision?.nota ?? '',
        guardadas: [...?revision?.evidencias],
      );

  ResultadoPunto? resultado;
  String nota;

  /// Fotos que ya estaban subidas (rutas en el almacén).
  final List<String> guardadas;

  /// Fotos que el inspector acaba de elegir y todavía no se suben.
  final List<FotoElegida> nuevas;

  int get totalFotos => guardadas.length + nuevas.length;
  bool get revisado => resultado != null;
  bool get tieneFalla => resultado == ResultadoPunto.falla;
}

/// Error con un mensaje listo para mostrarle al inspector.
class ErrorDeInspeccion implements Exception {
  const ErrorDeInspeccion(this.mensaje);

  final String mensaje;
}

/// Reglas del dictamen (HU08). El servidor revisa las mismas.
class ReglasDictamen {
  ReglasDictamen._();

  static const int minimoMotivo = 15;

  /// Qué falta en el motivo, o null si está bien.
  static String? motivo({
    required ResultadoDictamen? resultado,
    required String motivo,
    required int fallas,
  }) {
    if (resultado == null) return 'Elige si el equipo se aprueba o se rechaza.';
    final largo = motivo.trim().length;
    if (resultado == ResultadoDictamen.rechazado && largo < minimoMotivo) {
      return 'Explica por qué se rechaza (mínimo $minimoMotivo caracteres). '
          'El comprador y el vendedor lo van a leer.';
    }
    if (resultado == ResultadoDictamen.aprobado &&
        fallas > 0 &&
        largo < minimoMotivo) {
      return 'El checklist tiene ${fallas == 1 ? '1 falla' : '$fallas fallas'}: '
          'explica por qué igual se aprueba. Ejemplo: el rayón coincide con lo '
          'que declaró el vendedor.';
    }
    return null;
  }
}

/// Reglas del checklist (HU07). El servidor revisa las mismas.
class ReglasInspeccion {
  ReglasInspeccion._();

  static const int minimoNota = 10;
  static const int maximoFotosPorPunto = 4;

  /// Qué le falta a un punto, o null si está completo.
  static String? punto(BorradorPunto borrador) {
    if (!borrador.revisado) return 'Marca si funciona bien o si tiene una falla.';
    if (!borrador.tieneFalla) return null;
    if (borrador.nota.trim().length < minimoNota) {
      return 'Describe la falla (mínimo $minimoNota caracteres). '
          'Ejemplo: 3 píxeles muertos en la esquina superior.';
    }
    if (borrador.totalFotos < 1) {
      return 'Agrega al menos una foto de la falla como evidencia.';
    }
    return null;
  }
}

/// Panel del Hub e inspección técnica (HU07, «control» InspeccionService).
///
/// Solo funciona para cuentas de inspector. Las fotos de evidencia se suben
/// al almacén `evidencias`, y el checklist se guarda con la función del
/// servidor `guardar_inspeccion`, que vuelve a revisar todas las reglas.
class InspeccionService extends ChangeNotifier {
  InspeccionService._() {
    SesionService.instancia.addListener(_revisarRol);
    _revisarRol();
  }

  static final InspeccionService instancia = InspeccionService._();

  static const String _almacen = 'evidencias';
  static const List<String> _estadosDelHub = [
    'pago_en_custodia',
    'recibido_en_hub',
    'en_diagnostico',
    // Con dictamen (HU08): se muestran para consultarlos.
    'aprobado',
    'rechazado',
    'pago_liberado',
  ];

  SupabaseClient get _cliente => Supabase.instance.client;

  bool _soyInspector = false;
  String? _usuarioRevisado;

  /// Lo usa el tiempo real cuando cambia algo en el Hub.
  void avisarCambio() => notifyListeners();

  /// Si la persona que inició sesión es inspector técnico del Hub.
  bool get soyInspector => _soyInspector;

  Future<void> _revisarRol() async {
    final usuario = _cliente.auth.currentUser?.id;
    if (usuario == _usuarioRevisado) return;
    _usuarioRevisado = usuario;

    var esInspector = false;
    if (usuario != null) {
      try {
        esInspector = await _cliente.rpc('es_inspector') == true;
      } catch (_) {
        esInspector = false; // si falla, simplemente no se muestra el panel
      }
    }
    if (esInspector != _soyInspector) {
      _soyInspector = esInspector;
      notifyListeners();
    }
  }

  static String urlEvidencia(String ruta) =>
      Supabase.instance.client.storage.from(_almacen).getPublicUrl(ruta);

  /// Los pedidos pagados que están por llegar o ya están en el Hub, del más
  /// viejo al más nuevo (el primero que llegó, el primero que se revisa).
  Future<List<PedidoHub>> pedidosDelHub() async {
    try {
      final filas = await _cliente
          .from('pedidos')
          .select('*, equipos(*), inspecciones(*), dictamenes(*)')
          .inFilter('estado', _estadosDelHub)
          .order('pagado_en', ascending: true);
      return [
        for (final fila in filas)
          if (fila['equipos'] is Map<String, dynamic>)
            PedidoHub(
              pedido: Pedido.desdeFila(
                fila,
                Equipo.desdeFila(
                  fila['equipos'] as Map<String, dynamic>,
                  CatalogoService.urlDeFoto,
                ),
              ),
              inspeccion: _inspeccionDe(fila['inspecciones']),
            ),
      ];
    } on PostgrestException catch (error) {
      debugPrint('[InspeccionService] pedidosDelHub: ${error.message}');
      throw const ErrorDeInspeccion(
        'No pudimos cargar los pedidos del Hub. Vuelve a intentarlo.',
      );
    } catch (_) {
      throw const ErrorDeInspeccion(
        'No pudimos conectarnos. Revisa tu conexión a internet.',
      );
    }
  }

  /// La relación puede llegar como objeto o como lista, según Supabase.
  Inspeccion? _inspeccionDe(Object? dato) {
    if (dato is Map<String, dynamic>) return Inspeccion.desdeFila(dato);
    if (dato is List && dato.isNotEmpty && dato.first is Map<String, dynamic>) {
      return Inspeccion.desdeFila(dato.first as Map<String, dynamic>);
    }
    return null;
  }

  /// HU08: emite el dictamen técnico. Es definitivo.
  Future<void> emitirDictamen(
    Pedido pedido, {
    required ResultadoDictamen resultado,
    required String motivo,
  }) async {
    final problema = ReglasDictamen.motivo(
      resultado: resultado,
      motivo: motivo,
      fallas: pedido.inspeccion?.fallas ?? 0,
    );
    if (problema != null) throw ErrorDeInspeccion(problema);

    try {
      await _cliente.rpc('emitir_dictamen', params: {
        'p_pedido': pedido.id,
        'p_resultado': resultado.clave,
        'p_motivo': motivo.trim(),
      });
      PedidoService.instancia.avisarCambio();
      notifyListeners();
    } on PostgrestException catch (error) {
      debugPrint('[InspeccionService] dictamen: ${error.message}');
      throw _traducir(error.message, pedido.equipo.categoria);
    } catch (_) {
      throw const ErrorDeInspeccion(
        'No pudimos conectarnos. Revisa tu conexión: el dictamen no se '
        'emitió todavía, vuelve a intentarlo.',
      );
    }
  }

  /// Registra que el vendedor entregó el equipo en el Hub.
  Future<void> recibirEnHub(Pedido pedido) async {
    try {
      await _cliente.rpc('recibir_en_hub', params: {'p_pedido': pedido.id});
      PedidoService.instancia.avisarCambio();
      notifyListeners();
    } on PostgrestException catch (error) {
      throw _traducir(error.message, pedido.equipo.categoria);
    } catch (_) {
      throw const ErrorDeInspeccion(
        'No pudimos conectarnos. Revisa tu conexión y vuelve a intentarlo.',
      );
    }
  }

  /// HU07: sube las fotos nuevas y guarda el checklist completo.
  Future<void> guardar(
    Pedido pedido,
    Map<String, BorradorPunto> borradores,
  ) async {
    final categoria = pedido.equipo.categoria;
    final checklist = PuntoChecklist.para(categoria);
    for (final punto in checklist) {
      if (borradores[punto.clave]?.resultado == ResultadoPunto.noAplica &&
          !punto.opcional) {
        throw ErrorDeInspeccion('${punto.nombre}: este punto sí se revisa.');
      }
      final problema = ReglasInspeccion.punto(
        borradores[punto.clave] ?? BorradorPunto(),
      );
      if (problema != null) {
        throw ErrorDeInspeccion('${punto.nombre}: $problema');
      }
    }

    final subidas = <String>[];
    try {
      final puntos = <String, dynamic>{};
      final marca = DateTime.now().millisecondsSinceEpoch;

      for (final punto in checklist) {
        final borrador = borradores[punto.clave]!;
        final evidencias = <String>[];
        if (borrador.tieneFalla) {
          evidencias.addAll(borrador.guardadas);
          for (var i = 0; i < borrador.nuevas.length; i++) {
            final foto = borrador.nuevas[i];
            final ruta =
                '${pedido.id}/${punto.clave}-$marca-${i + 1}.${foto.extension}';
            await _cliente.storage.from(_almacen).uploadBinary(
                  ruta,
                  foto.bytes,
                  fileOptions: FileOptions(contentType: foto.tipo),
                );
            subidas.add(ruta);
            evidencias.add(ruta);
          }
        }
        puntos[punto.clave] = RevisionPunto(
          resultado: borrador.resultado,
          nota: borrador.nota,
          evidencias: evidencias,
        ).aJson();
      }

      await _cliente.rpc('guardar_inspeccion', params: {
        'p_pedido': pedido.id,
        'p_puntos': puntos,
      });
      PedidoService.instancia.avisarCambio();
      notifyListeners();
    } on StorageException catch (error) {
      debugPrint('[InspeccionService] fotos: ${error.message}');
      await _borrar(subidas);
      throw const ErrorDeInspeccion(
        'No pudimos subir las fotos de evidencia. Revisa que sean JPG, PNG o '
        'WEBP de hasta 5 MB y vuelve a intentarlo. No se guardó nada.',
      );
    } on PostgrestException catch (error) {
      debugPrint('[InspeccionService] guardar: ${error.message}');
      await _borrar(subidas);
      throw _traducir(error.message, categoria);
    } catch (error) {
      debugPrint('[InspeccionService] guardar: $error');
      await _borrar(subidas);
      throw const ErrorDeInspeccion(
        'No pudimos conectarnos. Revisa tu conexión: el checklist sigue en '
        'pantalla, vuelve a tocar «Guardar».',
      );
    }
  }

  Future<void> _borrar(List<String> rutas) async {
    if (rutas.isEmpty) return;
    try {
      await _cliente.storage.from(_almacen).remove(rutas);
    } catch (_) {}
  }

  ErrorDeInspeccion _traducir(String mensaje, String? categoria) {
    String nombreDe(String codigo) {
      if (!mensaje.contains(':')) return codigo;
      final clave = mensaje.split(':').last.trim();
      return PuntoChecklist.nombreDe(clave, categoria);
    }

    if (mensaje.contains('NO_INSPECTOR')) {
      return const ErrorDeInspeccion(
        'Tu cuenta no es de inspector técnico. Pide acceso al administrador.',
      );
    }
    if (mensaje.contains('FALTA_MOTIVO')) {
      return const ErrorDeInspeccion(
        'Explica por qué se rechaza el equipo (mínimo 15 caracteres).',
      );
    }
    if (mensaje.contains('FALTA_JUSTIFICACION')) {
      return const ErrorDeInspeccion(
        'El checklist tiene fallas: explica por qué igual se aprueba '
        '(mínimo 15 caracteres).',
      );
    }
    if (mensaje.contains('YA_EMITIDO')) {
      return const ErrorDeInspeccion(
        'Este pedido ya tiene dictamen. Los dictámenes no se pueden cambiar.',
      );
    }
    if (mensaje.contains('SIN_CHECKLIST')) {
      return const ErrorDeInspeccion(
        'Primero guarda el checklist completo de este equipo.',
      );
    }
    if (mensaje.contains('NO_APLICA')) {
      return ErrorDeInspeccion(
        '${nombreDe('Un punto')}: este punto sí se revisa en este equipo.',
      );
    }
    if (mensaje.contains('INCOMPLETO')) {
      return ErrorDeInspeccion(
        '${nombreDe('Un punto')}: falta marcar si funciona bien o tiene falla.',
      );
    }
    if (mensaje.contains('FALTA_NOTA')) {
      return ErrorDeInspeccion('${nombreDe('Un punto')}: describe la falla.');
    }
    if (mensaje.contains('FALTA_EVIDENCIA')) {
      return ErrorDeInspeccion(
        '${nombreDe('Un punto')}: agrega una foto de la falla.',
      );
    }
    if (mensaje.contains('ESTADO')) {
      return const ErrorDeInspeccion(
        'Este pedido cambió de estado mientras trabajabas. Vuelve al panel '
        'para ver cómo quedó.',
      );
    }
    return const ErrorDeInspeccion(
      'No pudimos guardar el checklist. Vuelve a intentarlo en un momento.',
    );
  }
}
