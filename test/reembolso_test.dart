// Pruebas unitarias de la HU13 · Reembolso por equipo rechazado.
//
// Ejecutar desde la carpeta del proyecto con:  flutter test
//
// Revisan las reglas de negocio que ve el usuario: si el equipo no pasa la
// inspección, el comprador recupera el 100 % y nadie cobra comisión.
import 'package:flutter_test/flutter_test.dart';
import 'package:reuso_seguro/models/equipo.dart';
import 'package:reuso_seguro/models/pedido.dart';

const _equipo = Equipo(
  id: 'equipo-1',
  titulo: 'Laptop de prueba',
  descripcion: 'Equipo usado para las pruebas unitarias del reembolso.',
  estadoDeclarado: 'Usado, en buen estado.',
  precio: 250,
  vendedor: 'Vendedor de prueba',
);

/// Una fila como la que devuelve Supabase de la tabla `pedidos`.
Map<String, dynamic> _fila(Map<String, dynamic> cambios) => {
      'id': 'pedido-1',
      'numero': 1001,
      'comprador_id': 'comprador-1',
      'monto': 250,
      'creado_en': '2026-11-03T14:00:00Z',
      'estado': 'pago_en_custodia',
      'metodo_pago': 'pago_movil',
      'referencia': 'RS-261103-1001',
      'pagado_en': '2026-11-03T14:05:00Z',
      ...cambios,
    };

void main() {
  group('HU13 · Reembolso del pedido', () {
    test('CP-13.1 Un pedido reembolsado devuelve el 100 % del monto', () {
      final pedido = Pedido.desdeFila(
        _fila({
          'estado': 'reembolsado',
          'monto_reembolsado': 250,
          'comision': 0,
          'monto_vendedor': 0,
          'reembolsado_en': '2026-11-05T10:00:00Z',
          'referencia_reembolso': 'RE-261105-1001',
        }),
        _equipo,
      );

      expect(pedido.estado, EstadoPedido.reembolsado);
      expect(pedido.fueReembolsado, isTrue);
      expect(pedido.montoADevolver, pedido.monto);
      expect(pedido.montoADevolver, 250);
      expect(pedido.referenciaReembolso, 'RE-261105-1001');
      expect(pedido.reembolsadoEn, isNotNull);
    });

    test('CP-13.2 Si el equipo se rechaza no se cobra comisión', () {
      final reembolsado = Pedido.desdeFila(
        _fila({'estado': 'reembolsado', 'comision': 0, 'monto_vendedor': 0}),
        _equipo,
      );
      // Aunque el servidor todavía no haya hecho el reembolso.
      final rechazado = Pedido.desdeFila(_fila({'estado': 'rechazado'}), _equipo);

      for (final pedido in [reembolsado, rechazado]) {
        expect(pedido.noPasoInspeccion, isTrue);
        expect(pedido.comisionEstimada, 0);
        expect(pedido.recibeVendedor, 0);
        expect(pedido.pagoLiberado, isFalse);
      }
    });

    test('CP-13.3 Mientras se procesa, se muestra el monto completo', () {
      final pedido = Pedido.desdeFila(_fila({'estado': 'rechazado'}), _equipo);

      expect(pedido.fueReembolsado, isFalse);
      expect(pedido.montoADevolver, 250);
    });

    test('CP-13.4 Un pedido aprobado sí cobra el 8 % (no se rompe la HU06)', () {
      final pedido = Pedido.desdeFila(_fila({'estado': 'aprobado'}), _equipo);

      expect(pedido.noPasoInspeccion, isFalse);
      expect(pedido.comisionEstimada, 20);
      expect(pedido.recibeVendedor, 230);
    });
  });
}
