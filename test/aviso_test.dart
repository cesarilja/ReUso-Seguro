// Pruebas unitarias de la HU10 · Avisos y monitor.
//
// Ejecutar con:  flutter test
import 'package:flutter_test/flutter_test.dart';
import 'package:reuso_seguro/models/aviso.dart';
import 'package:reuso_seguro/models/pedido.dart';

Map<String, dynamic> _fila(int id, {String? compradorVisto, String? vendedorVisto, String hora = '10'}) => {
      'id': id,
      'pedido_id': 'pedido-1',
      'estado': 'en_diagnostico',
      'mensaje_comprador': 'Comprador $id',
      'mensaje_vendedor': 'Vendedor $id',
      'creado_en': '2026-11-11T$hora:00:00Z',
      'comprador_visto_en': compradorVisto,
      'vendedor_visto_en': vendedorVisto,
      'pedidos': {
        'numero': 1001,
        'comprador_id': 'ana',
        'equipos': {'titulo': 'Laptop', 'vendedor_id': 'beto'},
      },
    };

void main() {
  test('CP-10.1 Lee el aviso con su pedido, su equipo y quién lo vio', () {
    final aviso = Aviso.desdeFila(_fila(1, compradorVisto: '2026-11-11T10:05:00Z'));
    expect(aviso.estado, EstadoPedido.enDiagnostico);
    expect(aviso.codigo, 'P-1001');
    expect(aviso.titulo, 'Laptop');
    expect(aviso.vistoPorComprador, isTrue);
    expect(aviso.vistoPorVendedor, isFalse);
    expect(aviso.vistoPorAmbos, isFalse);
  });

  test('CP-10.2 Cada quien recibe su mensaje y solo los que no ha visto', () {
    final avisos = [
      Aviso.desdeFila(_fila(1, compradorVisto: '2026-11-11T10:05:00Z', hora: '10')),
      Aviso.desdeFila(_fila(2, hora: '11')),
    ];
    final comprador = ReglasAvisos.pendientesDe('ana', avisos);
    expect(comprador.mensajes, ['Comprador 2']);
    expect(comprador.ids, [2]);

    final vendedor = ReglasAvisos.pendientesDe('beto', avisos);
    expect(vendedor.mensajes, ['Vendedor 1', 'Vendedor 2']);
    expect(vendedor.ids, [1, 2]);

    expect(ReglasAvisos.pendientesDe('otra', avisos).ids, isEmpty);
  });

  test('CP-10.3 Al volver, resume los avisos pendientes', () {
    final texto = ReglasAvisos.resumen(['A', 'B'], alVolver: true)!;
    expect(texto, startsWith('Mientras no estabas (2 avisos)'));
    expect(texto, contains('A\nB'));
    expect(ReglasAvisos.resumen(['A'], alVolver: false), 'A');
    expect(ReglasAvisos.resumen(const [], alVolver: true), isNull);
  });

  test('CP-10.4 Con muchos avisos muestra los 3 últimos y cuántos más', () {
    final texto = ReglasAvisos.resumen(['1', '2', '3', '4', '5'], alVolver: false)!;
    expect(texto, '3\n4\n5\n…y 2 más.');
  });
}
