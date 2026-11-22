// Pruebas unitarias de la HU20 (reputación del vendedor).
//
// Las mismas reglas se prueban en el servidor con
// supabase/pruebas/16_verificar_reputacion.sql.
//
// Ejecutar con:  flutter test
import 'package:flutter_test/flutter_test.dart';
import 'package:reuso_seguro/models/pedido.dart';
import 'package:reuso_seguro/models/reputacion.dart';

import 'datos_de_prueba.dart';

NivelVendedor _nivel(int ventas, int aprobadas, {int inexactas = 0, double? dias}) =>
    ReglasReputacion.nivel(
      ventas: ventas,
      aprobadas: aprobadas,
      inexactasRecientes: inexactas,
      diasEntrega: dias,
    );

void main() {
  group('HU20 · Niveles', () {
    test('CP-20.1 Con menos de 3 ventas es «nuevo»', () {
      expect(_nivel(0, 0), NivelVendedor.nuevo);
      expect(_nivel(2, 2), NivelVendedor.nuevo);
    });

    test('CP-20.2 Con 3 aprobadas y sin declaraciones inexactas es «confiable»', () {
      expect(_nivel(3, 3), NivelVendedor.confiable);
      // 9 de 10 es justo el 90 %.
      expect(_nivel(10, 9, dias: 5), NivelVendedor.confiable);
    });

    test('CP-20.3 Una declaración inexacta le quita el nivel', () {
      expect(_nivel(3, 3, inexactas: 1), NivelVendedor.vendedor);
    });

    test('CP-20.4 Menos del 90 % aprobadas no llega a confiable', () {
      expect(_nivel(4, 3), NivelVendedor.vendedor);
    });

    test('CP-20.5 «Destacado» pide 10 ventas, 95 % y entregar en 2 días', () {
      expect(_nivel(10, 10, dias: 1.5), NivelVendedor.destacado);
      expect(_nivel(10, 10, dias: 2.5), NivelVendedor.confiable);
      expect(_nivel(10, 10), NivelVendedor.confiable); // sin datos de entrega
      expect(_nivel(20, 18, dias: 1), NivelVendedor.confiable); // 90 %
    });
  });

  group('HU20 · Comisión según el nivel', () {
    test('CP-20.6 Confiable y Destacado pagan 4 %; los demás 5 %', () {
      expect(ReglasReputacion.tasaComision(NivelVendedor.nuevo), 0.05);
      expect(ReglasReputacion.tasaComision(NivelVendedor.vendedor), 0.05);
      expect(ReglasReputacion.tasaComision(NivelVendedor.confiable), 0.04);
      expect(ReglasReputacion.tasaComision(NivelVendedor.destacado), 0.04);
    });

    test('CP-20.7 El desglose de la venta usa la tasa del nivel', () {
      final venta = pedidoDePrueba(EstadoPedido.enDiagnostico);
      expect(venta.comisionEstimadaCon(0.04), 10);
      expect(venta.recibeVendedorCon(0.04), 240);
      // Si ya se liberó, vale lo que cobró el servidor.
      final liberada = Pedido.desdeFila({
        'id': 'pedido-1',
        'numero': 1001,
        'comprador_id': 'comprador-1',
        'monto': 250,
        'creado_en': '2026-11-10T14:00:00Z',
        'estado': 'pago_liberado',
        'comision': 12.5,
        'monto_vendedor': 237.5,
      }, laptopDePrueba);
      expect(liberada.comisionEstimadaCon(0.04), 12.5);
    });
  });

  group('HU20 · Lo que ve la persona', () {
    test('CP-20.8 Lee la respuesta del servidor', () {
      final reputacion = Reputacion.desdeJson({
        'vendedor_id': 'v1',
        'ventas': 10,
        'aprobadas': 9,
        'inexactas_recientes': 0,
        'dias_entrega': 1.5,
        'nivel': 'confiable',
      });
      expect(reputacion.nivel, NivelVendedor.confiable);
      expect(reputacion.porcentajeAprobadas, 90);
      expect(reputacion.textoAprobadas, '9 de 10 equipos aprobados');
      expect(reputacion.textoEntrega, '1,5 días');
      expect(reputacion.tasaComision, 0.04);
      expect(NivelVendedor.desde('otro'), NivelVendedor.nuevo);
    });

    test('CP-20.9 Le dice al vendedor qué le falta para subir', () {
      const nuevo = Reputacion(vendedorId: 'v1', ventas: 1, aprobadas: 1);
      expect(nuevo.queFalta, contains('faltan 2 ventas'));

      const conInexacta = Reputacion(
        vendedorId: 'v1',
        ventas: 4,
        aprobadas: 4,
        inexactasRecientes: 1,
        nivel: NivelVendedor.vendedor,
      );
      expect(conInexacta.queFalta, contains('declaración inexacta'));
      expect(conInexacta.queFalta, isNot(contains('90 %')));

      const destacado = Reputacion(
        vendedorId: 'v1',
        ventas: 12,
        aprobadas: 12,
        nivel: NivelVendedor.destacado,
      );
      expect(destacado.queFalta, isNull);
    });
  });
}
