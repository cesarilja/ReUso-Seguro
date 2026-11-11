import '../formato.dart';
import 'pedido.dart';

/// Dónde y cuándo se lleva un equipo al Hub (HU04, escenario 2).
///
/// Son datos de DEMOSTRACIÓN del proyecto universitario.
class DatosDelHub {
  const DatosDelHub._();

  static const String nombre = 'Hub de inspección ReUso Seguro';
  static const String direccion =
      'Universidad Metropolitana, Edificio de Ingeniería, planta baja. '
      'Caracas (dirección de demostración)';
  static const String horario = 'Lunes a viernes, de 8:00 a. m. a 4:00 p. m.';
}

/// La cuenta donde el vendedor recibe su dinero (HU06, SIMULADA).
class CuentaCobro {
  const CuentaCobro({
    required this.banco,
    required this.telefono,
    required this.cedula,
    required this.titular,
  });

  factory CuentaCobro.desdeFila(Map<String, dynamic> fila) => CuentaCobro(
        banco: fila['banco'] as String,
        telefono: fila['telefono'] as String,
        cedula: fila['cedula'] as String,
        titular: fila['titular'] as String,
      );

  final String banco;
  final String telefono;
  final String cedula;
  final String titular;

  /// Teléfono con los últimos 4 dígitos visibles: 0414 ••• 4567.
  String get telefonoOculto {
    if (telefono.length < 8) return telefono;
    return '${telefono.substring(0, 4)} ••• ${telefono.substring(telefono.length - 4)}';
  }
}

/// Reglas de las ventas del vendedor (HU04 y HU06). No dependen de la
/// pantalla, así que se prueban con pruebas unitarias.
class ReglasVenta {
  const ReglasVenta._();

  /// Número de la insignia de «Mis ventas»: ventas pagadas sin ver.
  static int contarNuevas(Iterable<Pedido> ventas) =>
      ventas.where((v) => v.esVentaNueva).length;

  /// Avisos para el vendedor cuando cambian sus ventas en vivo:
  /// una venta nueva, un pago liberado o una liberación pendiente.
  ///
  /// [antes] es el estado de cada venta en la carga anterior. En la
  /// primera carga no se avisa nada (para eso está la insignia).
  static List<String> avisosDeCambio(
    Map<String, EstadoPedido>? antes,
    Iterable<Pedido> ahora,
  ) {
    if (antes == null) return const [];
    final avisos = <String>[];
    for (final venta in ahora) {
      final titulo = venta.equipo.titulo;
      final anterior = antes[venta.id];
      if (anterior == null) {
        if (venta.estado == EstadoPedido.pagoEnCustodia) {
          avisos.add('Te compraron «$titulo». El pago está en custodia: ya '
              'puedes llevarlo al Hub.');
        }
        continue;
      }
      if (anterior == venta.estado) continue;
      if (venta.estado == EstadoPedido.pagoLiberado) {
        avisos.add('Te liberamos el pago de «$titulo»: recibes '
            '${formatearDolares(venta.recibeVendedor)}.');
      } else if (venta.estado == EstadoPedido.liberacionPendiente) {
        avisos.add('No pudimos transferirte el pago de «$titulo». Revisa '
            '«Mis ventas».');
      }
    }
    return avisos;
  }
}
