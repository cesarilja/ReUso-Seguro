import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Datos de la persona que inició sesión.
class Usuario {
  const Usuario({
    required this.id,
    required this.nombre,
    required this.correo,
  });

  final String id;
  final String nombre;
  final String correo;

  /// Primera letra del nombre, para el círculo de la barra superior.
  String get inicial => nombre.isEmpty ? '?' : nombre[0].toUpperCase();
}

/// Cómo terminó la creación de una cuenta.
enum ResultadoRegistro {
  /// La cuenta se creó y la persona ya está dentro.
  sesionIniciada,

  /// La cuenta se creó, pero falta abrir el correo de confirmación.
  faltaConfirmarCorreo,
}

/// En qué campo del formulario hay que mostrar un error.
enum CampoDeError { correo, contrasena, general }

/// Error con un mensaje listo para mostrarle al usuario.
class ErrorDeSesion implements Exception {
  const ErrorDeSesion(this.mensaje, {this.campo = CampoDeError.general});

  final String mensaje;

  /// Dónde se muestra: debajo del correo, de la contraseña o en un recuadro.
  final CampoDeError campo;
}

/// Maneja las cuentas: crear cuenta, iniciar sesión y cerrar sesión.
///
/// Es el único archivo que habla con Supabase sobre las cuentas. Las
/// pantallas lo usan con `SesionService.instancia` y se enteran de los
/// cambios porque avisa cada vez que alguien entra o sale.
class SesionService extends ChangeNotifier {
  SesionService._() {
    _cliente.auth.onAuthStateChange.listen(
      (_) => notifyListeners(),
      onError: (Object _) {},
    );
  }

  static final SesionService instancia = SesionService._();

  static const String _mensajeGenerico =
      'No pudimos completar la acción. Revisa tu conexión y prueba otra vez.';

  SupabaseClient get _cliente => Supabase.instance.client;

  bool get haySesion => _cliente.auth.currentSession != null;

  /// La persona que inició sesión, o null si nadie lo ha hecho.
  Usuario? get usuario {
    final actual = _cliente.auth.currentUser;
    if (actual == null) return null;

    final correo = actual.email ?? '';
    final dato = actual.userMetadata?['nombre'];
    final nombre = dato is String ? dato.trim() : '';

    return Usuario(
      id: actual.id,
      nombre: nombre.isEmpty ? correo : nombre,
      correo: correo,
    );
  }

  Future<ResultadoRegistro> crearCuenta({
    required String nombre,
    required String correo,
    required String contrasena,
  }) async {
    try {
      final respuesta = await _cliente.auth.signUp(
        email: correo,
        password: contrasena,
        // El nombre se guarda junto a la cuenta.
        data: {'nombre': nombre},
      );
      return respuesta.session == null
          ? ResultadoRegistro.faltaConfirmarCorreo
          : ResultadoRegistro.sesionIniciada;
    } on AuthException catch (error) {
      throw _traducir(error.message);
    } catch (_) {
      throw const ErrorDeSesion(_mensajeGenerico);
    }
  }

  Future<void> iniciarSesion({
    required String correo,
    required String contrasena,
  }) async {
    try {
      await _cliente.auth.signInWithPassword(
        email: correo,
        password: contrasena,
      );
    } on AuthException catch (error) {
      throw _traducir(error.message);
    } catch (_) {
      throw const ErrorDeSesion(_mensajeGenerico);
    }
  }

  Future<void> cerrarSesion() async {
    try {
      await _cliente.auth.signOut();
    } catch (_) {
      // Si falla la conexión, la sesión se cierra igual en este navegador.
    }
  }

  /// Supabase responde en inglés: aquí lo pasamos a mensajes nuestros y
  /// decimos en qué campo mostrarlos.
  ErrorDeSesion _traducir(String original) {
    final texto = original.toLowerCase();

    if (texto.contains('invalid login credentials')) {
      // Por seguridad, Supabase no dice si falló el correo o la contraseña:
      // así nadie puede averiguar qué correos tienen cuenta.
      return const ErrorDeSesion(
        'El correo o la contraseña no son correctos. Revisa que el correo '
        'esté bien escrito y que la contraseña respete mayúsculas y '
        'minúsculas.',
      );
    }
    if (texto.contains('already registered') ||
        texto.contains('already been registered')) {
      return const ErrorDeSesion(
        'Ya existe una cuenta con este correo. Inicia sesión.',
        campo: CampoDeError.correo,
      );
    }
    if (texto.contains('not confirmed')) {
      return const ErrorDeSesion(
        'Falta confirmar tu correo. Abre el mensaje que te enviamos y luego '
        'inicia sesión.',
      );
    }
    if (texto.contains('rate limit') || texto.contains('too many')) {
      return const ErrorDeSesion(
        'Demasiados intentos. Espera unos minutos y prueba otra vez.',
      );
    }
    if (texto.contains('password')) {
      return const ErrorDeSesion(
        'Esa contraseña no es segura. Usa al menos 8 caracteres con '
        'mayúsculas, minúsculas y números.',
        campo: CampoDeError.contrasena,
      );
    }
    // Solo si dice que el correo es inválido (no, por ejemplo, si falló el
    // envío del correo de confirmación).
    if (texto.contains('email') && texto.contains('invalid')) {
      return const ErrorDeSesion(
        'Ese correo no es válido. Revísalo. Ejemplo: maria@gmail.com',
        campo: CampoDeError.correo,
      );
    }
    return const ErrorDeSesion(_mensajeGenerico);
  }
}
