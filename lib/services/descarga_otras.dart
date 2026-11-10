import 'dart:typed_data';

/// Fuera del navegador (por ejemplo, al correr `flutter test`) no hay a
/// dónde descargar.
Future<void> descargarArchivo(Uint8List bytes, String nombre, String tipo) async {
  throw UnsupportedError('La descarga de archivos solo está disponible en la web.');
}
