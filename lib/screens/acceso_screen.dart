import 'package:flutter/material.dart';

import '../services/sesion_service.dart';
import '../tema.dart';
import '../widgets/barra_superior.dart';
import '../widgets/pegatina.dart';

/// Pantalla para iniciar sesión o crear una cuenta (HU14).
///
/// Es una sola pantalla con dos modos. Al terminar bien, se cierra y
/// devuelve `true` a quien la abrió.
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

  /// false: iniciar sesión. true: crear cuenta.
  bool _creando = false;
  bool _enviando = false;
  bool _verContrasena = false;
  String? _error;
  String? _aviso;

  @override
  void dispose() {
    _nombre.dispose();
    _correo.dispose();
    _contrasena.dispose();
    super.dispose();
  }

  void _cambiarModo() {
    setState(() {
      _creando = !_creando;
      _error = null;
      _aviso = null;
    });
  }

  Future<void> _enviar() async {
    if (_enviando) return;
    if (!(_formulario.currentState?.validate() ?? false)) return;

    setState(() {
      _enviando = true;
      _error = null;
      _aviso = null;
    });

    final sesion = SesionService.instancia;
    final correo = _correo.text.trim();

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
            _aviso = 'Te enviamos un correo para confirmar tu cuenta. '
                'Ábrelo y luego inicia sesión aquí.';
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
        _error = error.mensaje;
      });
    }
  }

  InputDecoration _decoracion(String etiqueta, {Widget? sufijo}) {
    OutlineInputBorder borde(Color color) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: color, width: 2),
      );
    }

    return InputDecoration(
      labelText: etiqueta,
      filled: true,
      fillColor: Colors.white,
      enabledBorder: borde(ColoresApp.tinta),
      focusedBorder: borde(ColoresApp.orquidea),
      errorBorder: borde(_rojo),
      focusedErrorBorder: borde(_rojo),
      suffixIcon: sufijo,
    );
  }

  String? _validarNombre(String? valor) {
    if (valor == null || valor.trim().length < 2) return 'Escribe tu nombre.';
    return null;
  }

  String? _validarCorreo(String? valor) {
    final correo = (valor ?? '').trim();
    final valido = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(correo);
    return valido ? null : 'Escribe un correo válido.';
  }

  String? _validarContrasena(String? valor) {
    final contrasena = valor ?? '';
    if (contrasena.isEmpty) return 'Escribe tu contraseña.';
    if (_creando && contrasena.length < 6) return 'Usa al menos 6 caracteres.';
    return null;
  }

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
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Pegatina(
                    radio: 24,
                    sombra: 8,
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Form(
                        key: _formulario,
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
                                      'vender.'
                                  : 'Entra para comprar o publicar un equipo.',
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
                            if (_creando) ...[
                              TextFormField(
                                controller: _nombre,
                                decoration: _decoracion('Nombre y apellido'),
                                textInputAction: TextInputAction.next,
                                autofillHints: const [AutofillHints.name],
                                validator: _validarNombre,
                              ),
                              const SizedBox(height: 14),
                            ],
                            TextFormField(
                              controller: _correo,
                              decoration: _decoracion('Correo'),
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.email],
                              validator: _validarCorreo,
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _contrasena,
                              obscureText: !_verContrasena,
                              decoration: _decoracion(
                                'Contraseña',
                                sufijo: IconButton(
                                  tooltip: _verContrasena
                                      ? 'Ocultar contraseña'
                                      : 'Mostrar contraseña',
                                  icon: Icon(
                                    _verContrasena
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                  ),
                                  onPressed: () => setState(
                                    () => _verContrasena = !_verContrasena,
                                  ),
                                ),
                              ),
                              textInputAction: TextInputAction.done,
                              autofillHints: const [AutofillHints.password],
                              validator: _validarContrasena,
                              // Enter en la contraseña envía el formulario.
                              onFieldSubmitted: (_) => _enviar(),
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
                                    ? 'Ya tengo cuenta'
                                    : 'No tengo cuenta, quiero crear una',
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
