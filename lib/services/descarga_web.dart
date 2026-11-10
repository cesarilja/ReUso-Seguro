import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Hace que el navegador descargue el archivo con ese nombre.
Future<void> descargarArchivo(Uint8List bytes, String nombre, String tipo) async {
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: tipo),
  );
  final url = web.URL.createObjectURL(blob);
  final enlace = web.HTMLAnchorElement()
    ..href = url
    ..download = nombre
    ..style.display = 'none';
  web.document.body?.appendChild(enlace);
  enlace.click();
  enlace.remove();
  web.URL.revokeObjectURL(url);
}
