import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/pasarela.dart';
import '../tema.dart';
import 'avisos.dart';

const Color _rojo = Color(0xFFB3261E);
const Color _verde = Color(0xFF1F7A44);

// ---------------------------------------------------------------------
// Encabezado de ReUso Pay
// ---------------------------------------------------------------------

/// Marca de la pasarela, con la insignia «Modo de prueba» (como Stripe o
/// PayPal en sandbox). Al tocar la insignia se ven los datos de prueba.
class EncabezadoReUsoPay extends StatelessWidget {
  const EncabezadoReUsoPay({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: ColoresApp.tinta,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.shield_outlined, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ReUso Pay', style: Tipos.subtitulo.copyWith(fontSize: 18)),
              Text(
                'Pago protegido · conexión cifrada',
                style: Tipos.pequeno.copyWith(fontSize: 12.5),
              ),
            ],
          ),
        ),
        Tooltip(
          message: 'Ver los datos de prueba',
          child: InkWell(
            onTap: () => mostrarDatosDePrueba(context),
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF4D6),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0xFF8A5A00), width: 1.5),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.science_outlined, size: 15, color: Color(0xFF6B4500)),
                  SizedBox(width: 5),
                  Text(
                    'Modo de prueba',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF6B4500),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Tabla con los datos que provocan cada respuesta del banco.
Future<void> mostrarDatosDePrueba(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (contexto) => AlertDialog(
      title: const Text('Datos de prueba de ReUso Pay'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Esta pasarela es una simulación: no hay bancos conectados y '
                'no se mueve dinero real. Usa estos datos para ver cada '
                'respuesta. En las tarjetas, cualquier fecha futura y '
                'cualquier CVV sirven.',
                style: Tipos.pequeno.copyWith(fontSize: 14),
              ),
              const SizedBox(height: 12),
              for (final dato in DatoDePrueba.todos)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 5,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(dato.metodo, style: Tipos.pequeno.copyWith(fontSize: 12)),
                            SelectableText(
                              dato.dato,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: ColoresApp.tinta,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 4,
                        child: Text(
                          dato.resultado,
                          style: Tipos.pequeno.copyWith(
                            fontSize: 14,
                            color: dato.resultado.startsWith('Aprobado')
                                ? _verde
                                : _rojo,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(contexto).pop(),
          child: const Text('Entendido'),
        ),
      ],
    ),
  );
}

// ---------------------------------------------------------------------
// Cuenta regresiva
// ---------------------------------------------------------------------

/// Cuánto queda para pagar. En los últimos 2 minutos se pone roja, con
/// ícono y texto (nunca solo color).
class CuentaRegresiva extends StatelessWidget {
  const CuentaRegresiva({super.key, required this.queda});

  final Duration queda;

  @override
  Widget build(BuildContext context) {
    final urgente = queda.inSeconds < 120;
    final minutos = queda.inMinutes.toString().padLeft(2, '0');
    final segundos = (queda.inSeconds % 60).toString().padLeft(2, '0');
    final color = urgente ? _rojo : ColoresApp.tinta;

    return Semantics(
      liveRegion: urgente,
      label: 'Te quedan ${queda.inMinutes} minutos para pagar',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: urgente ? const Color(0xFFFBE9E8) : ColoresApp.nube,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(urgente ? Icons.timer_off_outlined : Icons.timer_outlined,
                  color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  urgente
                      ? '¡Apúrate! Tu pedido vence pronto'
                      : 'Reservamos este precio para ti mientras pagas',
                  style: Tipos.pequeno.copyWith(fontSize: 13.5, color: color),
                ),
              ),
              Text(
                '$minutos:$segundos',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: color,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Tarjeta
// ---------------------------------------------------------------------

/// Vista de la tarjeta que se llena mientras el comprador escribe.
/// Es decorativa: los lectores de pantalla leen los campos, no esto.
class TarjetaVisual extends StatelessWidget {
  const TarjetaVisual({
    super.key,
    required this.numero,
    required this.titular,
    required this.vence,
    required this.cvv,
    this.mostrarReverso = false,
  });

  final String numero;
  final String titular;
  final String vence;
  final String cvv;

  /// Se voltea mientras se escribe el CVV.
  final bool mostrarReverso;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: AspectRatio(
            aspectRatio: 1.586, // proporción de una tarjeta real
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              transitionBuilder: (hijo, animacion) =>
                  ScaleTransition(scale: animacion, child: hijo),
              child: mostrarReverso
                  ? _Reverso(key: const ValueKey('reverso'), cvv: cvv)
                  : _Frente(
                      key: const ValueKey('frente'),
                      numero: numero,
                      titular: titular,
                      vence: vence,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

BoxDecoration _fondoTarjeta(MarcaTarjeta marca) {
  final colores = switch (marca) {
    MarcaTarjeta.visa => const [Color(0xFF15133D), Color(0xFF3B4BA8)],
    MarcaTarjeta.mastercard => const [Color(0xFF2B1A3D), Color(0xFF9C4FB0)],
    MarcaTarjeta.amex => const [Color(0xFF0F3B4C), Color(0xFF2C8C9C)],
    MarcaTarjeta.otra => const [Color(0xFF15133D), Color(0xFF5868B8)],
  };
  return BoxDecoration(
    gradient: LinearGradient(
      colors: colores,
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    borderRadius: BorderRadius.circular(18),
    boxShadow: const [
      BoxShadow(color: Color(0x3315133D), blurRadius: 18, offset: Offset(0, 8)),
    ],
  );
}

class _Frente extends StatelessWidget {
  const _Frente({
    super.key,
    required this.numero,
    required this.titular,
    required this.vence,
  });

  final String numero;
  final String titular;
  final String vence;

  @override
  Widget build(BuildContext context) {
    final marca = MarcaTarjeta.de(numero);
    final digitos = soloDigitos(numero);
    final relleno = digitos.padRight(marca.largo, '•');
    const blanco = Colors.white;
    const suave = Color(0xCCFFFFFF);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _fondoTarjeta(marca),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // El chip de la tarjeta.
              Container(
                width: 40,
                height: 30,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF3D27A), Color(0xFFC9A13B)],
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(width: 10),
              const Icon(Icons.contactless_outlined, color: suave, size: 22),
              const Spacer(),
              Text(
                marca == MarcaTarjeta.otra ? 'ReUso Pay' : marca.nombre,
                style: const TextStyle(
                  color: blanco,
                  fontWeight: FontWeight.w700,
                  fontStyle: FontStyle.italic,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              _enmascarar(
                formatearNumeroTarjeta(relleno.replaceAll('•', '0')),
                digitos.length,
              ),
              style: const TextStyle(
                color: blanco,
                fontSize: 21,
                letterSpacing: 2,
                fontWeight: FontWeight.w500,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const Spacer(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('TITULAR',
                        style: TextStyle(color: suave, fontSize: 10, letterSpacing: 1)),
                    Text(
                      titular.trim().isEmpty ? 'TU NOMBRE' : titular.trim().toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: blanco, fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('VENCE',
                      style: TextStyle(color: suave, fontSize: 10, letterSpacing: 1)),
                  Text(
                    vence.isEmpty ? 'MM/AA' : vence,
                    style: const TextStyle(
                        color: blanco, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Muestra los dígitos escritos y puntos donde faltan.
  static String _enmascarar(String agrupado, int escritos) {
    final salida = StringBuffer();
    var cuenta = 0;
    for (final caracter in agrupado.split('')) {
      if (caracter == ' ') {
        salida.write(' ');
      } else {
        salida.write(cuenta < escritos ? caracter : '•');
        cuenta++;
      }
    }
    return salida.toString();
  }
}

class _Reverso extends StatelessWidget {
  const _Reverso({super.key, required this.cvv});

  final String cvv;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _fondoTarjeta(MarcaTarjeta.otra),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          Container(height: 42, color: const Color(0xFF0B0A22)),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 36,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    color: Colors.white,
                    child: Text(
                      cvv.isEmpty ? '•••' : cvv,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        fontStyle: FontStyle.italic,
                        color: ColoresApp.tinta,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Text(
              'Código de seguridad (CVV)',
              textAlign: TextAlign.right,
              style: TextStyle(color: Color(0xCCFFFFFF), fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

/// Escribe el número de tarjeta con espacios mientras se teclea.
class FormatoNumeroTarjeta extends TextInputFormatter {
  const FormatoNumeroTarjeta();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue anterior,
    TextEditingValue nuevo,
  ) {
    var digitos = soloDigitos(nuevo.text);
    final marca = MarcaTarjeta.de(digitos);
    final maximo = marca == MarcaTarjeta.otra ? 19 : marca.largo;
    if (digitos.length > maximo) digitos = digitos.substring(0, maximo);
    final texto = formatearNumeroTarjeta(digitos);
    return TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(offset: texto.length),
    );
  }
}

/// Escribe la fecha como MM/AA mientras se teclea.
class FormatoVencimiento extends TextInputFormatter {
  const FormatoVencimiento();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue anterior,
    TextEditingValue nuevo,
  ) {
    var digitos = soloDigitos(nuevo.text);
    if (digitos.length > 4) digitos = digitos.substring(0, 4);
    // Si se escribe 2-9 como primer dígito, es un mes de un dígito: 0X.
    if (digitos.length == 1 && int.parse(digitos) > 1) digitos = '0$digitos';
    final borrando = nuevo.text.length < anterior.text.length;
    final texto = digitos.length > 2 || (digitos.length == 2 && !borrando)
        ? '${digitos.substring(0, 2)}/${digitos.substring(2)}'
        : digitos;
    return TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(offset: texto.length),
    );
  }
}

// ---------------------------------------------------------------------
// Transferencias
// ---------------------------------------------------------------------

/// Un dato para transferir, con botón de copiar (menos errores al escribir:
/// heurística 5, prevención de errores).
class DatoCopiable extends StatelessWidget {
  const DatoCopiable({
    super.key,
    required this.titulo,
    required this.valor,
    this.copiar,
  });

  final String titulo;
  final String valor;

  /// Lo que se copia, si es distinto de lo que se muestra.
  final String? copiar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: Tipos.pequeno.copyWith(fontSize: 12.5)),
                Text(
                  valor,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: ColoresApp.tinta,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Copiar $titulo',
            icon: const Icon(Icons.copy_rounded, size: 20, color: ColoresApp.tinta),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: copiar ?? valor));
              if (context.mounted) mostrarAviso(context, '$titulo copiado.');
            },
          ),
        ],
      ),
    );
  }
}

/// Título numerado de cada paso de una transferencia.
class PasoTransferencia extends StatelessWidget {
  const PasoTransferencia({super.key, required this.numero, required this.texto});

  final int numero;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: ColoresApp.tinta,
            shape: BoxShape.circle,
          ),
          child: Text(
            '$numero',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(texto, style: Tipos.subtitulo.copyWith(fontSize: 15.5))),
      ],
    );
  }
}

// ---------------------------------------------------------------------
// Procesando y respuesta
// ---------------------------------------------------------------------

/// Los pasos que se ven mientras el «banco» responde (heurística 1:
/// visibilidad del estado del sistema).
class ProcesandoPago extends StatefulWidget {
  const ProcesandoPago({super.key, required this.transferencia});

  /// Pago Móvil o Zelle: se «busca» el pago en vez de autorizarlo.
  final bool transferencia;

  @override
  State<ProcesandoPago> createState() => _ProcesandoPagoState();
}

class _ProcesandoPagoState extends State<ProcesandoPago> {
  int _paso = 0;
  Timer? _reloj;

  List<String> get _pasos => widget.transferencia
      ? const [
          'Conectando con el banco',
          'Buscando tu pago por la referencia',
          'Confirmando el monto',
        ]
      : const [
          'Conectando con tu banco',
          'Verificando los datos de la tarjeta',
          'Autorizando el pago',
        ];

  @override
  void initState() {
    super.initState();
    _reloj = Timer.periodic(const Duration(milliseconds: 800), (_) {
      if (_paso < _pasos.length - 1) setState(() => _paso++);
    });
  }

  @override
  void dispose() {
    _reloj?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: '${_pasos[_paso]}. No cierres esta página.',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: ColoresApp.nube,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < _pasos.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    SizedBox(
                      width: 22,
                      height: 22,
                      child: i < _paso
                          ? const Icon(Icons.check_circle, color: _verde, size: 22)
                          : i == _paso
                              ? const CircularProgressIndicator(
                                  strokeWidth: 3,
                                  color: ColoresApp.orquidea,
                                )
                              : const Icon(Icons.radio_button_unchecked,
                                  color: ColoresApp.cielo, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _pasos[i],
                      style: Tipos.pequeno.copyWith(
                        fontSize: 14.5,
                        color: i <= _paso ? ColoresApp.tinta : ColoresApp.pizarra,
                        fontWeight: i == _paso ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 6),
            Text('No cierres esta página.', style: Tipos.pequeno),
          ],
        ),
      ),
    );
  }
}

/// El banco rechazó el pago: qué pasó, qué hacer y que no se cobró nada.
class AvisoRechazo extends StatelessWidget {
  const AvisoRechazo({
    super.key,
    required this.respuesta,
    required this.intentosRestantes,
  });

  final RespuestaBanco respuesta;
  final int intentosRestantes;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFBE9E8),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _rojo, width: 2),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.credit_card_off_outlined, color: _rojo, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pago rechazado: ${respuesta.titulo}',
                    style: Tipos.subtitulo.copyWith(color: _rojo, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    respuesta.queHacer,
                    style: Tipos.pequeno.copyWith(fontSize: 14, color: ColoresApp.tinta),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    respuesta.permiteReintentar
                        ? 'No se te cobró nada. '
                            '${intentosRestantes == 1 ? 'Te queda 1 intento' : 'Te quedan $intentosRestantes intentos'}'
                            ' con este pedido.'
                        : 'No se te cobró nada.',
                    style: Tipos.pequeno.copyWith(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: ColoresApp.tinta,
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
