import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../models/plan_inspeccion.dart';
import '../services/publicacion_service.dart';
import '../services/reputacion_service.dart';
import '../services/verificacion_vendedor_service.dart';
import '../tema.dart';
import '../widgets/avisos.dart';
import '../widgets/barra_superior.dart';
import '../widgets/pegatina.dart';
import '../widgets/plan_widgets.dart';
import '../widgets/pie_de_pagina.dart';
import 'detalle_equipo_screen.dart';

/// Formulario para publicar un equipo en el catálogo (HU11).
///
/// Todos los datos son obligatorios, incluidas al menos 3 fotos. Al tocar
/// «Publicar equipo» las fotos se suben a Supabase Storage, el equipo se
/// guarda en la tabla `equipos` y aparece de una vez en el catálogo.
///
/// Sprint 4: el vendedor también elige el plan de inspección que pagará al
/// entregar (HU16 y HU17) y califica del 1 al 4 cómo está cada parte del
/// equipo (HU19).
class PublicarScreen extends StatefulWidget {
  const PublicarScreen({super.key});

  @override
  State<PublicarScreen> createState() => _PublicarScreenState();
}

class _PublicarScreenState extends State<PublicarScreen> {
  static const Color _rojo = Color(0xFFB3261E);

  final _formulario = GlobalKey<FormState>();
  final _titulo = TextEditingController();
  final _precio = TextEditingController();
  final _detalles = TextEditingController();
  final _descripcion = TextEditingController();

  String? _categoria;
  String? _condicion;
  final List<FotoElegida> _fotos = [];

  PlanInspeccion _plan = PlanInspeccion.basica;
  bool _express = false;
  final Map<String, int> _autoevaluacion = {};
  final Set<String> _sinParte = {};

  /// Se vuelve verdadero al primer intento de publicar: desde ahí se
  /// muestran los errores de todos los campos, también el de las fotos.
  bool _intento = false;
  bool _publicando = false;
  bool _eligiendoFotos = false;
  String? _error;
  String? _avisoFotos;

  /// Lo que valía [_hayCambios] la última vez que se dibujó la pantalla.
  bool _cambiosDibujados = false;

  // Verificación de identidad del vendedor (foto de cédula antes de publicar).
  final _cedula = TextEditingController();
  VerificacionVendedor? _verificacion;
  FotoElegida? _fotoCedula;
  bool _cargandoVerificacion = true;
  bool _verificando = false;
  String? _errorVerificacion;

  @override
  void initState() {
    super.initState();
    // Al escribir en cualquier campo se vuelve a revisar si hay cambios,
    // para preguntar antes de salir sin publicar.
    for (final campo in [_titulo, _precio, _detalles, _descripcion]) {
      campo.addListener(_revisarCambios);
    }
    // El resumen de cobro se recalcula con cada cambio del precio.
    _precio.addListener(_alCambiarPrecio);
    // HU20: si el vendedor es Confiable o Destacado, su comisión es del 4 %.
    ReputacionService.instancia.mia().then((reputacion) {
      if (mounted && reputacion != null) {
        setState(() => _tasaComision = reputacion.tasaComision);
      }
    });
    VerificacionVendedorService.instancia.estadoActual().then((estado) {
      if (mounted) {
        setState(() {
          _verificacion = estado;
          _cargandoVerificacion = false;
        });
      }
    });
  }

  double _tasaComision = ReglasPlan.tasaComision;

  void _alCambiarPrecio() {
    if (mounted) setState(() {});
  }

  void _revisarCambios() {
    if (_hayCambios != _cambiosDibujados) {
      setState(() => _cambiosDibujados = _hayCambios);
    }
  }

  @override
  void dispose() {
    _titulo.dispose();
    _precio.dispose();
    _detalles.dispose();
    _descripcion.dispose();
    _cedula.dispose();
    super.dispose();
  }

  Future<void> _elegirFotoCedula() async {
    if (_verificando) return;
    setState(() => _errorVerificacion = null);
    try {
      final archivo = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (archivo == null || !mounted) return;
      final foto = FotoElegida(
        bytes: await archivo.readAsBytes(),
        nombre: archivo.name,
        tipo: _tipoDe(archivo),
      );
      final problema = ReglasPublicacion.foto(foto);
      setState(() {
        if (problema != null) {
          _errorVerificacion = problema;
        } else {
          _fotoCedula = foto;
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorVerificacion = 'No pudimos abrir la imagen. Intenta de nuevo.';
        });
      }
    }
  }

  Future<void> _enviarVerificacion() async {
    if (_verificando) return;
    final errorCedula = VerificacionVendedorService.validarCedula(_cedula.text);
    if (errorCedula != null) {
      setState(() => _errorVerificacion = errorCedula);
      return;
    }
    if (_fotoCedula == null) {
      setState(() {
        _errorVerificacion =
            'Adjunta una foto legible de tu cédula de identidad para continuar.';
      });
      return;
    }

    setState(() {
      _verificando = true;
      _errorVerificacion = null;
    });
    try {
      final resultado = await VerificacionVendedorService.instancia.verificar(
        cedulaNumero: _cedula.text,
        fotoCedula: _fotoCedula!,
      );
      if (!mounted) return;
      setState(() {
        _verificacion = resultado;
        _verificando = false;
      });
      mostrarAviso(
        context,
        'Identidad verificada. Ya puedes publicar tus equipos.',
      );
    } on ErrorDePublicacion catch (error) {
      if (!mounted) return;
      setState(() {
        _errorVerificacion = error.mensaje;
        _verificando = false;
      });
    }
  }

  bool get _hayCambios =>
      _fotos.isNotEmpty ||
      _categoria != null ||
      _condicion != null ||
      _autoevaluacion.isNotEmpty ||
      [_titulo, _precio, _detalles, _descripcion]
          .any((campo) => campo.text.trim().isNotEmpty);

  // ---------------------------------------------------------------- fotos

  Future<void> _elegirFotos() async {
    final espacio = ReglasPublicacion.maximoFotos - _fotos.length;
    if (espacio <= 0 || _eligiendoFotos) return;

    setState(() {
      _eligiendoFotos = true;
      _avisoFotos = null;
    });

    try {
      // Se achican a 1600 px de ancho: se ven bien y suben más rápido.
      final archivos = await ImagePicker().pickMultiImage(
        maxWidth: 1600,
        imageQuality: 85,
      );

      final rechazos = <String>[];
      var sobraron = 0;
      for (final archivo in archivos) {
        if (_fotos.length >= ReglasPublicacion.maximoFotos) {
          sobraron++;
          continue;
        }
        final foto = FotoElegida(
          bytes: await archivo.readAsBytes(),
          nombre: archivo.name,
          tipo: _tipoDe(archivo),
        );
        final problema = ReglasPublicacion.foto(foto);
        if (problema == null) {
          _fotos.add(foto);
        } else {
          rechazos.add(problema);
        }
      }
      if (sobraron > 0) {
        rechazos.add(
          'Solo se pueden subir ${ReglasPublicacion.maximoFotos} fotos: '
          'dejamos fuera $sobraron.',
        );
      }
      _avisoFotos = rechazos.isEmpty ? null : rechazos.join('\n');
    } catch (_) {
      _avisoFotos = 'No pudimos abrir tus fotos. Intenta de nuevo.';
    } finally {
      if (mounted) setState(() => _eligiendoFotos = false);
    }
  }

  String _tipoDe(XFile archivo) {
    final tipo = archivo.mimeType;
    if (tipo != null && tipo.isNotEmpty) {
      return tipo == 'image/jpg' ? 'image/jpeg' : tipo;
    }
    final nombre = archivo.name.toLowerCase();
    if (nombre.endsWith('.png')) return 'image/png';
    if (nombre.endsWith('.webp')) return 'image/webp';
    if (nombre.endsWith('.jpg') || nombre.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    return 'desconocido';
  }

  void _quitarFoto(int indice) {
    setState(() {
      _fotos.removeAt(indice);
      _avisoFotos = null;
    });
  }

  void _hacerPortada(int indice) {
    setState(() => _fotos.insert(0, _fotos.removeAt(indice)));
  }

  // -------------------------------------------------------------- publicar

  Future<void> _publicar() async {
    if (_publicando) return;

    final camposBien = _formulario.currentState?.validate() ?? false;
    final errorFotos = ReglasPublicacion.fotos(_fotos);
    final errorAuto = _errorAutoevaluacion;
    setState(() {
      _intento = true;
      _error = null;
    });

    if (!camposBien || errorFotos != null || errorAuto != null) {
      setState(() {
        _error = 'Falta completar algunos datos. Revisa lo que está marcado '
            'en rojo: todos los campos, al menos '
            '${ReglasPublicacion.minimoFotos} fotos y la calificación de '
            'cada parte son obligatorios.';
      });
      return;
    }

    setState(() => _publicando = true);
    try {
      final equipo = await const PublicacionService().publicar(
        NuevaPublicacion(
          titulo: _titulo.text,
          categoria: _categoria!,
          precio: _precio.text,
          condicion: _condicion!,
          detallesEstado: _detalles.text,
          descripcion: _descripcion.text,
          fotos: List.unmodifiable(_fotos),
          plan: _plan,
          express: _express,
          autoevaluacion: Map.unmodifiable(_autoevaluacion),
        ),
      );
      if (!mounted) return;
      mostrarAviso(context, '¡Listo! Tu equipo ya está en el catálogo.');
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => DetalleEquipoScreen(equipo: equipo),
        ),
      );
    } on ErrorDePublicacion catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.mensaje;
        _publicando = false;
      });
    }
  }

  String? get _errorAutoevaluacion => ReglasPublicacion.autoevaluacion(
        _categoria,
        _categoria == null
            ? const {}
            : ReglasPublicacion.autoevaluacionLimpia(_categoria!, _autoevaluacion),
      );

  /// Si hay datos sin publicar, pregunta antes de salir.
  Future<void> _alIntentarSalir(bool yaSalio, Object? _) async {
    if (yaSalio || _publicando) return;

    final salir = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('¿Salir sin publicar?'),
        content: const Text(
          'Se perderán los datos y las fotos que agregaste.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(contexto).pop(false),
            child: const Text('Seguir editando'),
          ),
          TextButton(
            onPressed: () => Navigator.of(contexto).pop(true),
            style: TextButton.styleFrom(foregroundColor: _rojo),
            child: const Text('Salir'),
          ),
        ],
      ),
    );
    if (salir == true && mounted) Navigator.of(context).pop();
  }

  // ---------------------------------------------------------------- campos

  InputDecoration _decoracion({
    required String ejemplo,
    required IconData icono,
    String? ayuda,
  }) {
    OutlineInputBorder borde(Color color) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: color, width: 2),
      );
    }

    return InputDecoration(
      hintText: ejemplo,
      // Gris con contraste suficiente (4,89:1), según el taller de UX.
      hintStyle: const TextStyle(color: Color(0xFF6B7088)),
      helperText: ayuda,
      helperMaxLines: 2,
      helperStyle: Tipos.pequeno.copyWith(fontSize: 12.5),
      errorMaxLines: 3,
      errorStyle: const TextStyle(fontSize: 12.5, color: _rojo, height: 1.3),
      prefixIcon: Icon(icono, color: ColoresApp.pizarra),
      filled: true,
      fillColor: Colors.white,
      enabledBorder: borde(ColoresApp.tinta),
      focusedBorder: borde(ColoresApp.orquidea),
      errorBorder: borde(_rojo),
      focusedErrorBorder: borde(_rojo),
    );
  }

  AutovalidateMode get _modo => _intento
      ? AutovalidateMode.always
      : AutovalidateMode.onUserInteraction;

  Widget _desplegable({
    required String ejemplo,
    required IconData icono,
    required List<String> opciones,
    required String? valor,
    required ValueChanged<String?> alCambiar,
    required FormFieldValidator<String> validador,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: valor,
      autovalidateMode: _modo,
      isExpanded: true,
      decoration: _decoracion(ejemplo: ejemplo, icono: icono),
      items: [
        for (final opcion in opciones)
          DropdownMenuItem(value: opcion, child: Text(opcion)),
      ],
      onChanged: _publicando ? null : alCambiar,
      validator: validador,
    );
  }

  List<Widget> _campos(bool ancha) {
    final categoria = _desplegable(
      ejemplo: 'Elige el tipo',
      icono: Icons.category_outlined,
      opciones: ReglasPublicacion.categorias,
      valor: _categoria,
      alCambiar: (valor) => setState(() => _categoria = valor),
      validador: ReglasPublicacion.categoria,
    );
    final precio = TextFormField(
      controller: _precio,
      enabled: !_publicando,
      autovalidateMode: _modo,
      decoration: _decoracion(
        ejemplo: 'Ejemplo: 180',
        icono: Icons.attach_money,
        ayuda: 'En dólares. La inspección del Hub la pagas al entregar '
            '(elige el plan más abajo).',
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
      textInputAction: TextInputAction.next,
      validator: ReglasPublicacion.precio,
    );

    return [
      const _Etiqueta('Título'),
      TextFormField(
        controller: _titulo,
        enabled: !_publicando,
        autovalidateMode: _modo,
        maxLength: 80,
        decoration: _decoracion(
          ejemplo: 'Ejemplo: Laptop Lenovo ThinkPad T480',
          icono: Icons.title,
          ayuda: 'Incluye la marca y el modelo.',
        ),
        textCapitalization: TextCapitalization.sentences,
        textInputAction: TextInputAction.next,
        validator: ReglasPublicacion.titulo,
      ),
      const SizedBox(height: 10),
      if (ancha)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [const _Etiqueta('Tipo de equipo'), categoria],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [const _Etiqueta('Precio'), precio],
              ),
            ),
          ],
        )
      else ...[
        const _Etiqueta('Tipo de equipo'),
        categoria,
        const SizedBox(height: 16),
        const _Etiqueta('Precio'),
        precio,
      ],
      const SizedBox(height: 16),
      const _Etiqueta('Condición'),
      _desplegable(
        ejemplo: 'Elige cómo está',
        icono: Icons.verified_outlined,
        opciones: ReglasPublicacion.condiciones,
        valor: _condicion,
        alCambiar: (valor) => setState(() => _condicion = valor),
        validador: ReglasPublicacion.condicion,
      ),
      const SizedBox(height: 16),
      const _Etiqueta('Detalles del estado'),
      TextFormField(
        controller: _detalles,
        enabled: !_publicando,
        autovalidateMode: _modo,
        maxLength: 200,
        decoration: _decoracion(
          ejemplo: 'Ejemplo: la batería dura 3 horas y tiene un rayón leve',
          icono: Icons.build_outlined,
          ayuda: 'Batería, pantalla, golpes o rayones. El Hub lo comparará '
              'con el equipo.',
        ),
        textCapitalization: TextCapitalization.sentences,
        textInputAction: TextInputAction.next,
        validator: ReglasPublicacion.detallesEstado,
      ),
      const SizedBox(height: 10),
      const _Etiqueta('Descripción'),
      TextFormField(
        controller: _descripcion,
        enabled: !_publicando,
        autovalidateMode: _modo,
        minLines: 4,
        maxLines: 8,
        maxLength: ReglasPublicacion.maximoDescripcion,
        decoration: _decoracion(
          ejemplo: 'Ejemplo: Core i5, 8 GB de RAM y SSD de 256 GB. '
              'Incluye el cargador original.',
          icono: Icons.notes,
          ayuda: 'Mínimo ${ReglasPublicacion.minimoDescripcion} caracteres: '
              'características y accesorios incluidos.',
        ),
        textCapitalization: TextCapitalization.sentences,
        keyboardType: TextInputType.multiline,
        validator: ReglasPublicacion.descripcion,
      ),
    ];
  }

  // ----------------------------------------------------------------- vista

  @override
  Widget build(BuildContext context) {
    final margen = margenLateral(context);
    final ancha = MediaQuery.sizeOf(context).width >= 640;
    final errorFotos = _intento ? ReglasPublicacion.fotos(_fotos) : null;
    _cambiosDibujados = _hayCambios;

    return PopScope(
      canPop: !_hayCambios && !_publicando,
      onPopInvokedWithResult: _alIntentarSalir,
      child: Scaffold(
        body: Column(
          children: [
            BarraSuperior(
              mostrarAcciones: false,
              alTocarLogo: () => Navigator.of(context).maybePop(),
            ),
            Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(margen, 20, margen, 72),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 760),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextButton.icon(
                                onPressed: () =>
                                    Navigator.of(context).maybePop(),
                                style: TextButton.styleFrom(
                                  foregroundColor: ColoresApp.tinta,
                                ),
                                icon: const Icon(Icons.arrow_back, size: 18),
                                label: const Text('Volver al catálogo'),
                              ),
                              const SizedBox(height: 16),
                              const Text('Publicar un equipo',
                                  style: Tipos.titulo),
                              const SizedBox(height: 6),
                              Text(
                                'Todos los datos son obligatorios. Mientras '
                                'más claro seas, más rápido vendes.',
                                style: Tipos.cuerpo,
                              ),
                              const SizedBox(height: 24),
                              if (_cargandoVerificacion)
                                const Pegatina(
                                  radio: 22,
                                  child: Padding(
                                    padding: EdgeInsets.all(28),
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        color: ColoresApp.tinta,
                                      ),
                                    ),
                                  ),
                                )
                              else if (_verificacion == null)
                                _TarjetaVerificacionIdentidad(
                                  cedula: _cedula,
                                  fotoCedula: _fotoCedula,
                                  verificando: _verificando,
                                  error: _errorVerificacion,
                                  decoracion: _decoracion(
                                    ejemplo: 'Ejemplo: V-12345678',
                                    icono: Icons.badge_outlined,
                                    ayuda:
                                        'Ingresa tu cédula (V o E) tal como aparece en el documento.',
                                  ),
                                  alElegirFoto: _elegirFotoCedula,
                                  alQuitarFoto: () =>
                                      setState(() => _fotoCedula = null),
                                  alVerificar: _enviarVerificacion,
                                )
                              else ...[
                                _Mensaje(
                                  icono: Icons.verified_user,
                                  fondo: const Color(0xFFE7F5ED),
                                  color: ColoresApp.verde,
                                  texto:
                                      'Identidad verificada (${_verificacion!.cedulaNumero}). '
                                      'Ya puedes publicar equipos en el catálogo.',
                                ),
                                const SizedBox(height: 16),
                                Pegatina(
                                  radio: 22,
                                  child: Padding(
                                    padding: EdgeInsets.all(ancha ? 28 : 18),
                                    child: Form(
                                    key: _formulario,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        const _Etiqueta('Fotos del equipo'),
                                        _SelectorFotos(
                                          fotos: _fotos,
                                          habilitado: !_publicando,
                                          cargando: _eligiendoFotos,
                                          error: errorFotos,
                                          aviso: _avisoFotos,
                                          alAgregar: _elegirFotos,
                                          alQuitar: _quitarFoto,
                                          alHacerPortada: _hacerPortada,
                                        ),
                                        const SizedBox(height: 24),
                                        ..._campos(ancha),
                                        const SizedBox(height: 24),
                                        const _Etiqueta('Plan de inspección'),
                                        SelectorPlan(
                                          plan: _plan,
                                          express: _express,
                                          precio: ReglasPublicacion.precio(
                                                    _precio.text,
                                                  ) ==
                                                  null
                                              ? ReglasPublicacion.leerPrecio(
                                                  _precio.text,
                                                )
                                              : null,
                                          habilitado: !_publicando,
                                          alCambiarPlan: (plan) =>
                                              setState(() => _plan = plan),
                                          alCambiarExpress: (valor) =>
                                              setState(() => _express = valor),
                                        ),
                                        if (ReglasPublicacion.precio(
                                              _precio.text,
                                            ) ==
                                            null) ...[
                                          const SizedBox(height: 12),
                                          ResumenCobro(
                                            precio: ReglasPublicacion.leerPrecio(
                                              _precio.text,
                                            )!,
                                            plan: _plan,
                                            express: _express,
                                            tasaComision: _tasaComision,
                                          ),
                                        ],
                                        const SizedBox(height: 24),
                                        const _Etiqueta('¿Cómo está cada parte?'),
                                        if (_categoria == null)
                                          Text(
                                            'Elige primero el tipo de equipo '
                                            'para ver qué partes calificar.',
                                            style: Tipos.pequeno.copyWith(
                                              fontSize: 13.5,
                                            ),
                                          )
                                        else
                                          AutoevaluacionVendedor(
                                            categoria: _categoria!,
                                            notas: _autoevaluacion,
                                            sinParte: _sinParte,
                                            habilitado: !_publicando,
                                            error: _intento
                                                ? _errorAutoevaluacion
                                                : null,
                                            alCalificar: (clave, nota) =>
                                                setState(() {
                                              _sinParte.remove(clave);
                                              _autoevaluacion[clave] = nota.valor;
                                            }),
                                            alMarcarSinParte: (clave) =>
                                                setState(() {
                                              _autoevaluacion.remove(clave);
                                              _sinParte.add(clave);
                                            }),
                                          ),
                                        const SizedBox(height: 20),
                                        const _Mensaje(
                                          icono: Icons.verified_user_outlined,
                                          fondo: ColoresApp.lila,
                                          color: ColoresApp.tinta,
                                          texto:
                                              'Antes de que el comprador lo '
                                              'reciba, el inspector técnico del '
                                              'Hub revisará el equipo y lo '
                                              'comparará con lo que declares '
                                              'aquí, parte por parte. Si '
                                              'coincide, cobras.',
                                        ),
                                        if (_error != null) ...[
                                          const SizedBox(height: 16),
                                          _Mensaje(
                                            icono: Icons.error_outline,
                                            fondo: const Color(0xFFFBE9E8),
                                            color: _rojo,
                                            texto: _error!,
                                          ),
                                        ],
                                        const SizedBox(height: 24),
                                        _publicando
                                            ? const _Publicando()
                                            : BotonPegatina(
                                                texto: 'Publicar equipo',
                                                icono: Icons.upload_outlined,
                                                expandido: true,
                                                alTocar: _publicar,
                                              ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: PieDePagina(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fotos elegidas, el botón para agregar más y lo que falta cumplir.
class _SelectorFotos extends StatelessWidget {
  const _SelectorFotos({
    required this.fotos,
    required this.habilitado,
    required this.cargando,
    required this.error,
    required this.aviso,
    required this.alAgregar,
    required this.alQuitar,
    required this.alHacerPortada,
  });

  static const double _lado = 116;

  final List<FotoElegida> fotos;
  final bool habilitado;
  final bool cargando;
  final String? error;
  final String? aviso;
  final VoidCallback alAgregar;
  final ValueChanged<int> alQuitar;
  final ValueChanged<int> alHacerPortada;

  @override
  Widget build(BuildContext context) {
    final cantidad = fotos.length;
    final minimo = ReglasPublicacion.minimoFotos;
    final maximo = ReglasPublicacion.maximoFotos;
    final colorBorde =
        error != null ? const Color(0xFFB3261E) : ColoresApp.tinta;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (var i = 0; i < cantidad; i++)
              _Miniatura(
                foto: fotos[i],
                lado: _lado,
                esPortada: i == 0,
                habilitado: habilitado,
                alQuitar: () => alQuitar(i),
                alHacerPortada: () => alHacerPortada(i),
              ),
            if (cantidad < maximo)
              Semantics(
                button: true,
                label: 'Agregar fotos',
                child: InkWell(
                  onTap: habilitado && !cargando ? alAgregar : null,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: _lado,
                    height: _lado,
                    decoration: BoxDecoration(
                      color: ColoresApp.nube,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: colorBorde, width: 2),
                    ),
                    child: cargando
                        ? const Center(
                            child: SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                color: ColoresApp.orquidea,
                              ),
                            ),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.add_a_photo_outlined,
                                color: ColoresApp.tinta,
                                size: 30,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Agregar fotos',
                                style: Tipos.pequeno.copyWith(
                                  color: ColoresApp.tinta,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        _Requisito(
          cumplido: cantidad >= minimo,
          texto: 'Al menos $minimo fotos (llevas $cantidad de $maximo)',
        ),
        const _Requisito(
          cumplido: null,
          texto: 'JPG, PNG o WEBP, hasta 5 MB cada una',
        ),
        const _Requisito(
          cumplido: null,
          texto: 'La primera foto es la portada del catálogo. Toca la '
              'estrella para cambiarla.',
        ),
        if (error != null) ...[
          const SizedBox(height: 6),
          Text(
            error!,
            style: const TextStyle(
              fontSize: 12.5,
              color: Color(0xFFB3261E),
              height: 1.3,
            ),
          ),
        ],
        if (aviso != null) ...[
          const SizedBox(height: 6),
          Text(
            aviso!,
            style: Tipos.pequeno.copyWith(color: const Color(0xFFB3261E)),
          ),
        ],
      ],
    );
  }
}

class _Miniatura extends StatelessWidget {
  const _Miniatura({
    required this.foto,
    required this.lado,
    required this.esPortada,
    required this.habilitado,
    required this.alQuitar,
    required this.alHacerPortada,
  });

  final FotoElegida foto;
  final double lado;
  final bool esPortada;
  final bool habilitado;
  final VoidCallback alQuitar;
  final VoidCallback alHacerPortada;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: lado,
      height: lado,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: esPortada ? ColoresApp.orquidea : ColoresApp.tinta,
          width: esPortada ? 3 : 2,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.memory(foto.bytes, fit: BoxFit.cover),
          if (esPortada)
            Positioned(
              left: 6,
              bottom: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: ColoresApp.tinta,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'Portada',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          if (habilitado) ...[
            Positioned(
              top: 4,
              right: 4,
              child: _BotonRedondo(
                icono: Icons.close,
                ayuda: 'Quitar esta foto',
                alTocar: alQuitar,
              ),
            ),
            if (!esPortada)
              Positioned(
                top: 4,
                left: 4,
                child: _BotonRedondo(
                  icono: Icons.star_outline,
                  ayuda: 'Usar como portada',
                  alTocar: alHacerPortada,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _BotonRedondo extends StatelessWidget {
  const _BotonRedondo({
    required this.icono,
    required this.ayuda,
    required this.alTocar,
  });

  final IconData icono;
  final String ayuda;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: ayuda,
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(
          side: BorderSide(color: ColoresApp.tinta, width: 1.5),
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: alTocar,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(icono, size: 16, color: ColoresApp.tinta),
          ),
        ),
      ),
    );
  }
}

/// Una regla de las fotos: con check verde cuando se cumple.
class _Requisito extends StatelessWidget {
  const _Requisito({required this.cumplido, required this.texto});

  /// null = es solo informativa.
  final bool? cumplido;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final bien = cumplido == true;
    // Verde oscuro para que el texto tenga buen contraste (taller de UX).
    final color = bien ? const Color(0xFF1F7A44) : ColoresApp.pizarra;
    final icono = switch (cumplido) {
      true => Icons.check_circle,
      false => Icons.radio_button_unchecked,
      null => Icons.info_outline,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              texto,
              style: Tipos.pequeno.copyWith(
                color: color,
                fontWeight: bien ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Lo que se ve en lugar del botón mientras se sube todo.
class _Publicando extends StatelessWidget {
  const _Publicando();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: ColoresApp.nube,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: ColoresApp.orquidea,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Subiendo las fotos y publicando…',
            style: Tipos.boton.copyWith(color: ColoresApp.tinta),
          ),
        ],
      ),
    );
  }
}

/// Título pequeño encima de cada campo.
class _Etiqueta extends StatelessWidget {
  const _Etiqueta(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(texto, style: Tipos.subtitulo.copyWith(fontSize: 14.5)),
    );
  }
}

/// Recuadro para un aviso o un error.
class _Mensaje extends StatelessWidget {
  const _Mensaje({
    required this.texto,
    required this.icono,
    required this.fondo,
    required this.color,
  });

  final String texto;
  final IconData icono;
  final Color fondo;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              texto,
              style: Tipos.pequeno.copyWith(fontSize: 14.5, color: color),
            ),
          ),
        ],
      ),
    );
  }
}


/// Paso previo de verificación de identidad: foto de cédula del vendedor.
class _TarjetaVerificacionIdentidad extends StatelessWidget {
  const _TarjetaVerificacionIdentidad({
    required this.cedula,
    required this.fotoCedula,
    required this.verificando,
    required this.error,
    required this.decoracion,
    required this.alElegirFoto,
    required this.alQuitarFoto,
    required this.alVerificar,
  });

  final TextEditingController cedula;
  final FotoElegida? fotoCedula;
  final bool verificando;
  final String? error;
  final InputDecoration decoracion;
  final VoidCallback alElegirFoto;
  final VoidCallback alQuitarFoto;
  final VoidCallback alVerificar;

  @override
  Widget build(BuildContext context) {
    return Pegatina(
      radio: 22,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: ColoresApp.lila,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.verified_user_outlined,
                    color: ColoresApp.tinta,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Verifica tu identidad antes de publicar',
                        style: Tipos.subtitulo,
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Paso único de seguridad para proteger a compradores y vendedores.',
                        style: Tipos.pequeno,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Text(
              'Para evitar estafas, necesitamos que adjuntes una foto clara de '
              'tu cédula de identidad. Solo se solicita una vez; al completarlo '
              'podrás publicar cualquier equipo.',
              style: Tipos.cuerpo,
            ),
            const SizedBox(height: 20),
            const _Etiqueta('Número de cédula'),
            TextFormField(
              controller: cedula,
              enabled: !verificando,
              textCapitalization: TextCapitalization.characters,
              decoration: decoracion,
            ),
            const SizedBox(height: 20),
            const _Etiqueta('Foto de tu cédula de identidad'),
            if (fotoCedula == null)
              OutlinedButton.icon(
                onPressed: verificando ? null : alElegirFoto,
                icon: const Icon(Icons.add_a_photo_outlined),
                label: const Text('Adjuntar imagen de la cédula'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: ColoresApp.tinta,
                  side: const BorderSide(color: ColoresApp.tinta, width: 2),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: ColoresApp.nube,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: ColoresApp.tinta, width: 2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.memory(
                        fotoCedula!.bytes,
                        height: 200,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(
                          Icons.check_circle,
                          color: ColoresApp.verde,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            fotoCedula!.nombre,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Tipos.pequeno.copyWith(
                              color: ColoresApp.tinta,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: verificando ? null : alElegirFoto,
                          child: const Text('Cambiar'),
                        ),
                        TextButton(
                          onPressed: verificando ? null : alQuitarFoto,
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFFB3261E),
                          ),
                          child: const Text('Quitar'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            if (error != null) ...[
              const SizedBox(height: 14),
              _Mensaje(
                icono: Icons.error_outline,
                fondo: const Color(0xFFFBE9E8),
                color: const Color(0xFFB3261E),
                texto: error!,
              ),
            ],
            const SizedBox(height: 22),
            BotonPegatina(
              texto: verificando
                  ? 'Verificando identidad…'
                  : 'Verificar identidad y continuar',
              icono: Icons.verified_outlined,
              expandido: true,
              alTocar: verificando ? () {} : alVerificar,
            ),
          ],
        ),
      ),
    );
  }
}
