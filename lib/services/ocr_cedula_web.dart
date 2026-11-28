import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

@JS('reusoOcr')
external _ReusoOcrJS? get _puente;

extension type _ReusoOcrJS(JSObject _) implements JSObject {
  external JSBoolean disponible();
  external JSPromise<JSString> leerTextoCedula(JSString dataUrl);
}

bool disponible() => _puente?.disponible().toDart ?? false;

Future<String> leerTexto(Uint8List bytes, String mimeType) async {
  final puente = _puente;
  if (puente == null || !puente.disponible().toDart) {
    throw StateError('OCR_NO_DISPONIBLE');
  }
  final dataUrl = 'data:$mimeType;base64,${base64Encode(bytes)}';
  final resultado = await puente.leerTextoCedula(dataUrl.toJS).toDart;
  return resultado.toDart;
}
