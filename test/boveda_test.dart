// Pruebas unitarias de la HU09 · Bóveda escrow.
//
// El cuadre lo calcula el servidor (se prueba con
// supabase/pruebas/13_verificar_boveda.sql). Aquí se prueba que la app
// entienda bien su respuesta: totales, descuadres y liberaciones.
//
// Ejecutar con:  flutter test
import 'package:flutter_test/flutter_test.dart';
import 'package:reuso_seguro/models/boveda.dart';
import 'package:reuso_seguro/models/pedido.dart';

import 'boveda_datos.dart';

void main() {
  group('HU09 · Totales', () {
    test('CP-09.1 Lee los 4 totales y el total que entró a la bóveda', () {
      final estado = EstadoBoveda.desdeJson(bovedaCuadrada());
      expect(estado.totales.enCustodia, 70);
      expect(estado.totales.liberado, 92);
      expect(estado.totales.reembolsado, 50);
      expect(estado.totales.comisiones, 8);
      // 70 + 92 + 50 + 8: todo lo que pagaron los compradores.
      expect(estado.totales.totalIngresado, 220);
    });

    test('CP-09.2 Cuenta los pedidos por estado', () {
      final estado = EstadoBoveda.desdeJson(bovedaCuadrada());
      expect(estado.porEstado[EstadoPedido.pagoLiberado], 1);
      expect(estado.totalPedidos, 3);
      expect(estado.vacia, isFalse);
    });

    test('CP-09.3 Una bóveda sin pagos está vacía y cuadrada', () {
      final estado = EstadoBoveda.desdeJson(bovedaVacia());
      expect(estado.vacia, isTrue);
      expect(estado.cuadrada, isTrue);
      expect(estado.totalPedidos, 0);
    });
  });

  group('HU09 · Descuadres', () {
    test('CP-09.4 Detecta el descuadre con su pedido y su diferencia', () {
      final estado = EstadoBoveda.desdeJson(bovedaConDescuadre());
      expect(estado.cuadrada, isFalse);
      final d = estado.descuadres.single;
      expect(d.codigo, 'P-1003');
      expect(d.esperado, 0);
      expect(d.real, -276);
      expect(d.diferencia, -276);
      expect(d.explicacion, contains('posible pago repetido'));
      expect(estado.diferenciaTotal, -276);
    });

    test('CP-09.5 Sobra dinero: lo explica distinto', () {
      const d = Descuadre(
        pedidoId: 'p2',
        numero: 1004,
        titulo: 'Equipo',
        estado: EstadoPedido.pagoEnCustodia,
        esperado: 100,
        real: 150,
      );
      expect(d.diferencia, 50);
      expect(d.explicacion, contains('más dinero retenido'));
    });

    test('CP-09.6 Guarda los descuadres registrados con su fecha', () {
      final estado = EstadoBoveda.desdeJson(bovedaConDescuadre());
      final r = estado.descuadresRegistrados.single;
      expect(r.pedidos, 1);
      expect(r.revisadoEn, DateTime.parse('2026-11-11T19:30:00Z').toLocal());
    });
  });

  group('HU06 · Liberaciones pendientes en la bóveda', () {
    test('CP-09.7 Lee el motivo y los intentos', () {
      final l = EstadoBoveda.desdeJson(bovedaCuadrada()).liberacionesPendientes.single;
      expect(l.codigo, 'P-1009');
      expect(l.motivo, MotivoLiberacion.sinCuenta);
      expect(l.intentos, 2);
      expect(l.ultimoIntento, isNotNull);
    });
  });
}
