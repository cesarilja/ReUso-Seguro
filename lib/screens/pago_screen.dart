import 'package:flutter/material.dart';

import '../formato.dart';
import '../models/pedido.dart';
import '../services/pedido_service.dart';
import '../tema.dart';
import '../widgets/avisos.dart';
import '../widgets/imagen_equipo.dart';
import '../widgets/pagina_base.dart';
import '../widgets/pedido_widgets.dart';
import '../widgets/pegatina.dart';
import 'mis_compras_screen.dart';

/// Pago protegido de un pedido (HU01).
///
/// El pago es SIMULADO: no se mueve dinero real ni se usa una pasarela.
/// Cuando se confirma, el servidor deja el pedido en «Pago en custodia»,
/// reserva el equipo y la misma pantalla muestra el comprobante.
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
  bool _simularRechazo = false;
  bool _intento = false;
  String? _error;

  Future<void> _confirmarPago() async {
    if (_ocupado) return;
    setState(() {
      _intento = true;
      _error = null;
    });
    final metodo = _metodo;
    if (metodo == null) return; // el aviso rojo explica qué falta

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

    setState(() => _ocupado = true);
    try {
      final pagado = await PedidoService.instancia.pagar(
        _pedido,
        metodo: metodo,
        simularRechazo: _simularRechazo,
      );
      if (!mounted) return;
      setState(() {
        _pedido = pagado;
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
    return PaginaBase(
      child: _pedido.estaPendiente
          ? _formulario()
          : _Comprobante(pedido: _pedido),
    );
  }

  Widget _formulario() {
    final faltaMetodo = _intento && _metodo == null;

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
        const Text('¿Cómo quieres pagar?', style: Tipos.subtitulo),
        const SizedBox(height: 10),
        for (final metodo in MetodoPago.values) ...[
          _OpcionMetodo(
            metodo: metodo,
            elegido: _metodo == metodo,
            conError: faltaMetodo,
            alElegir: _ocupado
                ? null
                : () => setState(() {
                      _metodo = metodo;
                      _error = null;
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
        const SizedBox(height: 10),
        RecuadroInfo(
          icono: Icons.science_outlined,
          color: ColoresApp.lila,
          texto: 'Modo demostración: este pago es simulado. No se mueve '
              'dinero real ni se piden datos bancarios.',
          hijo: Row(
            children: [
              Switch(
                value: _simularRechazo,
                activeTrackColor: ColoresApp.tinta,
                onChanged: _ocupado
                    ? null
                    : (valor) => setState(() => _simularRechazo = valor),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Simular que el pago es rechazado (para probar)',
                  style: Tipos.pequeno.copyWith(color: ColoresApp.tinta),
                ),
              ),
            ],
          ),
        ),
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
        const SizedBox(height: 28),
        if (_ocupado)
          const _Verificando()
        else
          BotonPegatina(
            texto: 'Pagar ${_pedido.montoFormateado}',
            icono: Icons.lock_outline,
            expandido: true,
            alTocar: _confirmarPago,
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

/// Lo que se ve mientras se verifica el pago.
class _Verificando extends StatelessWidget {
  const _Verificando();

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
            'Verificando el pago…',
            style: Tipos.boton.copyWith(color: ColoresApp.tinta),
          ),
        ],
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
