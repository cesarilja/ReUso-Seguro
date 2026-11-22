import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/equipo.dart';
import '../models/inspeccion.dart';
import '../models/plan_inspeccion.dart';
import 'catalogo_service.dart';
import 'sesion_service.dart';

/// Una foto que el vendedor eligió en su computadora o teléfono.
class FotoElegida {
  const FotoElegida({
    required this.bytes,
    required this.nombre,
    required this.tipo,
  });

  final Uint8List bytes;

  /// Nombre original del archivo, por ejemplo: laptop.jpg
  final String nombre;

  /// Tipo de imagen: image/jpeg, image/png o image/webp.
  final String tipo;

  String get extension => switch (tipo) {
        'image/png' => 'png',
        'image/webp' => 'webp',
        _ => 'jpg',
      };
}

/// Los datos que el vendedor llena en el formulario.
class NuevaPublicacion {
  const NuevaPublicacion({
    required this.titulo,
    required this.categoria,
    required this.precio,
    required this.condicion,
    required this.detallesEstado,
    required this.descripcion,
    required this.fotos,
    this.plan = PlanInspeccion.basica,
    this.express = false,
    this.autoevaluacion = const {},
  });

  final String titulo;
  final String categoria;
  final String precio;
  final String condicion;
  final String detallesEstado;
  final String descripcion;
  final List<FotoElegida> fotos;

  /// HU16: plan de inspección que paga el vendedor y si la quiere Express.
  final PlanInspeccion plan;
  final bool express;

  /// HU19: cómo califica el vendedor cada punto del checklist (1 a 4).
  /// Un punto opcional sin nota es que su equipo no lo tiene.
  final Map<String, int> autoevaluacion;
}

/// Error con un mensaje listo para mostrarle al vendedor.
class ErrorDePublicacion implements Exception {
  const ErrorDePublicacion(this.mensaje);

  final String mensaje;
}

/// Reglas del formulario de publicación (HU11).
///
/// Todos los datos son obligatorios. Cada función responde `null` si el dato
/// está bien, o un mensaje que dice exactamente qué corregir. La base de
/// datos revisa las mismas reglas (supabase/03_publicar.sql).
class ReglasPublicacion {
  ReglasPublicacion._();

  static const int minimoFotos = 3;
  static const int maximoFotos = 6;
  static const int maximoBytesFoto = 5 * 1024 * 1024;
  static const double precioMaximo = 10000;
  static const int minimoDescripcion = 30;
  static const int maximoDescripcion = 1000;

  static const List<String> categorias = [
    'Laptop',
    'Teléfono',
    'Tablet',
    'Consola',
    'Audio',
    'Otro',
  ];

  static const List<String> condiciones = [
    'Nuevo, sin usar',
    'Como nuevo',
    'Usado, en buen estado',
    'Usado, con detalles visibles',
  ];

  static const List<String> tiposPermitidos = [
    'image/jpeg',
    'image/png',
    'image/webp',
  ];

  static String? titulo(String? valor) {
    final texto = (valor ?? '').trim();
    if (texto.isEmpty) {
      return 'Escribe qué equipo vendes. Ejemplo: Laptop Lenovo ThinkPad T480';
    }
    if (texto.length < 5) {
      return 'El título es muy corto. Incluye la marca y el modelo.';
    }
    if (texto.length > 80) {
      return 'El título puede tener hasta 80 caracteres (tiene ${texto.length}).';
    }
    return null;
  }

  static String? categoria(String? valor) =>
      valor == null ? 'Elige qué tipo de equipo es.' : null;

  static String? condicion(String? valor) =>
      valor == null ? 'Elige en qué condición está el equipo.' : null;

  static String? detallesEstado(String? valor) {
    final texto = (valor ?? '').trim();
    if (texto.isEmpty) {
      return 'Cuenta cómo está el equipo. Ejemplo: la batería dura 3 horas '
          'y tiene un rayón leve en la tapa.';
    }
    if (texto.length < 10) {
      return 'Da un poco más de detalle: batería, pantalla, golpes o rayones.';
    }
    if (texto.length > 200) {
      return 'Resume los detalles en 200 caracteres o menos.';
    }
    return null;
  }

  static String? descripcion(String? valor) {
    final texto = (valor ?? '').trim();
    if (texto.isEmpty) {
      return 'Describe el equipo: características, accesorios incluidos y '
          'por qué lo vendes.';
    }
    if (texto.length < minimoDescripcion) {
      final faltan = minimoDescripcion - texto.length;
      return 'Escribe al menos $minimoDescripcion caracteres '
          '(te faltan $faltan). Incluye características y accesorios.';
    }
    if (texto.length > maximoDescripcion) {
      return 'La descripción puede tener hasta $maximoDescripcion caracteres.';
    }
    return null;
  }

  /// Convierte lo que escribió el vendedor ("180", "180,50") en un número.
  static double? leerPrecio(String? valor) {
    final texto = (valor ?? '').trim().replaceAll(',', '.');
    if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(texto)) return null;
    return double.tryParse(texto);
  }

  static String? precio(String? valor) {
    final texto = (valor ?? '').trim();
    if (texto.isEmpty) return 'Escribe el precio en dólares. Ejemplo: 180';
    final numero = leerPrecio(texto);
    if (numero == null) {
      return 'Escribe solo números, con hasta 2 decimales. Ejemplo: 180,50';
    }
    if (numero < 1) return 'El precio debe ser de al menos \$1.';
    if (numero > precioMaximo) {
      return 'El precio no puede pasar de \$10.000.';
    }
    return null;
  }

  static String? fotos(List<FotoElegida> fotos) {
    if (fotos.length < minimoFotos) {
      final faltan = minimoFotos - fotos.length;
      return 'Agrega al menos $minimoFotos fotos del equipo '
          '(te ${faltan == 1 ? 'falta 1' : 'faltan $faltan'}).';
    }
    if (fotos.length > maximoFotos) {
      return 'Puedes subir hasta $maximoFotos fotos.';
    }
    return null;
  }

  /// Revisa una foto antes de agregarla. Responde por qué no sirve, o null.
  static String? foto(FotoElegida foto) {
    if (!tiposPermitidos.contains(foto.tipo)) {
      return '«${foto.nombre}» no es una foto válida. Usa JPG, PNG o WEBP.';
    }
    if (foto.bytes.lengthInBytes > maximoBytesFoto) {
      return '«${foto.nombre}» pesa más de 5 MB. Elige una foto más liviana.';
    }
    return null;
  }

  /// HU19: qué falta en la autoevaluación, o null si está completa.
  /// Todos los puntos del checklist llevan nota del 1 al 4, salvo los
  /// opcionales (cámaras, lectora, micrófono).
  static String? autoevaluacion(String? categoria, Map<String, int> notas) {
    if (categoria == null) return 'Elige primero qué tipo de equipo es.';
    final faltan = [
      for (final punto in PuntoChecklist.para(categoria))
        if (!punto.opcional && notas[punto.clave] == null) punto.nombre,
    ];
    if (faltan.isNotEmpty) {
      return 'Califica del 1 al 4 cómo está: ${faltan.join(', ')}.';
    }
    final validas = {for (final p in PuntoChecklist.para(categoria)) p.clave};
    for (final entrada in notas.entries) {
      if (!validas.contains(entrada.key) ||
          entrada.value < 1 ||
          entrada.value > 4) {
        return 'Vuelve a calificar los puntos de tu equipo del 1 al 4.';
      }
    }
    return null;
  }

  /// Solo se guardan los puntos del checklist de ese tipo de equipo (si
  /// el vendedor cambió de tipo, las notas viejas se descartan).
  static Map<String, int> autoevaluacionLimpia(
    String categoria,
    Map<String, int> notas,
  ) {
    final validas = {for (final p in PuntoChecklist.para(categoria)) p.clave};
    return {
      for (final entrada in notas.entries)
        if (validas.contains(entrada.key)) entrada.key: entrada.value,
    };
  }

  /// El texto que se guarda como estado declarado.
  static String estadoDeclarado(String condicion, String detalles) {
    final limpio = detalles.trim();
    final conPunto = RegExp(r'[.!?]$').hasMatch(limpio) ? limpio : '$limpio.';
    return '$condicion. ${conPunto[0].toUpperCase()}${conPunto.substring(1)}';
  }
}

/// Publica equipos en el catálogo (HU11, «control» PublicacionService).
///
/// Sube las fotos a Supabase Storage, cada una dentro de la carpeta del
/// vendedor, y luego guarda el equipo en la tabla `equipos` con la ruta de
/// cada foto. Si algo falla a mitad de camino, borra las fotos subidas para
/// no dejar archivos sueltos.
class PublicacionService {
  const PublicacionService();

  static const String _tabla = 'equipos';
  static const String _almacen = 'equipos';

  SupabaseClient get _cliente => Supabase.instance.client;

  Future<Equipo> publicar(NuevaPublicacion datos) async {
    final usuario = SesionService.instancia.usuario;
    if (usuario == null) {
      throw const ErrorDePublicacion(
        'Tu sesión se cerró. Inicia sesión otra vez para publicar.',
      );
    }

    // Las mismas reglas del formulario, por si acaso.
    final errores = [
      ReglasPublicacion.titulo(datos.titulo),
      ReglasPublicacion.categoria(datos.categoria),
      ReglasPublicacion.precio(datos.precio),
      ReglasPublicacion.condicion(datos.condicion),
      ReglasPublicacion.detallesEstado(datos.detallesEstado),
      ReglasPublicacion.descripcion(datos.descripcion),
      ReglasPublicacion.fotos(datos.fotos),
      ...datos.fotos.map(ReglasPublicacion.foto),
      ReglasPublicacion.autoevaluacion(
        datos.categoria,
        ReglasPublicacion.autoevaluacionLimpia(
          datos.categoria,
          datos.autoevaluacion,
        ),
      ),
    ].whereType<String>();
    if (errores.isNotEmpty) throw ErrorDePublicacion(errores.first);

    // Carpeta de esta publicación: <id del vendedor>/<marca de tiempo>/
    final carpeta = '${usuario.id}/${DateTime.now().millisecondsSinceEpoch}';
    final rutas = <String>[];

    try {
      for (var i = 0; i < datos.fotos.length; i++) {
        final foto = datos.fotos[i];
        final ruta = '$carpeta/${i + 1}.${foto.extension}';
        await _cliente.storage.from(_almacen).uploadBinary(
              ruta,
              foto.bytes,
              fileOptions: FileOptions(contentType: foto.tipo),
            );
        rutas.add(ruta);
      }

      final fila = await _cliente
          .from(_tabla)
          .insert({
            'vendedor_id': usuario.id,
            'vendedor_nombre': usuario.nombre,
            'titulo': datos.titulo.trim(),
            'categoria': datos.categoria,
            'descripcion': datos.descripcion.trim(),
            'estado_declarado': ReglasPublicacion.estadoDeclarado(
              datos.condicion,
              datos.detallesEstado,
            ),
            'precio': ReglasPublicacion.leerPrecio(datos.precio),
            'fotos': rutas,
            'plan_inspeccion': datos.plan.clave,
            'express': datos.express,
            'autoevaluacion': ReglasPublicacion.autoevaluacionLimpia(
              datos.categoria,
              datos.autoevaluacion,
            ),
          })
          .select()
          .single();

      CatalogoService.avisarCambio();
      return Equipo.desdeFila(fila, CatalogoService.urlDeFoto);
    } on StorageException catch (error) {
      await _borrar(rutas);
      throw _traducirFoto(error.message);
    } on PostgrestException {
      await _borrar(rutas);
      throw const ErrorDePublicacion(
        'No pudimos guardar tu equipo. Revisa que todos los datos estén '
        'completos y vuelve a intentarlo.',
      );
    } catch (_) {
      await _borrar(rutas);
      throw const ErrorDePublicacion(
        'No pudimos conectarnos. Revisa tu conexión a internet y vuelve a '
        'intentarlo. No se publicó nada.',
      );
    }
  }

  Future<void> _borrar(List<String> rutas) async {
    if (rutas.isEmpty) return;
    try {
      await _cliente.storage.from(_almacen).remove(rutas);
    } catch (_) {
      // Si tampoco se pueden borrar, quedan en la carpeta del vendedor.
    }
  }

  ErrorDePublicacion _traducirFoto(String original) {
    final texto = original.toLowerCase();
    if (texto.contains('size') || texto.contains('too large')) {
      return const ErrorDePublicacion(
        'Una de las fotos pesa más de 5 MB. Cámbiala por una más liviana.',
      );
    }
    if (texto.contains('mime') || texto.contains('type')) {
      return const ErrorDePublicacion(
        'Una de las fotos no es JPG, PNG ni WEBP. Cámbiala e intenta de nuevo.',
      );
    }
    return const ErrorDePublicacion(
      'No pudimos subir las fotos. Revisa tu conexión y vuelve a intentarlo. '
      'No se publicó nada.',
    );
  }
}
