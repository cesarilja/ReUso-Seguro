import 'package:flutter/material.dart';

import '../services/sesion_service.dart';
import '../services/validaciones.dart';
import '../tema.dart';
import '../widgets/barra_superior.dart';
import '../widgets/pegatina.dart';

/// Pantalla para iniciar sesión o crear una cuenta (HU14).
///
/// Es una sola pantalla con dos modos. Al terminar bien, se cierra y
/// devuelve `true` a quien la abrió.
///
/// Ayudas para el usuario:
/// - Cada campo trae un ejemplo en gris y un texto de ayuda debajo.
/// - Un campo se revisa cuando la persona sale de él (no mientras escribe
///   la primera vez) y, desde ahí, se actualiza en vivo mientras lo corrige.
/// - Cada error dice exactamente qué corregir y en qué campo.
/// - Al crear la cuenta, los requisitos de la contraseña se marcan solos.
class AccesoScreen extends StatefulWidget {
  const AccesoScreen({super.key});

  @override
  State<AccesoScreen> createState() => _AccesoScreenState();
}

class _AccesoScreenState extends State<AccesoScreen> {
  static const Color _rojo = Color(0xFFB3261E);

  final GlobalKey<FormState> _formulario = GlobalKey<FormState>();
  final TextEditingController _nombre = TextEditingController();
  final TextEditingController _correo = TextEditingController();
  final TextEditingController _contrasena = TextEditingController();
  final TextEditingController _confirmacion = TextEditingController();

  /// Un foco por campo, para saber cuándo la persona sale de cada uno.
  final Map<String, FocusNode> _focos = {
    'nombre': FocusNode(),
    'correo': FocusNode(),
    'contrasena': FocusNode(),
    'confirmacion': FocusNode(),
  };

  /// Campos por los que la persona ya pasó: esos se revisan en vivo.
  final Set<String> _tocados = <String>{};

  /// false: iniciar sesión. true: crear cuenta.
  bool _creando = false;
  bool _enviando = false;
  bool _intentoEnviar = false;
  bool _verContrasena = false;
  bool _verConfirmacion = false;

  /// Errores que vienen de Supabase y van debajo de un campo concreto.
  String? _errorCorreoServidor;
  String? _errorContrasenaServidor;

  /// Error general (por ejemplo, correo o contraseña incorrectos).
  String? _error;
  String? _aviso;

  @override
  void initState() {
    super.initState();
    _focos.forEach((campo, foco) {
      foco.addListener(() {
        if (!mounted) return;
        if (!foco.hasFocus && !_tocados.contains(campo)) {
          setState(() => _tocados.add(campo));
        }
      });
    });
  }

  @override
  void dispose() {
    _nombre.dispose();
    _correo.dispose();
    _contrasena.dispose();
    _confirmacion.dispose();
    for (final foco in _focos.values) {
      foco.dispose();
    }
    super.dispose();
  }

  void _cambiarModo() {
    setState(() {
      _creando = !_creando;
      _intentoEnviar = false;
      _tocados.clear();
      _errorCorreoServidor = null;
      _errorContrasenaServidor = null;
      _error = null;
      _aviso = null;
      _confirmacion.clear();
    });
  }

  /// Cuándo se revisa un campo: después de salir de él o al enviar.
  AutovalidateMode _modo(String campo) =>
      _intentoEnviar || _tocados.contains(campo)
          ? AutovalidateMode.onUserInteraction
          : AutovalidateMode.disabled;

  Future<void> _enviar() async {
    if (_enviando) return;

    setState(() {
      _intentoEnviar = true;
      _errorCorreoServidor = null;
      _errorContrasenaServidor = null;
      _error = null;
      _aviso = null;
    });
    if (!(_formulario.currentState?.validate() ?? false)) return;

    setState(() => _enviando = true);

    final sesion = SesionService.instancia;
    // Los correos no distinguen mayúsculas: se envían en minúscula.
    final correo = _correo.text.trim().toLowerCase();

    try {
      if (_creando) {
        final resultado = await sesion.crearCuenta(
          nombre: _nombre.text.trim(),
          correo: correo,
          contrasena: _contrasena.text,
        );
        if (!mounted) return;

        if (resultado == ResultadoRegistro.faltaConfirmarCorreo) {
          setState(() {
            _enviando = false;
            _creando = false;
            _intentoEnviar = false;
            _tocados.clear();
            _contrasena.clear();
            _confirmacion.clear();
            _aviso = 'Te enviamos un correo a $correo para confirmar tu '
                'cuenta. Ábrelo y luego inicia sesión aquí.';
          });
          return;
        }
      } else {
        await sesion.iniciarSesion(
          correo: correo,
          contrasena: _contrasena.text,
        );
        if (!mounted) return;
      }

      // Listo: vuelve a la pantalla donde estaba la persona.
      Navigator.of(context).pop(true);
    } on ErrorDeSesion catch (error) {
      if (!mounted) return;
      setState(() {
        _enviando = false;
        switch (error.campo) {
          case CampoDeError.correo:
            _errorCorreoServidor = error.mensaje;
          case CampoDeError.contrasena:
            _errorContrasenaServidor = error.mensaje;
          case CampoDeError.general:
            _error = error.mensaje;
        }
      });
      // Vuelve a revisar para que el error aparezca debajo de su campo.
      _formulario.currentState?.validate();
    }
  }

  // ---------------------------------------------------------------- campos

  InputDecoration _decoracion({
    required String ejemplo,
    required IconData icono,
    String? ayuda,
    Widget? sufijo,
  }) {
    OutlineInputBorder borde(Color color) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: color, width: 2),
      );
    }

    return InputDecoration(
      // El ejemplo se ve en gris clarito mientras el campo está vacío.
      hintText: ejemplo,
      hintStyle: const TextStyle(color: Color(0xFFA3A8BC)),
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
      suffixIcon: sufijo,
    );
  }

  Widget _botonVer(bool visible, VoidCallback alTocar) {
    return IconButton(
      tooltip: visible ? 'Ocultar contraseña' : 'Mostrar contraseña',
      icon: Icon(
        visible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
      ),
      onPressed: alTocar,
    );
  }

  /// Al escribir de nuevo en un campo, se borra el error que mandó el
  /// servidor para ese campo y el error general.
  void _alEscribir({bool correo = false, bool contrasena = false}) {
    if ((correo && _errorCorreoServidor != null) ||
        (contrasena && _errorContrasenaServidor != null) ||
        _error != null) {
      setState(() {
        if (correo) _errorCorreoServidor = null;
        if (contrasena) _errorContrasenaServidor = null;
        _error = null;
      });
    }
  }

  List<Widget> _campos() {
    return [
      if (_creando) ...[
        const _Etiqueta('Nombre y apellido'),
        TextFormField(
          controller: _nombre,
          focusNode: _focos['nombre'],
          autovalidateMode: _modo('nombre'),
          decoration: _decoracion(
            ejemplo: 'Ejemplo: María Pérez',
            icono: Icons.person_outline,
            ayuda: 'Así te verán los compradores y vendedores.',
          ),
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.name],
          validator: Validaciones.nombre,
        ),
        const SizedBox(height: 16),
      ],
      const _Etiqueta('Correo electrónico'),
      TextFormField(
        controller: _correo,
        focusNode: _focos['correo'],
        autovalidateMode: _modo('correo'),
        decoration: _decoracion(
          ejemplo: 'ejemplo@gmail.com',
          icono: Icons.mail_outline,
          ayuda: _creando
              ? 'Te escribiremos aquí para avisarte de tus compras y ventas.'
              : null,
        ),
        keyboardType: TextInputType.emailAddress,
        autocorrect: false,
        textInputAction: TextInputAction.next,
        autofillHints: const [AutofillHints.email],
        onChanged: (_) => _alEscribir(correo: true),
        validator: (valor) =>
            _errorCorreoServidor ?? Validaciones.correo(valor),
      ),
      const SizedBox(height: 16),
      const _Etiqueta('Contraseña'),
      TextFormField(
        controller: _contrasena,
        focusNode: _focos['contrasena'],
        autovalidateMode: _modo('contrasena'),
        obscureText: !_verContrasena,
        decoration: _decoracion(
          ejemplo: _creando
              ? 'Mínimo ${Validaciones.minimoContrasena} caracteres'
              : 'Escribe tu contraseña',
          icono: Icons.lock_outline,
          sufijo: _botonVer(
            _verContrasena,
            () => setState(() => _verContrasena = !_verContrasena),
          ),
        ),
        textInputAction:
            _creando ? TextInputAction.next : TextInputAction.done,
        autofillHints: [
          _creando ? AutofillHints.newPassword : AutofillHints.password,
        ],
        onChanged: (_) {
          _alEscribir(contrasena: true);
          // La lista de requisitos y la confirmación se actualizan en vivo.
          if (_creando) setState(() {});
        },
        validator: (valor) =>
            _errorContrasenaServidor ??
            (_creando
                ? Validaciones.contrasenaNueva(valor)
                : Validaciones.contrasenaIngreso(valor)),
        // En el inicio de sesión, Enter envía el formulario.
        onFieldSubmitted: _creando ? null : (_) => _enviar(),
      ),
      if (_creando) ...[
        const SizedBox(height: 10),
        _RequisitosContrasena(contrasena: _contrasena.text),
        const SizedBox(height: 16),
        const _Etiqueta('Repite la contraseña'),
        TextFormField(
          controller: _confirmacion,
          focusNode: _focos['confirmacion'],
          autovalidateMode: _modo('confirmacion'),
          obscureText: !_verConfirmacion,
          decoration: _decoracion(
            ejemplo: 'Escríbela otra vez',
            icono: Icons.lock_reset_outlined,
            sufijo: _botonVer(
              _verConfirmacion,
              () => setState(() => _verConfirmacion = !_verConfirmacion),
            ),
          ),
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.newPassword],
          validator: (valor) =>
              Validaciones.confirmacion(valor, _contrasena.text),
          onFieldSubmitted: (_) => _enviar(),
        ),
      ],
    ];
  }

  // -------------------------------------------------------------- pantalla

  @override
  Widget build(BuildContext context) {
    final String textoBoton;
    if (_enviando) {
      textoBoton = 'Un momento...';
    } else if (_creando) {
      textoBoton = 'Crear cuenta';
    } else {
      textoBoton = 'Iniciar sesión';
    }

    return Scaffold(
      body: Column(
        children: [
          BarraSuperior(
            mostrarAcciones: false,
            // El logo devuelve al catálogo.
            alTocarLogo: () =>
                Navigator.of(context).popUntil((ruta) => ruta.isFirst),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Pegatina(
                    radio: 24,
                    sombra: 8,
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Form(
                        key: _formulario,
                        child: AutofillGroup(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                _creando ? 'Crea tu cuenta' : 'Inicia sesión',
                                style: Tipos.titulo,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _creando
                                    ? 'Con una sola cuenta puedes comprar y '
                                        'vender. Todos los campos son '
                                        'obligatorios.'
                                    : 'Entra para comprar o publicar un '
                                        'equipo.',
                                style: Tipos.cuerpo.copyWith(fontSize: 15),
                              ),
                              const SizedBox(height: 24),
                              if (_aviso != null) ...[
                                _Mensaje(
                                  texto: _aviso!,
                                  icono: Icons.mark_email_read_outlined,
                                  fondo: ColoresApp.nube,
                                  color: ColoresApp.tinta,
                                ),
                                const SizedBox(height: 18),
                              ],
                              // La clave hace que, al cambiar de modo, los
                              // campos empiecen sin errores viejos.
                              KeyedSubtree(
                                key: ValueKey<bool>(_creando),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: _campos(),
                                ),
                              ),
                              if (_error != null) ...[
                                const SizedBox(height: 18),
                                _Mensaje(
                                  texto: _error!,
                                  icono: Icons.error_outline,
                                  fondo: const Color(0xFFFCE8E6),
                                  color: _rojo,
                                ),
                              ],
                              const SizedBox(height: 24),
                              BotonPegatina(
                                texto: textoBoton,
                                expandido: true,
                                alTocar: _enviar,
                              ),
                              const SizedBox(height: 14),
                              TextButton(
                                onPressed: _enviando ? null : _cambiarModo,
                                style: TextButton.styleFrom(
                                  foregroundColor: ColoresApp.tinta,
                                ),
                                child: Text(
                                  _creando
                                      ? '¿Ya tienes cuenta? Inicia sesión'
                                      : '¿No tienes cuenta? Créala aquí',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
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

/// Lista de requisitos de la contraseña que se marcan mientras se escribe.
class _RequisitosContrasena extends StatelessWidget {
  const _RequisitosContrasena({required this.contrasena});

  final String contrasena;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: ColoresApp.nube,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tu contraseña debe tener:',
            style: Tipos.pequeno.copyWith(color: ColoresApp.tinta),
          ),
          const SizedBox(height: 6),
          for (final requisito in Validaciones.requisitosContrasena)
            _LineaRequisito(
              texto: requisito.texto,
              cumplido: requisito.cumple(contrasena),
            ),
        ],
      ),
    );
  }
}

class _LineaRequisito extends StatelessWidget {
  const _LineaRequisito({required this.texto, required this.cumplido});

  final String texto;
  final bool cumplido;

  @override
  Widget build(BuildContext context) {
    final color = cumplido ? ColoresApp.verde : ColoresApp.pizarra;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            cumplido ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              texto,
              style: Tipos.pequeno.copyWith(
                color: color,
                fontWeight: cumplido ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Recuadro para un mensaje de error o de aviso dentro del formulario.
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
