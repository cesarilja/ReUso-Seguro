/// Un punto que el inspector técnico revisa en un equipo (HU07).
///
/// Cada tipo de equipo tiene su propio checklist: unos audífonos no tienen
/// pantalla, y una consola necesita probar los controles y la lectora.
class PuntoChecklist {
  const PuntoChecklist(
    this.clave,
    this.nombre,
    this.queRevisar, {
    this.opcional = false,
  });

  /// Cómo se guarda en la base de datos (igual que en 05_inspeccion.sql).
  final String clave;
  final String nombre;

  /// Ayuda corta para que el inspector no tenga que recordar el protocolo.
  final String queRevisar;

  /// Si se puede marcar «No aplica» (por ejemplo, la lectora de una consola
  /// que no tiene lectora).
  final bool opcional;

  static const _encendido = PuntoChecklist(
    'encendido',
    'Encendido',
    'Enciende, arranca el sistema y no se apaga solo.',
  );
  static const _bateria = PuntoChecklist(
    'bateria',
    'Batería',
    'Carga, mantiene la carga y no está inflada.',
  );
  static const _pantallaTactil = PuntoChecklist(
    'pantalla_tactil',
    'Pantalla táctil',
    'Sin manchas ni grietas; el toque responde en toda la pantalla.',
  );
  static const _camaras = PuntoChecklist(
    'camaras',
    'Cámaras',
    'Enfocan y toman fotos con la cámara delantera y la trasera.',
    opcional: true,
  );
  static const _botonesYCarga = PuntoChecklist(
    'botones_puertos',
    'Botones y carga',
    'Botones de volumen y encendido; el puerto de carga funciona.',
  );
  static const _carcasa = PuntoChecklist(
    'chasis',
    'Carcasa',
    'Golpes, rayones, vidrio roto o piezas sueltas.',
  );

  static const Map<String, List<PuntoChecklist>> _porCategoria = {
    'Laptop': [
      _encendido,
      PuntoChecklist(
        'pantalla',
        'Pantalla',
        'Sin píxeles muertos, manchas, líneas ni grietas.',
      ),
      PuntoChecklist(
        'teclado',
        'Teclado y touchpad',
        'Todas las teclas responden; el touchpad mueve el cursor y hace clic.',
      ),
      _bateria,
      PuntoChecklist(
        'puertos',
        'Puertos',
        'Carga, USB, audio y video funcionan.',
      ),
      PuntoChecklist(
        'chasis',
        'Chasis y bisagras',
        'Golpes, rayones, bisagras flojas o tornillos faltantes.',
      ),
    ],
    'Teléfono': [
      _encendido,
      _pantallaTactil,
      _bateria,
      _camaras,
      PuntoChecklist(
        'sonido',
        'Sonido y micrófono',
        'Se escucha por el altavoz y el micrófono graba bien.',
      ),
      _botonesYCarga,
      _carcasa,
    ],
    'Tablet': [
      _encendido,
      _pantallaTactil,
      _bateria,
      _camaras,
      _botonesYCarga,
      _carcasa,
    ],
    'Consola': [
      PuntoChecklist(
        'encendido',
        'Encendido',
        'Enciende, carga el menú y no se apaga sola.',
      ),
      PuntoChecklist(
        'video',
        'Imagen por HDMI',
        'Da imagen en un televisor, sin cortes ni rayas.',
      ),
      PuntoChecklist(
        'controles',
        'Controles',
        'Botones, palancas y vibración responden; sin movimientos fantasma.',
      ),
      PuntoChecklist(
        'lectora',
        'Lectora de discos',
        'Lee un disco de juego sin ruidos extraños.',
        opcional: true,
      ),
      PuntoChecklist(
        'ventilacion',
        'Ventilación y ruido',
        'No se recalienta ni hace ruidos raros tras 10 minutos de juego.',
      ),
      PuntoChecklist(
        'puertos',
        'Puertos',
        'USB, HDMI y red funcionan.',
      ),
      _carcasa,
    ],
    'Audio': [
      PuntoChecklist(
        'encendido',
        'Encendido y conexión',
        'Enciende y se conecta por Bluetooth o por cable.',
      ),
      PuntoChecklist(
        'sonido_lados',
        'Sonido',
        'Se escucha bien por los dos lados, sin ruido ni distorsión.',
      ),
      PuntoChecklist(
        'microfono',
        'Micrófono',
        'Se entiende la voz en una llamada de prueba.',
        opcional: true,
      ),
      PuntoChecklist(
        'funciones',
        'Botones y funciones',
        'Volumen, pausa y cancelación de ruido (si tiene) responden.',
      ),
      _bateria,
      PuntoChecklist(
        'estructura',
        'Almohadillas y diadema',
        'Sin roturas, cuero pelado ni partes flojas.',
      ),
    ],
    'Otro': [
      _encendido,
      PuntoChecklist(
        'funcion',
        'Función principal',
        'Hace correctamente aquello para lo que sirve.',
      ),
      PuntoChecklist(
        'puertos',
        'Puertos y conexiones',
        'La carga y las conexiones funcionan.',
      ),
      PuntoChecklist(
        'chasis',
        'Estado físico',
        'Golpes, rayones o piezas sueltas.',
      ),
    ],
  };

  /// El checklist de un tipo de equipo. Si no tiene tipo, se usa «Otro».
  static List<PuntoChecklist> para(String? categoria) =>
      _porCategoria[categoria] ?? _porCategoria['Otro']!;

  /// Nombre de un punto para mostrar en los mensajes de error.
  static String nombreDe(String clave, String? categoria) {
    for (final punto in para(categoria)) {
      if (punto.clave == clave) return punto.nombre;
    }
    return clave;
  }
}

enum ResultadoPunto {
  ok('ok', 'Funciona bien'),
  falla('falla', 'Tiene una falla'),
  noAplica('no_aplica', 'No aplica');

  const ResultadoPunto(this.clave, this.nombre);

  final String clave;
  final String nombre;

  static ResultadoPunto? desde(String? valor) {
    for (final resultado in ResultadoPunto.values) {
      if (resultado.clave == valor) return resultado;
    }
    return null;
  }
}

/// Lo que el inspector anotó en un punto del checklist.
class RevisionPunto {
  const RevisionPunto({
    this.resultado,
    this.nota = '',
    this.evidencias = const [],
  });

  factory RevisionPunto.desdeJson(Map<String, dynamic> json) => RevisionPunto(
        resultado: ResultadoPunto.desde(json['resultado'] as String?),
        nota: (json['nota'] as String?) ?? '',
        evidencias: ((json['evidencias'] as List?) ?? const [])
            .whereType<String>()
            .toList(growable: false),
      );

  /// null = todavía no se revisó.
  final ResultadoPunto? resultado;
  final String nota;

  /// Rutas de las fotos de evidencia en el almacén `evidencias`.
  final List<String> evidencias;

  bool get tieneFalla => resultado == ResultadoPunto.falla;

  Map<String, dynamic> aJson() => {
        'resultado': resultado?.clave,
        if (tieneFalla) 'nota': nota.trim(),
        if (tieneFalla) 'evidencias': evidencias,
      };
}

/// El checklist guardado de un pedido («entity» Inspeccion).
class Inspeccion {
  const Inspeccion({
    required this.pedidoId,
    required this.puntos,
    required this.completa,
    required this.actualizadaEn,
  });

  factory Inspeccion.desdeFila(Map<String, dynamic> fila) {
    final json = (fila['puntos'] as Map?)?.cast<String, dynamic>() ?? {};
    return Inspeccion(
      pedidoId: fila['pedido_id'] as String,
      puntos: {
        for (final entrada in json.entries)
          if (entrada.value is Map)
            entrada.key: RevisionPunto.desdeJson(
              (entrada.value as Map).cast<String, dynamic>(),
            ),
      },
      completa: fila['completa'] as bool? ?? false,
      actualizadaEn: DateTime.parse(fila['actualizado_en'] as String).toLocal(),
    );
  }

  final String pedidoId;

  /// Lo revisado en cada punto, según su clave (por ejemplo, `pantalla`).
  final Map<String, RevisionPunto> puntos;
  final bool completa;
  final DateTime actualizadaEn;

  int get fallas => puntos.values.where((p) => p.tieneFalla).length;
}
