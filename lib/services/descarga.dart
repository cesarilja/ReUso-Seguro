/// Descarga un archivo hecho en la app (por ejemplo, el PDF del
/// certificado). En la web lo baja el navegador; en las pruebas no hace
/// falta, por eso cada plataforma tiene su versión.
library;

export 'descarga_otras.dart' if (dart.library.js_interop) 'descarga_web.dart';
