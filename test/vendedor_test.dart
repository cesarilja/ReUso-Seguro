// Pruebas unitarias de la HU04 (confirmación de fondos) y la HU06
// (la transferencia falla).
//
// Ejecutar con:  flutter test
import 'package:flutter_test/flutter_test.dart';
import 'package:reuso_seguro/models/pedido.dart';
import 'package:reuso_seguro/models/rastreo.dart';
import 'package:reuso_seguro/models/venta.dart';

import 'datos_de_prueba.dart';

/// Una venta tal como la devuelve Supabase.
Pedido _venta(Map<String, dynamic> cambios) => Pedido.desdeFila({
      'id': 'pedido-1',
      'numero': 1001,
      'comprador_id': 'comprador-1',
      'monto': 250,
      'creado_en': '2026-11-10T14:00:00Z',
      'estado': 'pago_en_custodia',
      'pagado_en': '2026-11-10T14:05:00Z',
      ...cambios,
    }, laptopDePrueba);

void main() {
  group('HU04 · Ventas nuevas y entrega', () {
    test('CP-04.1 Cuenta solo las ventas pagadas que no se han visto', () {
      final ventas = [
        _venta({}),
        _venta({'id': 'p2', 'vendedor_vio_en': '2026-11-10T15:00:00Z'}),
        _venta({'id': 'p3', 'estado': 'recibido_en_hub'}),
      ];
      expect(ReglasVenta.contarNuevas(ventas), 2);
      expect(ReglasVenta.contarNuevas(const []), 0);
    });

    test('CP-04.2 Las instrucciones salen solo con el pago en custodia', () {
      expect(_venta({}).debeEntregar, isTrue);
      expect(_venta({'entregado_en': '2026-11-10T16:00:00Z'}).debeEntregar, isFalse);
      expect(_venta({'entregado_en': '2026-11-10T16:00:00Z'}).esperandoAlHub, isTrue);
      // Escenario 4: sin pago no se pide enviar nada.
      expect(_venta({'estado': 'pendiente_de_pago'}).debeEntregar, isFalse);
      expect(_venta({'estado': 'recibido_en_hub'}).debeEntregar, isFalse);
    });

    test('CP-04.3 Avisa cuando le compran, pero no en la primera carga', () {
      final venta = _venta({});
      expect(ReglasVenta.avisosDeCambio(null, [venta]), isEmpty);
      final avisos = ReglasVenta.avisosDeCambio({}, [venta]);
      expect(avisos.single, contains('Te compraron «${laptopDePrueba.titulo}»'));
      expect(avisos.single, contains('en custodia'));
    });
  });

  group('HU06 · La transferencia falla', () {
    test('CP-06.1 Lee el estado y el motivo de una liberación pendiente', () {
      final venta = _venta({
        'estado': 'liberacion_pendiente',
        'liberacion_motivo': 'SIN_CUENTA',
        'liberacion_intentos': 1,
      });
      expect(venta.estado, EstadoPedido.liberacionPendiente);
      expect(venta.liberacionPendiente, isTrue);
      expect(venta.liberacionMotivo, MotivoLiberacion.sinCuenta);
      expect(venta.liberacionIntentos, 1);
      expect(venta.pagoLiberado, isFalse);
      // El vendedor ve lo que va a recibir: el monto menos el 8 %.
      expect(venta.recibeVendedor, 230);
    });

    test('CP-06.2 Cada motivo explica qué hacer', () {
      expect(MotivoLiberacion.desde(null), isNull);
      expect(MotivoLiberacion.desde('CUENTA_RECHAZADA'), MotivoLiberacion.cuentaRechazada);
      expect(MotivoLiberacion.desde('OTRO'), MotivoLiberacion.desconocido);
      for (final motivo in MotivoLiberacion.values) {
        expect(motivo.titulo, isNotEmpty);
        expect(motivo.queHacer, isNotEmpty);
      }
    });

    test('CP-06.3 Avisa la falla y luego el pago liberado', () {
      final pendiente = _venta({'estado': 'liberacion_pendiente'});
      final falla = ReglasVenta.avisosDeCambio(
          {'pedido-1': EstadoPedido.aprobado}, [pendiente]);
      expect(falla.single, contains('No pudimos transferirte'));

      final liberada = _venta({
        'estado': 'pago_liberado',
        'liberado_en': '2026-11-11T10:00:00Z',
        'comision': 20,
        'monto_vendedor': 230,
      });
      final exito = ReglasVenta.avisosDeCambio(
          {'pedido-1': EstadoPedido.liberacionPendiente}, [liberada]);
      expect(exito.single, contains('Te liberamos el pago'));
      expect(exito.single, contains('\$230,00'));
    });

    test('CP-06.4 Para el comprador, el dinero se está liberando', () {
      final rastreo = Rastreo.de(pedidoDePrueba(EstadoPedido.liberacionPendiente));
      expect(rastreo.indiceActual, 3);
      expect(rastreo.dinero, DondeEstaElDinero.liberandose);
    });

    test('CP-06.5 La cuenta de cobro oculta el teléfono', () {
      const cuenta = CuentaCobro(
        banco: '0134 · Banesco',
        telefono: '04141234567',
        cedula: 'V12345678',
        titular: 'Ana Pérez',
      );
      expect(cuenta.telefonoOculto, '0414 ••• 4567');
    });
  });
}
