/// Reglas para validar los datos del registro y del inicio de sesión (HU14).
///
/// Están en la capa de lógica, no en la pantalla: la pantalla solo muestra
/// el mensaje que estas funciones devuelven. Cada función responde `null`
/// si el dato está bien, o un mensaje que explica exactamente qué corregir.
class Validaciones {
  Validaciones._();

  static const int minimoContrasena = 8;

  /// Lo que debe cumplir una contraseña nueva. La pantalla de registro los
  /// muestra como una lista que se va marcando mientras la persona escribe.
  static final List<RequisitoContrasena> requisitosContrasena = [
    RequisitoContrasena(
      texto: 'Al menos $minimoContrasena caracteres',
      faltante: 'al menos $minimoContrasena caracteres',
      cumple: (c) => c.length >= minimoContrasena,
    ),
    RequisitoContrasena(
      texto: 'Una letra mayúscula',
      faltante: 'una mayúscula',
      cumple: (c) => RegExp(r'[A-ZÁÉÍÓÚÑ]').hasMatch(c),
    ),
    RequisitoContrasena(
      texto: 'Una letra minúscula',
      faltante: 'una minúscula',
      cumple: (c) => RegExp(r'[a-záéíóúñ]').hasMatch(c),
    ),
    RequisitoContrasena(
      texto: 'Un número',
      faltante: 'un número',
      cumple: (c) => RegExp(r'[0-9]').hasMatch(c),
    ),
  ];

  /// Errores de escritura comunes en los correos más usados.
  static const Map<String, String> _dominiosMalEscritos = {
    'gmial.com': 'gmail.com',
    'gmai.com': 'gmail.com',
    'gamil.com': 'gmail.com',
    'gmal.com': 'gmail.com',
    'gmail.co': 'gmail.com',
    'gmail.con': 'gmail.com',
    'gmail.cm': 'gmail.com',
    'gmail.om': 'gmail.com',
    'hotmial.com': 'hotmail.com',
    'hotmal.com': 'hotmail.com',
    'hotmail.con': 'hotmail.com',
    'hotmail.co': 'hotmail.com',
    'outlok.com': 'outlook.com',
    'outlook.con': 'outlook.com',
    'yahooo.com': 'yahoo.com',
    'yaho.com': 'yahoo.com',
    'yahoo.con': 'yahoo.com',
  };

  static String? nombre(String? valor) {
    final nombre = (valor ?? '').trim();

    if (nombre.isEmpty) return 'Escribe tu nombre y apellido.';
    if (RegExp(r'[0-9]').hasMatch(nombre)) {
      return 'El nombre no puede tener números.';
    }
    // Letras con cualquier acento (é, ñ, ç, ö...), también si el navegador
    // manda el acento aparte, más apóstrofo (' o ’), guion y espacio.
    if (!RegExp("^[A-Za-zÀ-ÖØ-öø-ÿ\u0300-\u036f'’ -]+\$").hasMatch(nombre)) {
      return 'Usa solo letras en tu nombre (sin símbolos).';
    }

    // Solo cuentan las palabras que tienen al menos una letra: así
    // "María -" no pasa como nombre y apellido.
    final palabras = nombre
        .split(RegExp(r'\s+'))
        .where((palabra) => RegExp('[A-Za-zÀ-ÖØ-öø-ÿ]').hasMatch(palabra));
    if (palabras.length < 2) {
      return 'Escribe también tu apellido. Ejemplo: María Pérez';
    }
    return null;
  }

  static String? correo(String? valor) {
    final correo = (valor ?? '').trim();

    if (correo.isEmpty) return 'Escribe tu correo electrónico.';
    if (correo.contains(' ')) return 'El correo no puede tener espacios.';

    final arrobas = '@'.allMatches(correo).length;
    if (arrobas == 0) {
      return 'Al correo le falta la @. Ejemplo: maria@gmail.com';
    }
    if (arrobas > 1) return 'El correo solo puede tener una @.';

    final partes = correo.split('@');
    final usuario = partes[0];
    final dominio = partes[1].toLowerCase();

    if (usuario.isEmpty) {
      return 'Falta lo que va antes de la @. Ejemplo: maria@gmail.com';
    }
    if (!RegExp(r'^[A-Za-z0-9._%+\-]+$').hasMatch(usuario)) {
      return 'Antes de la @ solo puede haber letras, números, puntos, '
          'guiones o guion bajo.';
    }
    if (usuario.startsWith('.') ||
        usuario.endsWith('.') ||
        usuario.contains('..')) {
      return 'Antes de la @ no puede empezar ni terminar con punto, ni tener '
          'dos puntos seguidos.';
    }
    if (dominio.isEmpty) {
      return 'Falta lo que va después de la @. Ejemplo: gmail.com';
    }
    if (!dominio.contains('.')) {
      return 'Al correo le falta la terminación. Ejemplo: @gmail.com';
    }
    if (dominio.startsWith('.') ||
        dominio.endsWith('.') ||
        dominio.contains('..') ||
        dominio.split('.').any((p) => p.startsWith('-') || p.endsWith('-')) ||
        !RegExp(r'^[a-z0-9.\-]+$').hasMatch(dominio)) {
      return 'Revisa lo que va después de la @. Ejemplo: gmail.com';
    }

    final terminacion = dominio.split('.').last;
    if (terminacion.length < 2 || !RegExp(r'^[a-z]+$').hasMatch(terminacion)) {
      return 'La terminación del correo no es válida. Ejemplo: .com o .ve';
    }

    final correcto = _dominiosMalEscritos[dominio];
    if (correcto != null) return '¿Quisiste decir $usuario@$correcto?';

    return null;
  }

  /// Contraseña al crear la cuenta: dice exactamente qué le falta.
  static String? contrasenaNueva(String? valor) {
    final contrasena = valor ?? '';

    if (contrasena.isEmpty) return 'Crea una contraseña.';
    if (contrasena.contains(' ')) {
      return 'La contraseña no puede tener espacios.';
    }

    final faltan = requisitosContrasena
        .where((requisito) => !requisito.cumple(contrasena))
        .map((requisito) => requisito.faltante)
        .toList();
    if (faltan.isEmpty) return null;
    return 'A tu contraseña le falta ${_unir(faltan)}.';
  }

  static String? confirmacion(String? valor, String original) {
    final repetida = valor ?? '';
    if (repetida.isEmpty) return 'Repite tu contraseña.';
    if (repetida != original) {
      return 'Las contraseñas no coinciden. Escríbela igual que arriba.';
    }
    return null;
  }

  /// Contraseña al iniciar sesión: solo se revisa que no esté vacía.
  static String? contrasenaIngreso(String? valor) {
    if ((valor ?? '').isEmpty) return 'Escribe tu contraseña.';
    return null;
  }

  /// Une una lista así: "a", "a y b", "a, b y c".
  static String _unir(List<String> partes) {
    if (partes.length == 1) return partes.first;
    final inicio = partes.sublist(0, partes.length - 1).join(', ');
    return '$inicio y ${partes.last}';
  }
}

/// Un requisito de la contraseña, con su texto y cómo comprobarlo.
class RequisitoContrasena {
  const RequisitoContrasena({
    required this.texto,
    required this.faltante,
    required this.cumple,
  });

  /// Cómo se muestra en la lista: "Una letra mayúscula".
  final String texto;

  /// Cómo se nombra cuando falta: "una mayúscula".
  final String faltante;

  final bool Function(String contrasena) cumple;
}
