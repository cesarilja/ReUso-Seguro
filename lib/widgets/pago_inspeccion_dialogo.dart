import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../formato.dart';
import '../models/pedido.dart';
import '../services/pasarela.dart';
import '../services/pedido_service.dart';
import '../services/vendedor_service.dart';
import '../tema.dart';
import 'pasarela_widgets.dart';

/// HU17: al tocar «Ya entregué el equipo», el vendedor paga la inspección
/// con ReUso Pay (SIMULADO). Si el banco la aprueba, la entrega queda
/// registrada de una vez. Responde true si se pagó.
Future<bool> pagarInspeccion(BuildContext context, Pedido venta) async {
  final pagado = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _DialogoPagoInspeccion(venta: venta),
  );
  return pagado == true;
}

enum _Metodo { tarjeta, pagoMovil }

const Color _rojo = Color(0xFFB3261E);

class _DialogoPagoInspeccion extends StatefulWidget {
  const _DialogoPagoInspeccion({required this.venta});

  final Pedido venta;

  @override
  State<_DialogoPagoInspeccion> createState() => _DialogoPagoInspeccionState();
}

class _DialogoPagoInspeccionState extends State<_DialogoPagoInspeccion> {
  final _formulario = GlobalKey<FormState>();
  final _numero = TextEditingController();
  final _titular = TextEditingController();
  final _vence = TextEditingController();
  final _cvv = TextEditingController();
  final _telefono = TextEditingController();
  final _cedula = TextEditingController();
  final _referencia = TextEditingController();
  late final _monto = TextEditingController(
    text: widget.venta.costoInspeccion.toStringAsFixed(2).replaceAll('.', ','),
  );

  _Metodo _metodo = _Metodo.tarjeta;
  String? _banco;
  bool _confirmaEntrega = false;
  bool _pagando = false;
  RespuestaBanco? _rechazo;
  String? _error;

  @override
  void dispose() {
    for (final campo in [
      _numero,
      _titular,
      _vence,
      _cvv,
      _telefono,
      _cedula,
      _referencia,
      _monto,
    ]) {
      campo.dispose();
    }
    super.dispose();
  }

  Map<String, dynamic> get _datos => switch (_metodo) {
        _Metodo.tarjeta => {
            'numero': soloDigitos(_numero.text),
            'titular': _titular.text.trim(),
            'vence': _vence.text.trim(),
            'cvv': soloDigitos(_cvv.text),
          },
        _Metodo.pagoMovil => {
            'banco': _banco,
            'telefono': soloDigitos(_telefono.text),
            'cedula': _cedula.text.trim().toUpperCase(),
            'referencia': _referencia.text.trim().toUpperCase(),
            'monto': leerMonto(_monto.text),
          },
      };

  Future<void> _pagar() async {
    if (_pagando) return;
    setState(() {
      _error = null;
      _rechazo = null;
    });
    final bien = _formulario.currentState?.validate() ?? false;
    if (!_confirmaEntrega) {
      setState(() => _error = 'Marca que ya dejaste el equipo en el Hub.');
      return;
    }
    if (!bien) return;

    setState(() => _pagando = true);
    try {
      final resultado = await VendedorService.instancia.pagarInspeccion(
        widget.venta,
        metodo: _metodo == _Metodo.tarjeta ? 'tarjeta' : 'pago_movil',
        datos: _datos,
      );
      if (!mounted) return;
      if (resultado.aprobado) {
        Navigator.of(context).pop(true);
        return;
      }
      setState(() {
        _rechazo = resultado.respuesta;
        _pagando = false;
      });
    } on ErrorDePedido catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.mensaje;
        _pagando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final venta = widget.venta;
    final costo = venta.costoInspeccion;
    final plan = venta.planInspeccion;

    return AlertDialog(
      title: const Text('Pagar la inspección y avisar la entrega'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Form(
            key: _formulario,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const EncabezadoReUsoPay(),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ColoresApp.nube,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Inspección ${plan.nombre}'
                          '${venta.conExpress ? ' Express' : ''} de '
                          '${venta.codigo}',
                          style: Tipos.cuerpo,
                        ),
                      ),
                      Text(
                        formatearDolares(costo),
                        style: Tipos.cuerpo.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Este pago no se devuelve si el equipo se rechaza. Es un '
                  'pago de prueba: no se mueve dinero real.',
                  style: Tipos.pequeno.copyWith(fontSize: 13),
                ),
                const SizedBox(height: 14),
                SegmentedButton<_Metodo>(
                  segments: const [
                    ButtonSegment(
                      value: _Metodo.tarjeta,
                      icon: Icon(Icons.credit_card),
                      label: Text('Tarjeta'),
                    ),
                    ButtonSegment(
                      value: _Metodo.pagoMovil,
                      icon: Icon(Icons.phone_android),
                      label: Text('Pago Móvil'),
                    ),
                  ],
                  selected: {_metodo},
                  onSelectionChanged: _pagando
                      ? null
                      : (valor) => setState(() {
                            _metodo = valor.first;
                            _rechazo = null;
                          }),
                ),
                const SizedBox(height: 14),
                if (_metodo == _Metodo.tarjeta) ..._camposTarjeta()
                else ..._camposPagoMovil(costo),
                const SizedBox(height: 8),
                CheckboxListTile(
                  value: _confirmaEntrega,
                  onChanged: _pagando
                      ? null
                      : (valor) => setState(() => _confirmaEntrega = valor ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Ya dejé «${venta.equipo.titulo}» en el Hub con el código '
                    '${venta.codigo}.',
                    style: Tipos.pequeno.copyWith(fontSize: 14, color: ColoresApp.tinta),
                  ),
                ),
                if (_rechazo != null) ...[
                  const SizedBox(height: 8),
                  _Problema(titulo: _rechazo!.titulo, texto: _rechazo!.queHacer),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  _Problema(titulo: 'Falta un dato', texto: _error!),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _pagando ? null : () => Navigator.of(context).pop(false),
          child: const Text('Todavía no'),
        ),
        FilledButton.icon(
          onPressed: _pagando ? null : _pagar,
          style: FilledButton.styleFrom(backgroundColor: ColoresApp.tinta),
          icon: _pagando
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.lock_outline),
          label: Text(_pagando ? 'Procesando…' : 'Pagar ${formatearDolares(costo)}'),
        ),
      ],
    );
  }

  List<Widget> _camposTarjeta() {
    final marca = MarcaTarjeta.de(_numero.text);
    return [
      TextFormField(
        controller: _numero,
        enabled: !_pagando,
        decoration: const InputDecoration(
          labelText: 'Número de la tarjeta',
          hintText: '4242 4242 4242 4242',
          prefixIcon: Icon(Icons.credit_card),
        ),
        keyboardType: TextInputType.number,
        inputFormatters: const [FormatoNumeroTarjeta()],
        onChanged: (_) => setState(() {}),
        validator: (valor) => validarNumeroTarjeta(valor ?? ''),
      ),
      const SizedBox(height: 10),
      TextFormField(
        controller: _titular,
        enabled: !_pagando,
        decoration: const InputDecoration(
          labelText: 'Nombre en la tarjeta',
          prefixIcon: Icon(Icons.person_outline),
        ),
        textCapitalization: TextCapitalization.words,
        validator: (valor) => validarTitular(valor ?? ''),
      ),
      const SizedBox(height: 10),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TextFormField(
              controller: _vence,
              enabled: !_pagando,
              decoration: const InputDecoration(labelText: 'Vence (MM/AA)'),
              keyboardType: TextInputType.number,
              inputFormatters: const [FormatoVencimiento()],
              validator: (valor) => validarVencimiento(valor ?? ''),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextFormField(
              controller: _cvv,
              enabled: !_pagando,
              obscureText: true,
              decoration: InputDecoration(labelText: 'CVV (${marca.largoCvv} dígitos)'),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(4),
              ],
              validator: (valor) => validarCvv(valor ?? '', marca),
            ),
          ),
        ],
      ),
    ];
  }

  List<Widget> _camposPagoMovil(double costo) {
    return [
      Text(
        'Haz el Pago Móvil a ReUso Seguro y escribe aquí la referencia.',
        style: Tipos.pequeno.copyWith(fontSize: 13.5, color: ColoresApp.tinta),
      ),
      const SizedBox(height: 8),
      const DatoCopiable(titulo: 'Banco', valor: DatosDeCobro.bancoPagoMovil),
      const DatoCopiable(titulo: 'Teléfono', valor: DatosDeCobro.telefonoPagoMovil),
      const DatoCopiable(titulo: 'RIF', valor: DatosDeCobro.rif),
      DatoCopiable(
        titulo: 'Monto',
        valor: formatearDolares(costo),
        copiar: costo.toStringAsFixed(2).replaceAll('.', ','),
      ),
      const SizedBox(height: 10),
      DropdownButtonFormField<String>(
        initialValue: _banco,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Tu banco',
          prefixIcon: Icon(Icons.account_balance_outlined),
        ),
        items: [
          for (final (codigo, nombre) in bancosVenezuela)
            DropdownMenuItem(value: '$codigo · $nombre', child: Text('$codigo · $nombre')),
        ],
        onChanged: _pagando ? null : (valor) => setState(() => _banco = valor),
        validator: (valor) => valor == null ? 'Elige tu banco.' : null,
      ),
      const SizedBox(height: 10),
      TextFormField(
        controller: _telefono,
        enabled: !_pagando,
        decoration: const InputDecoration(
          labelText: 'Tu teléfono',
          hintText: '0414 123 4567',
          prefixIcon: Icon(Icons.phone_outlined),
        ),
        keyboardType: TextInputType.phone,
        validator: (valor) => validarTelefono(valor ?? ''),
      ),
      const SizedBox(height: 10),
      TextFormField(
        controller: _cedula,
        enabled: !_pagando,
        decoration: const InputDecoration(
          labelText: 'Tu cédula',
          hintText: 'V12345678',
          prefixIcon: Icon(Icons.badge_outlined),
        ),
        validator: (valor) => validarCedula(valor ?? ''),
      ),
      const SizedBox(height: 10),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TextFormField(
              controller: _referencia,
              enabled: !_pagando,
              decoration: const InputDecoration(labelText: 'Referencia'),
              textCapitalization: TextCapitalization.characters,
              validator: (valor) => validarReferencia(valor ?? ''),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextFormField(
              controller: _monto,
              enabled: !_pagando,
              decoration: const InputDecoration(labelText: 'Monto (\$)'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (valor) => validarMonto(valor ?? ''),
            ),
          ),
        ],
      ),
    ];
  }
}

class _Problema extends StatelessWidget {
  const _Problema({required this.titulo, required this.texto});

  final String titulo;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFBE9E8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: _rojo, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo,
                    style: Tipos.cuerpo.copyWith(color: _rojo, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(texto, style: Tipos.pequeno.copyWith(fontSize: 13.5, color: _rojo)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
