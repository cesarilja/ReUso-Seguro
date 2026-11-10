import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../formato.dart';
import '../models/pedido.dart';
import '../services/pasarela.dart';
import '../services/pedido_service.dart';
import '../tema.dart';
import '../widgets/avisos.dart';
import '../widgets/imagen_equipo.dart';
import '../widgets/pagina_base.dart';
import '../widgets/pasarela_widgets.dart';
import '../widgets/pedido_widgets.dart';
import '../widgets/pegatina.dart';
import 'mis_compras_screen.dart';

/// Pago protegido de un pedido (HU01) con ReUso Pay, la pasarela SIMULADA.
///
/// El comprador elige cómo pagar y escribe sus datos como en una pasarela
/// real. El servidor hace de banco: aprueba o rechaza con un motivo
/// (fondos insuficientes, referencia no encontrada…). No se mueve dinero
/// real: los rechazos se prueban con los datos de prueba de la insignia
/// «Modo de prueba».
class PagoScreen extends StatefulWidget {
  const PagoScreen({super.key, required this.pedido});

  final Pedido pedido;

  @override
  State<PagoScreen> createState() => _PagoScreenState();
}

class _PagoScreenState extends State<PagoScreen> {
  static const Color _rojo = Color(0xFFB3261E);

  late Pedido _pedido = widget.pedido;
  MetodoPago? _metodo;
  bool _ocupado = false;
  bool _intento = false;
  String? _error;

  /// La última respuesta negativa del banco, para explicarla.
  ResultadoPago? _rechazo;

  /// Mueve la cuenta regresiva cada segundo.
  Timer? _reloj;

  final _claveFormulario = GlobalKey<FormState>();

  // Tarjeta
  final _numero = TextEditingController();
  final _titular = TextEditingController();
  final _vence = TextEditingController();
  final _cvv = TextEditingController();
  final _focoCvv = FocusNode();

  // Pago Móvil y Zelle
  String? _bancoOrigen;
  final _telefono = TextEditingController();
  final _cedula = TextEditingController();
  final _correo = TextEditingController();
  final _referencia = TextEditingController();
  final _monto = TextEditingController();

  @override
  void initState() {
    super.initState();
    _reloj = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _pedido.estaPendiente) setState(() {});
    });
    // La tarjeta de la vista previa se llena mientras se escribe.
    for (final campo in [_numero, _titular, _vence, _cvv]) {
      campo.addListener(_refrescar);
    }
    _focoCvv.addListener(_refrescar);
  }

  void _refrescar() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _reloj?.cancel();
    for (final campo in [
      _numero, _titular, _vence, _cvv, //
      _telefono, _cedula, _correo, _referencia, _monto,
    ]) {
      campo.dispose();
    }
    _focoCvv.dispose();
    super.dispose();
  }

  /// Lo que se le manda al «banco». De la tarjeta, el servidor solo guarda
  /// la marca y los últimos 4 dígitos.
  Map<String, dynamic> _datos(MetodoPago metodo) => switch (metodo) {
        MetodoPago.tarjeta => {
            'numero': soloDigitos(_numero.text),
            'titular': _titular.text.trim(),
            'vence': _vence.text.trim(),
            'cvv': soloDigitos(_cvv.text),
          },
        MetodoPago.pagoMovil => {
            'banco': _bancoOrigen,
            'telefono': soloDigitos(_telefono.text),
            'cedula': _cedula.text.trim().toUpperCase(),
            'referencia': _referencia.text.trim().toUpperCase(),
            'monto': leerMonto(_monto.text),
          },
        MetodoPago.zelle => {
            'correo': _correo.text.trim(),
            'referencia': _referencia.text.trim().toUpperCase(),
            'monto': leerMonto(_monto.text),
          },
      };

  Future<void> _confirmarPago() async {
    if (_ocupado) return;
    setState(() {
      _intento = true;
      _error = null;
    });
    final metodo = _metodo;
    if (metodo == null) return; // el aviso rojo explica qué falta
    if (!(_claveFormulario.currentState?.validate() ?? false)) return;

    // Prevención de errores (heurística 5): pagar es importante, así que se
    // confirma el monto antes de seguir.
    final seguro = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: Text('¿Pagar ${_pedido.montoFormateado}?'),
        content: Text(
          'Pagarás con ${metodo.nombre}. Tu dinero quedará en custodia: el '
          'vendedor no lo recibe hasta que el Hub apruebe el equipo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(contexto).pop(false),
            child: const Text('Revisar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(contexto).pop(true),
            style: FilledButton.styleFrom(backgroundColor: ColoresApp.tinta),
            child: const Text('Sí, pagar'),
          ),
        ],
      ),
    );
    if (seguro != true || !mounted) return;

    setState(() {
      _ocupado = true;
      _rechazo = null;
    });
    try {
      final resultado = await PedidoService.instancia.pagar(
        _pedido,
        metodo: metodo,
        datos: _datos(metodo),
      );
      if (!mounted) return;
      setState(() {
        _pedido = resultado.pedido;
        _ocupado = false;
        _rechazo = resultado.aprobado ? null : resultado;
        // Como en las pasarelas reales, el CVV se vuelve a pedir.
        if (!resultado.aprobado) _cvv.clear();
      });
    } on ErrorDePedido catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.mensaje;
        _ocupado = false;
      });
    }
  }

  /// Después de vencer o cancelarse, empieza un pedido nuevo del mismo
  /// equipo (si sigue disponible).
  Future<void> _volverAIntentar() async {
    if (_ocupado) return;
    setState(() {
      _ocupado = true;
      _error = null;
    });
    try {
      final nuevo = await PedidoService.instancia.crearPedido(_pedido.equipo);
      if (!mounted) return;
      setState(() {
        _pedido = nuevo;
        _rechazo = null;
        _intento = false;
        _ocupado = false;
      });
    } on ErrorDePedido catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.mensaje;
        _ocupado = false;
      });
    }
  }

  /// Salida de emergencia (heurística 3): anular un pedido hecho por error.
  Future<void> _cancelar() async {
    if (_ocupado) return;
    final seguro = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('¿Cancelar este pedido?'),
        content: const Text(
          'No se te cobrará nada y el equipo seguirá disponible para otros '
          'compradores.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(contexto).pop(false),
            child: const Text('No, volver'),
          ),
          TextButton(
            onPressed: () => Navigator.of(contexto).pop(true),
            style: TextButton.styleFrom(foregroundColor: _rojo),
            child: const Text('Sí, cancelar'),
          ),
        ],
      ),
    );
    if (seguro != true || !mounted) return;

    setState(() => _ocupado = true);
    try {
      await PedidoService.instancia.cancelar(_pedido);
      if (!mounted) return;
      mostrarAviso(context, 'Cancelamos el pedido ${_pedido.codigo}.');
      Navigator.of(context).pop();
    } on ErrorDePedido catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.mensaje;
        _ocupado = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final Widget contenido;
    if (_pedido.estaPagado) {
      contenido = _Comprobante(pedido: _pedido);
    } else if (_pedido.estaCancelado || _pedido.vencido()) {
      final respuesta = _rechazo?.respuesta ??
          (_pedido.vencido() ? RespuestaBanco.vencido : null);
      contenido = _PedidoCerrado(
        respuesta: respuesta,
        ocupado: _ocupado,
        error: _error,
        alReintentar: _volverAIntentar,
      );
    } else {
      contenido = _vistaFormulario();
    }
    return PaginaBase(child: contenido);
  }

  Widget _vistaFormulario() {
    final faltaMetodo = _intento && _metodo == null;
    final metodo = _metodo;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const BotonVolver(texto: 'Volver al equipo'),
        const SizedBox(height: 20),
        const Text('Pago protegido', style: Tipos.titulo),
        const SizedBox(height: 6),
        Text(
          'Tu dinero queda en custodia hasta que nuestro centro de revisión '
          '(el Hub) compruebe que el equipo funciona. El vendedor no lo '
          'recibe antes.',
          style: Tipos.cuerpo,
        ),
        const SizedBox(height: 24),
        const _Pasos(actual: 2),
        const SizedBox(height: 24),
        _ResumenPedido(pedido: _pedido),
        const SizedBox(height: 28),
        Pegatina(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const EncabezadoReUsoPay(),
                const SizedBox(height: 16),
                CuentaRegresiva(queda: _pedido.tiempoRestante()),
                const SizedBox(height: 20),
                const Text('¿Cómo quieres pagar?', style: Tipos.subtitulo),
                const SizedBox(height: 10),
                for (final opcion in MetodoPago.values) ...[
                  _OpcionMetodo(
                    metodo: opcion,
                    elegido: _metodo == opcion,
                    conError: faltaMetodo,
                    alElegir: _ocupado
                        ? null
                        : () => setState(() {
                              _metodo = opcion;
                              _error = null;
                              _rechazo = null;
                            }),
                  ),
                  const SizedBox(height: 10),
                ],
                if (faltaMetodo)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 6),
                    child: Text(
                      'Elige una forma de pago para continuar.',
                      style: TextStyle(fontSize: 12.5, color: _rojo, height: 1.3),
                    ),
                  ),
                if (metodo != null) ...[
                  const SizedBox(height: 14),
                  Form(
                    key: _claveFormulario,
                    autovalidateMode: _intento
                        ? AutovalidateMode.onUserInteraction
                        : AutovalidateMode.disabled,
                    child: AnimatedSize(
                      duration: const Duration(milliseconds: 200),
                      child: switch (metodo) {
                        MetodoPago.tarjeta => _formularioTarjeta(),
                        MetodoPago.pagoMovil => _formularioPagoMovil(),
                        MetodoPago.zelle => _formularioZelle(),
                      },
                    ),
                  ),
                ],
                if (_rechazo != null) ...[
                  const SizedBox(height: 16),
                  AvisoRechazo(
                    respuesta: _rechazo!.respuesta,
                    intentosRestantes: _rechazo!.intentosRestantes,
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  RecuadroInfo(
                    icono: Icons.error_outline,
                    color: const Color(0xFFFBE9E8),
                    colorIcono: _rojo,
                    colorTexto: _rojo,
                    texto: _error!,
                  ),
                ],
                const SizedBox(height: 22),
                if (_ocupado)
                  ProcesandoPago(
                    transferencia: metodo != null && metodo != MetodoPago.tarjeta,
                  )
                else
                  BotonPegatina(
                    texto: _rechazo == null
                        ? 'Pagar ${_pedido.montoFormateado}'
                        : 'Intentar de nuevo',
                    icono: Icons.lock_outline,
                    expandido: true,
                    alTocar: _confirmarPago,
                  ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.lock, size: 14, color: ColoresApp.pizarra),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Pago simulado: no se mueve dinero real.',
                        style: Tipos.pequeno.copyWith(fontSize: 12.5),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: TextButton(
            onPressed: _ocupado ? null : _cancelar,
            style: TextButton.styleFrom(foregroundColor: _rojo),
            child: const Text('Cancelar pedido'),
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------------
  // Formularios de cada forma de pago
  // -------------------------------------------------------------------

  Widget _formularioTarjeta() {
    final marca = MarcaTarjeta.de(_numero.text);

    return AutofillGroup(
      child: Column(
        key: const ValueKey('tarjeta'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TarjetaVisual(
            numero: _numero.text,
            titular: _titular.text,
            vence: _vence.text,
            cvv: _cvv.text,
            mostrarReverso: _focoCvv.hasFocus,
          ),
          const SizedBox(height: 18),
          _Campo(
            controlador: _numero,
            etiqueta: 'Número de la tarjeta',
            pista: '4242 4242 4242 4242',
            teclado: TextInputType.number,
            formatos: const [FormatoNumeroTarjeta()],
            autollenado: const [AutofillHints.creditCardNumber],
            icono: Icons.credit_card,
            validar: validarNumeroTarjeta,
          ),
          _Campo(
            controlador: _titular,
            etiqueta: 'Nombre como aparece en la tarjeta',
            pista: 'María Pérez',
            mayusculas: TextCapitalization.words,
            autollenado: const [AutofillHints.creditCardName],
            icono: Icons.person_outline,
            validar: validarTitular,
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _Campo(
                  controlador: _vence,
                  etiqueta: 'Vence',
                  pista: 'MM/AA',
                  teclado: TextInputType.number,
                  formatos: const [FormatoVencimiento()],
                  autollenado: const [AutofillHints.creditCardExpirationDate],
                  icono: Icons.event_outlined,
                  validar: validarVencimiento,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Campo(
                  controlador: _cvv,
                  foco: _focoCvv,
                  etiqueta: 'CVV',
                  pista: marca.largoCvv == 4 ? '1234' : '123',
                  teclado: TextInputType.number,
                  oculto: true,
                  formatos: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(marca.largoCvv),
                  ],
                  autollenado: const [AutofillHints.creditCardSecurityCode],
                  icono: Icons.password_outlined,
                  validar: (valor) => validarCvv(valor, marca),
                ),
              ),
            ],
          ),
          Row(
            children: [
              const Icon(Icons.verified_user_outlined, size: 16, color: ColoresApp.pizarra),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'No guardamos el número completo ni el CVV: solo la marca y '
                  'los últimos 4 dígitos para tu comprobante.',
                  style: Tipos.pequeno.copyWith(fontSize: 12.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _formularioPagoMovil() {
    return Column(
      key: const ValueKey('pago_movil'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PasoTransferencia(
          numero: 1,
          texto: 'Haz el Pago Móvil desde la app de tu banco',
        ),
        const SizedBox(height: 10),
        _DatosDestino(
          children: [
            const DatoCopiable(
              titulo: 'Banco',
              valor: DatosDeCobro.bancoPagoMovil,
              copiar: '0134',
            ),
            DatoCopiable(
              titulo: 'Teléfono',
              valor: DatosDeCobro.telefonoPagoMovil,
              copiar: soloDigitos(DatosDeCobro.telefonoPagoMovil),
            ),
            const DatoCopiable(titulo: 'RIF', valor: DatosDeCobro.rif),
            _datoMonto(),
          ],
        ),
        const SizedBox(height: 18),
        const PasoTransferencia(numero: 2, texto: 'Escribe los datos de tu pago'),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _bancoOrigen,
          isExpanded: true,
          decoration: _decoracion('Banco desde el que pagaste', null,
              Icons.account_balance_outlined),
          items: [
            for (final (codigo, nombre) in bancosVenezuela)
              DropdownMenuItem(value: nombre, child: Text('$codigo · $nombre')),
          ],
          onChanged: _ocupado ? null : (valor) => setState(() => _bancoOrigen = valor),
          validator: (valor) => valor == null ? 'Elige tu banco.' : null,
        ),
        const SizedBox(height: 14),
        _Campo(
          controlador: _telefono,
          etiqueta: 'Teléfono desde el que pagaste',
          pista: '0414 123 4567',
          teclado: TextInputType.phone,
          autollenado: const [AutofillHints.telephoneNumber],
          icono: Icons.phone_iphone,
          validar: validarTelefono,
        ),
        _Campo(
          controlador: _cedula,
          etiqueta: 'Cédula del titular',
          pista: 'V12345678',
          mayusculas: TextCapitalization.characters,
          icono: Icons.badge_outlined,
          validar: validarCedula,
        ),
        _camposReferenciaYMonto('Número de referencia', '012345678912'),
      ],
    );
  }

  Widget _formularioZelle() {
    return Column(
      key: const ValueKey('zelle'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PasoTransferencia(numero: 1, texto: 'Envía el Zelle a esta cuenta'),
        const SizedBox(height: 10),
        _DatosDestino(
          children: [
            const DatoCopiable(titulo: 'Correo', valor: DatosDeCobro.correoZelle),
            const DatoCopiable(titulo: 'A nombre de', valor: DatosDeCobro.titularZelle),
            _datoMonto(),
          ],
        ),
        const SizedBox(height: 18),
        const PasoTransferencia(numero: 2, texto: 'Escribe los datos de tu Zelle'),
        const SizedBox(height: 12),
        _Campo(
          controlador: _correo,
          etiqueta: 'Tu correo de Zelle',
          pista: 'tucorreo@ejemplo.com',
          teclado: TextInputType.emailAddress,
          autollenado: const [AutofillHints.email],
          icono: Icons.alternate_email,
          validar: validarCorreo,
        ),
        _camposReferenciaYMonto('Número de confirmación', 'AB12CD34'),
      ],
    );
  }

  Widget _datoMonto() => DatoCopiable(
        titulo: 'Monto exacto',
        valor: _pedido.montoFormateado,
        copiar: _pedido.monto.toStringAsFixed(2).replaceAll('.', ','),
      );

  Widget _camposReferenciaYMonto(String etiqueta, String pista) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Campo(
          controlador: _referencia,
          etiqueta: etiqueta,
          pista: pista,
          mayusculas: TextCapitalization.characters,
          icono: Icons.tag,
          ayuda: 'Está en el comprobante que te dio tu banco.',
          validar: validarReferencia,
        ),
        _Campo(
          controlador: _monto,
          etiqueta: 'Monto que transferiste (USD)',
          pista: _pedido.monto.toStringAsFixed(2).replaceAll('.', ','),
          teclado: const TextInputType.numberWithOptions(decimal: true),
          icono: Icons.attach_money,
          validar: validarMonto,
        ),
      ],
    );
  }
}

/// Bordes y estilo iguales en todos los campos de la pasarela.
InputDecoration _decoracion(String etiqueta, String? pista, IconData icono,
    {String? ayuda}) {
  return InputDecoration(
    labelText: etiqueta,
    hintText: pista,
    helperText: ayuda,
    prefixIcon: Icon(icono),
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: ColoresApp.pizarra),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: ColoresApp.tinta, width: 2),
    ),
  );
}

/// Un campo de la pasarela, con su etiqueta visible y su validación.
class _Campo extends StatelessWidget {
  const _Campo({
    required this.controlador,
    required this.etiqueta,
    required this.icono,
    required this.validar,
    this.pista,
    this.ayuda,
    this.teclado,
    this.formatos,
    this.autollenado,
    this.mayusculas = TextCapitalization.none,
    this.oculto = false,
    this.foco,
  });

  final TextEditingController controlador;
  final String etiqueta;
  final IconData icono;
  final String? Function(String valor) validar;
  final String? pista;
  final String? ayuda;
  final TextInputType? teclado;
  final List<TextInputFormatter>? formatos;
  final List<String>? autollenado;
  final TextCapitalization mayusculas;
  final bool oculto;
  final FocusNode? foco;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controlador,
        focusNode: foco,
        keyboardType: teclado,
        inputFormatters: formatos,
        autofillHints: autollenado,
        textCapitalization: mayusculas,
        obscureText: oculto,
        decoration: _decoracion(etiqueta, pista, icono, ayuda: ayuda),
        validator: (valor) => validar(valor ?? ''),
      ),
    );
  }
}

/// Recuadro con los datos a los que se transfiere.
class _DatosDestino extends StatelessWidget {
  const _DatosDestino({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 4, 8),
      decoration: BoxDecoration(
        color: ColoresApp.nube,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(children: children),
    );
  }
}

/// El pedido venció o se canceló (por tiempo, por seguridad o porque otro
/// comprador pagó primero). Se dice por qué y qué se puede hacer.
class _PedidoCerrado extends StatelessWidget {
  const _PedidoCerrado({
    required this.respuesta,
    required this.ocupado,
    required this.error,
    required this.alReintentar,
  });

  final RespuestaBanco? respuesta;
  final bool ocupado;
  final String? error;
  final VoidCallback alReintentar;

  @override
  Widget build(BuildContext context) {
    final motivo = respuesta;
    final puedeReintentar = motivo != RespuestaBanco.reservado;
    final icono = switch (motivo) {
      RespuestaBanco.vencido => Icons.timer_off_outlined,
      RespuestaBanco.demasiadosIntentos => Icons.gpp_maybe_outlined,
      RespuestaBanco.reservado => Icons.lock_clock_outlined,
      _ => Icons.block,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const BotonVolver(texto: 'Volver'),
        const SizedBox(height: 28),
        Icon(icono, size: 64, color: ColoresApp.tinta),
        const SizedBox(height: 14),
        Text(
          motivo?.titulo ?? 'Este pedido está cancelado',
          textAlign: TextAlign.center,
          style: Tipos.titulo,
        ),
        const SizedBox(height: 8),
        Text(
          motivo?.queHacer ??
              'Si todavía quieres el equipo, puedes volver a comprarlo.',
          textAlign: TextAlign.center,
          style: Tipos.cuerpo,
        ),
        const SizedBox(height: 8),
        Text(
          'No se te cobró nada.',
          textAlign: TextAlign.center,
          style: Tipos.cuerpo.copyWith(
            fontWeight: FontWeight.w700,
            color: ColoresApp.tinta,
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 16),
          RecuadroInfo(
            icono: Icons.error_outline,
            color: const Color(0xFFFBE9E8),
            colorIcono: const Color(0xFFB3261E),
            colorTexto: const Color(0xFFB3261E),
            texto: error!,
          ),
        ],
        const SizedBox(height: 28),
        if (puedeReintentar)
          BotonPegatina(
            texto: ocupado ? 'Creando un pedido nuevo…' : 'Volver a intentarlo',
            icono: Icons.refresh,
            expandido: true,
            alTocar: ocupado ? () {} : alReintentar,
          ),
        if (puedeReintentar) const SizedBox(height: 14),
        BotonPegatina(
          texto: 'Ver otros equipos',
          principal: !puedeReintentar,
          expandido: true,
          alTocar: () => Navigator.of(context).popUntil((ruta) => ruta.isFirst),
        ),
      ],
    );
  }
}

/// Dónde va el comprador: 1 Elegir, 2 Pagar, 3 Listo.
class _Pasos extends StatelessWidget {
  const _Pasos({required this.actual});

  final int actual;

  @override
  Widget build(BuildContext context) {
    const nombres = ['Elegir equipo', 'Pagar', 'Listo'];

    // En pantallas angostas solo el paso actual muestra su nombre.
    return LayoutBuilder(
      builder: (context, medidas) {
        final angosta = medidas.maxWidth < 440;
        return Row(
          children: [
            for (var i = 0; i < nombres.length; i++) ...[
              if (i > 0)
                Expanded(
                  child: Container(
                    height: 2,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    color: i < actual ? ColoresApp.tinta : ColoresApp.cielo,
                  ),
                ),
              _Paso(
                numero: i + 1,
                texto: angosta && i + 1 != actual ? null : nombres[i],
                estado: (i + 1).compareTo(actual),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _Paso extends StatelessWidget {
  const _Paso({required this.numero, required this.texto, required this.estado});

  final int numero;
  final String? texto;

  /// -1 = ya pasó, 0 = es el actual, 1 = falta.
  final int estado;

  @override
  Widget build(BuildContext context) {
    final listo = estado < 0;
    final actual = estado == 0;
    final relleno = listo || actual;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: relleno ? ColoresApp.tinta : Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: ColoresApp.tinta, width: 2),
          ),
          child: listo
              ? const Icon(Icons.check, size: 15, color: Colors.white)
              : Text(
                  '$numero',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: actual ? Colors.white : ColoresApp.tinta,
                  ),
                ),
        ),
        if (texto != null) ...[
          const SizedBox(width: 6),
          Text(
            texto!,
            style: Tipos.pequeno.copyWith(
              color: ColoresApp.tinta,
              fontWeight: actual ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}

/// Una forma de pago para elegir, como una tarjeta grande y fácil de tocar.
class _OpcionMetodo extends StatelessWidget {
  const _OpcionMetodo({
    required this.metodo,
    required this.elegido,
    required this.conError,
    required this.alElegir,
  });

  final MetodoPago metodo;
  final bool elegido;
  final bool conError;
  final VoidCallback? alElegir;

  @override
  Widget build(BuildContext context) {
    final borde = elegido
        ? ColoresApp.orquidea
        : (conError ? const Color(0xFFB3261E) : ColoresApp.tinta);

    return Semantics(
      button: true,
      selected: elegido,
      label: 'Pagar con ${metodo.nombre}',
      child: InkWell(
        onTap: alElegir,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: elegido ? ColoresApp.lila : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borde, width: elegido ? 3 : 2),
          ),
          child: Row(
            children: [
              Icon(iconoDeMetodo(metodo), color: ColoresApp.tinta),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  metodo.nombre,
                  style: Tipos.subtitulo.copyWith(fontSize: 15.5),
                ),
              ),
              Icon(
                elegido ? Icons.radio_button_checked : Icons.radio_button_off,
                color: elegido ? ColoresApp.tinta : ColoresApp.pizarra,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Recuadro con el equipo, el estado del pedido y el monto.
class _ResumenPedido extends StatelessWidget {
  const _ResumenPedido({required this.pedido});

  final Pedido pedido;

  @override
  Widget build(BuildContext context) {
    final equipo = pedido.equipo;

    return Pegatina(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 84,
                    height: 84,
                    child: ImagenEquipo(equipo: equipo),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        equipo.titulo,
                        style: Tipos.subtitulo,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Pedido ${pedido.codigo} · Vende ${equipo.vendedor}',
                        style: Tipos.pequeno,
                      ),
                      const SizedBox(height: 8),
                      EtiquetaPedido(estado: pedido.estado),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(height: 2, color: ColoresApp.nube),
            const SizedBox(height: 10),
            FilaDato(titulo: 'Precio del equipo', valor: pedido.montoFormateado),
            const FilaDato(titulo: 'Inspección en el Hub', valor: 'Incluida'),
            FilaDato(
              titulo: 'Total a pagar',
              valor: pedido.montoFormateado,
              destacado: true,
            ),
          ],
        ),
      ),
    );
  }
}

/// Comprobante que ve el comprador cuando el pago queda en custodia.
class _Comprobante extends StatelessWidget {
  const _Comprobante({required this.pedido});

  final Pedido pedido;

  @override
  Widget build(BuildContext context) {
    final pagadoEn = pedido.pagadoEn;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Pasos(actual: 4),
        const SizedBox(height: 24),
        Center(
          child: Image.asset(
            'assets/images/pasos/custodia.png',
            width: 110,
            height: 110,
            filterQuality: FilterQuality.medium,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          '¡Listo! Tu pago está en custodia',
          textAlign: TextAlign.center,
          style: Tipos.titulo,
        ),
        const SizedBox(height: 8),
        Text(
          'Le avisamos al vendedor que lleve el equipo a nuestro Hub. Tu '
          'dinero queda retenido hasta que el inspector técnico lo revise.',
          textAlign: TextAlign.center,
          style: Tipos.cuerpo,
        ),
        const SizedBox(height: 28),
        Pegatina(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text('Comprobante', style: Tipos.subtitulo),
                    ),
                    EtiquetaPedido(estado: pedido.estado),
                  ],
                ),
                const SizedBox(height: 10),
                Container(height: 2, color: ColoresApp.nube),
                const SizedBox(height: 6),
                FilaDato(titulo: 'Equipo', valor: pedido.equipo.titulo),
                FilaDato(titulo: 'Pedido', valor: pedido.codigo),
                FilaDato(titulo: 'Referencia', valor: pedido.referencia ?? '-'),
                FilaDato(titulo: 'Forma de pago', valor: pedido.metodo?.nombre ?? '-'),
                if (pedido.pagoDetalle != null)
                  FilaDato(titulo: 'Pagado con', valor: pedido.pagoDetalle!),
                FilaDato(
                  titulo: 'Fecha',
                  valor: pagadoEn == null ? '-' : formatearFecha(pagadoEn),
                ),
                FilaDato(
                  titulo: 'Monto en custodia',
                  valor: pedido.montoFormateado,
                  destacado: true,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text('¿Qué sigue?', style: Tipos.subtitulo),
        const SizedBox(height: 12),
        LineaDeTiempo(estado: pedido.estado),
        const SizedBox(height: 8),
        const RecuadroInfo(
          icono: Icons.verified_user_outlined,
          texto: 'Si el equipo pasa la inspección, te lo enviamos. Si no, te '
              'devolvemos el monto completo.',
        ),
        const SizedBox(height: 28),
        BotonPegatina(
          texto: 'Ver mis compras',
          icono: Icons.receipt_long_outlined,
          expandido: true,
          alTocar: () => Navigator.of(context).pushReplacement(
            MaterialPageRoute<void>(builder: (_) => const MisComprasScreen()),
          ),
        ),
        const SizedBox(height: 14),
        BotonPegatina(
          texto: 'Seguir viendo equipos',
          principal: false,
          expandido: true,
          alTocar: () =>
              Navigator.of(context).popUntil((ruta) => ruta.isFirst),
        ),
      ],
    );
  }
}
