/// ReUso Pay: la pasarela de pago SIMULADA de ReUso Seguro.
///
/// Aquí está todo lo que no depende de la pantalla: revisar los datos antes
/// de enviarlos, reconocer la marca de una tarjeta y traducir la respuesta
/// del «banco» a un mensaje claro. Quien aprueba o rechaza es el servidor
/// (`procesar_pago` en supabase/10_pasarela_simulada.sql), nunca la app.
///
/// No se mueve dinero real. Los rechazos se prueban con [DatoDePrueba].
library;

/// Rechazos seguidos que se permiten antes de cancelar el pedido.
const int maximoRechazos = 5;

// ---------------------------------------------------------------------
// Tarjetas
// ---------------------------------------------------------------------

/// Marca de una tarjeta, según sus primeros dígitos.
enum MarcaTarjeta {
  visa('Visa', 16, 3),
  mastercard('Mastercard', 16, 3),
  amex('American Express', 15, 4),
  otra('Tarjeta', 16, 3);

  const MarcaTarjeta(this.nombre, this.largo, this.largoCvv);

  final String nombre;

  /// Cuántos dígitos tiene el número.
  final int largo;

  /// Cuántos dígitos tiene el código de seguridad.
  final int largoCvv;

  static MarcaTarjeta de(String numero) {
    final n = soloDigitos(numero);
    if (n.startsWith('4')) return visa;
    if (n.startsWith('34') || n.startsWith('37')) return amex;
    if (n.length >= 2) {
      final dos = int.parse(n.substring(0, 2));
      if (dos >= 51 && dos <= 55) return mastercard;
      if (n.length >= 4) {
        final cuatro = int.parse(n.substring(0, 4));
        if (cuatro >= 2221 && cuatro <= 2720) return mastercard;
      }
    }
    return otra;
  }
}

String soloDigitos(String texto) => texto.replaceAll(RegExp(r'\D'), '');

/// Algoritmo de Luhn: el dígito de control que tienen todas las tarjetas.
/// Atrapa la mayoría de los errores al escribir el número.
bool luhnValido(String numero) {
  final n = soloDigitos(numero);
  if (n.length < 13 || n.length > 19) return false;
  var suma = 0;
  for (var i = 0; i < n.length; i++) {
    var digito = int.parse(n[n.length - 1 - i]);
    if (i.isOdd) {
      digito *= 2;
      if (digito > 9) digito -= 9;
    }
    suma += digito;
  }
  return suma % 10 == 0;
}

/// Pone un espacio cada 4 dígitos (Amex: 4-6-5), como en la tarjeta física.
String formatearNumeroTarjeta(String numero) {
  final n = soloDigitos(numero);
  final grupos = MarcaTarjeta.de(n) == MarcaTarjeta.amex
      ? const [4, 6, 5]
      : const [4, 4, 4, 4, 3];
  final partes = <String>[];
  var inicio = 0;
  for (final largo in grupos) {
    if (inicio >= n.length) break;
    final fin = (inicio + largo).clamp(0, n.length);
    partes.add(n.substring(inicio, fin));
    inicio = fin;
  }
  return partes.join(' ');
}

/// Revisa el número antes de enviarlo. Responde null si está bien, o el
/// mensaje que se muestra debajo del campo.
String? validarNumeroTarjeta(String numero) {
  final n = soloDigitos(numero);
  if (n.isEmpty) return 'Escribe el número de tu tarjeta.';
  final marca = MarcaTarjeta.de(n);
  if (n.length < marca.largo) {
    return 'Faltan dígitos: la tarjeta tiene ${marca.largo}.';
  }
  if (!luhnValido(n)) {
    return 'Este número no es válido. Revisa que lo hayas copiado bien.';
  }
  return null;
}

/// Revisa la fecha de vencimiento (MM/AA). [hoy] se pasa en las pruebas.
String? validarVencimiento(String texto, {DateTime? hoy}) {
  final coincide = RegExp(r'^(\d{2})/(\d{2})$').firstMatch(texto.trim());
  if (coincide == null) return 'Escríbela como MM/AA, por ejemplo 08/28.';
  final mes = int.parse(coincide.group(1)!);
  final anio = 2000 + int.parse(coincide.group(2)!);
  if (mes < 1 || mes > 12) return 'El mes va del 01 al 12.';
  final ahora = hoy ?? DateTime.now();
  // La tarjeta sirve hasta el último día de ese mes.
  final primerDiaDelMesSiguiente = DateTime(anio, mes + 1);
  final hoyDia = DateTime(ahora.year, ahora.month, ahora.day);
  if (!primerDiaDelMesSiguiente.isAfter(hoyDia)) return 'Esta tarjeta ya venció.';
  if (anio > ahora.year + 20) return 'Revisa el año.';
  return null;
}

String? validarCvv(String cvv, MarcaTarjeta marca) {
  final n = soloDigitos(cvv);
  if (n.length != marca.largoCvv) {
    return 'Son los ${marca.largoCvv} dígitos de seguridad '
        '${marca == MarcaTarjeta.amex ? 'del frente' : 'de atrás'}.';
  }
  return null;
}

String? validarTitular(String nombre) {
  final limpio = nombre.trim();
  if (limpio.length < 5 || !limpio.contains(' ')) {
    return 'Escribe el nombre y el apellido como aparecen en la tarjeta.';
  }
  return null;
}

// ---------------------------------------------------------------------
// Pago Móvil y Zelle (transferencias que se confirman con una referencia)
// ---------------------------------------------------------------------

/// Bancos de Venezuela con su código, para el Pago Móvil.
const List<(String, String)> bancosVenezuela = [
  ('0102', 'Banco de Venezuela'),
  ('0104', 'Venezolano de Crédito'),
  ('0105', 'Mercantil'),
  ('0108', 'Provincial'),
  ('0114', 'Bancaribe'),
  ('0115', 'Exterior'),
  ('0134', 'Banesco'),
  ('0151', 'BFC Banco Fondo Común'),
  ('0163', 'Banco del Tesoro'),
  ('0172', 'Bancamiga'),
  ('0174', 'Banplus'),
  ('0175', 'Banco Bicentenario'),
  ('0191', 'BNC Nacional de Crédito'),
];

String? validarReferencia(String referencia) {
  final limpia = referencia.trim().toUpperCase();
  if (limpia.isEmpty) return 'Escribe el número de referencia del pago.';
  if (!RegExp(r'^[A-Z0-9]{6,20}$').hasMatch(limpia)) {
    return 'Usa solo letras y números (entre 6 y 20).';
  }
  return null;
}

/// Teléfono venezolano: 0412, 0414, 0416, 0424 o 0426 y 7 dígitos.
String? validarTelefono(String telefono) {
  final n = soloDigitos(telefono);
  if (!RegExp(r'^04(12|14|16|24|26)\d{7}$').hasMatch(n)) {
    return 'Escribe tu número completo, por ejemplo 0414 123 4567.';
  }
  return null;
}

/// Cédula: V o E y entre 6 y 9 dígitos.
String? validarCedula(String cedula) {
  final limpia = cedula.toUpperCase().replaceAll(RegExp(r'[\s.\-]'), '');
  if (!RegExp(r'^[VE]\d{6,9}$').hasMatch(limpia)) {
    return 'Escríbela con la letra, por ejemplo V12345678.';
  }
  return null;
}

String? validarCorreo(String correo) {
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(correo.trim())) {
    return 'Escribe el correo con el que hiciste el Zelle.';
  }
  return null;
}

/// Convierte «250,00», «250.00» o «$250» en 250.0. Null si no es un monto.
double? leerMonto(String texto) {
  var limpio = texto.replaceAll(RegExp(r'[^\d,\.]'), '');
  if (limpio.isEmpty) return null;
  // La coma decimal es la que usamos en Venezuela.
  if (limpio.contains(',')) {
    limpio = limpio.replaceAll('.', '').replaceAll(',', '.');
  }
  return double.tryParse(limpio);
}

String? validarMonto(String texto) {
  final monto = leerMonto(texto);
  if (monto == null || monto <= 0) return 'Escribe el monto que transferiste.';
  return null;
}

// ---------------------------------------------------------------------
// Respuesta del banco
// ---------------------------------------------------------------------

/// Lo que respondió ReUso Pay: cada código trae un título corto, qué
/// pasó y qué hacer (heurística 9: ayudar a reconocer y corregir errores).
enum RespuestaBanco {
  aprobado('APROBADO', 'Pago aprobado', ''),
  numeroInvalido(
    'NUMERO_INVALIDO',
    'Número de tarjeta inválido',
    'El banco no reconoce ese número. Revisa que lo hayas copiado bien.',
  ),
  datosInvalidos(
    'DATOS_INVALIDOS',
    'Faltan datos del pago',
    'Revisa los campos marcados y vuelve a intentarlo.',
  ),
  tarjetaRechazada(
    'TARJETA_RECHAZADA',
    'Tu banco rechazó la tarjeta',
    'Tu banco no autorizó este pago. Prueba con otra tarjeta o paga con '
        'Pago Móvil o Zelle.',
  ),
  fondosInsuficientes(
    'FONDOS_INSUFICIENTES',
    'Fondos insuficientes',
    'La tarjeta no tiene saldo suficiente para este monto. Prueba con otra '
        'tarjeta u otro método.',
  ),
  tarjetaVencida(
    'TARJETA_VENCIDA',
    'Tarjeta vencida',
    'Revisa la fecha de vencimiento o usa otra tarjeta.',
  ),
  cvvIncorrecto(
    'CVV_INCORRECTO',
    'Código de seguridad incorrecto',
    'Revisa los dígitos de seguridad de tu tarjeta.',
  ),
  pagoNoEncontrado(
    'PAGO_NO_ENCONTRADO',
    'No encontramos tu pago',
    'El banco todavía no registra un pago con esa referencia. Revisa el '
        'número o espera unos minutos si lo acabas de hacer.',
  ),
  montoNoCoincide(
    'MONTO_NO_COINCIDE',
    'El monto no coincide',
    'El monto que transferiste es distinto al del pedido. Debe ser exacto.',
  ),
  referenciaUsada(
    'REFERENCIA_USADA',
    'Esa referencia ya se usó',
    'Cada pago sirve para un solo pedido. Revisa el número de referencia.',
  ),
  reservado(
    'RESERVADO',
    'Otro comprador pagó primero',
    'Este equipo ya fue reservado. Tu pedido se canceló y no se te cobró '
        'nada.',
  ),
  vencido(
    'VENCIDO',
    'Se acabó el tiempo para pagar',
    'Tu pedido venció y se canceló. Puedes volver a comprar el equipo si '
        'sigue disponible.',
  ),
  demasiadosIntentos(
    'DEMASIADOS_INTENTOS',
    'Pedido cancelado por seguridad',
    'Hubo demasiados intentos rechazados. Cancelamos el pedido para '
        'proteger tu cuenta. Puedes volver a comprar el equipo.',
  ),
  desconocido(
    'DESCONOCIDO',
    'No se pudo completar el pago',
    'Vuelve a intentarlo en un momento.',
  );

  const RespuestaBanco(this.codigo, this.titulo, this.queHacer);

  final String codigo;
  final String titulo;
  final String queHacer;

  /// Si se puede volver a intentar con el mismo pedido.
  bool get permiteReintentar =>
      this != reservado && this != vencido && this != demasiadosIntentos;

  static RespuestaBanco desde(String? codigo) => RespuestaBanco.values
      .firstWhere((r) => r.codigo == codigo, orElse: () => desconocido);
}

// ---------------------------------------------------------------------
// Datos de cobro y datos de prueba
// ---------------------------------------------------------------------

/// A dónde transfiere el comprador. Son datos FICTICIOS de demostración:
/// ningún banco real está conectado.
class DatosDeCobro {
  const DatosDeCobro._();

  static const String bancoPagoMovil = '0134 · Banesco';
  static const String telefonoPagoMovil = '0414 000 0000';
  static const String rif = 'J-00000000-0';
  static const String correoZelle = 'pagos@reusoseguro.example';
  static const String titularZelle = 'ReUso Seguro (demostración)';
}

/// Datos para probar cada respuesta del banco, como las «tarjetas de
/// prueba» de las pasarelas reales.
class DatoDePrueba {
  const DatoDePrueba(this.metodo, this.dato, this.resultado);

  final String metodo;
  final String dato;
  final String resultado;

  static const List<DatoDePrueba> todos = [
    DatoDePrueba('Tarjeta', '4242 4242 4242 4242', 'Aprobado'),
    DatoDePrueba('Tarjeta', '5555 5555 5555 4444', 'Aprobado (Mastercard)'),
    DatoDePrueba('Tarjeta', '4000 0000 0000 0002', 'Tarjeta rechazada'),
    DatoDePrueba('Tarjeta', '4000 0000 0000 9995', 'Fondos insuficientes'),
    DatoDePrueba('Tarjeta', '4000 0000 0000 0069', 'Tarjeta vencida'),
    DatoDePrueba('Tarjeta', '4000 0000 0000 0127', 'CVV incorrecto'),
    DatoDePrueba('Pago Móvil o Zelle', 'Referencia terminada en 0000',
        'Pago no encontrado'),
    DatoDePrueba('Pago Móvil o Zelle', 'Monto distinto al del pedido',
        'Monto no coincide'),
    DatoDePrueba('Pago Móvil o Zelle', 'Cualquier otra referencia',
        'Aprobado'),
    DatoDePrueba('Cuenta para cobrar del vendedor',
        'Teléfono terminado en 0000', 'Transferencia rechazada'),
  ];
}
