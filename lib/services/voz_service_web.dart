import 'dart:js_interop';

@JS('reusoAccesibilidad')
external _ReusoAccesibilidadJS? get _puente;

extension type _ReusoAccesibilidadJS(JSObject _) implements JSObject {
  external void anunciar(JSString texto);
  external JSBoolean soportaLectura();
  external JSBoolean leerEnVozAlta(JSString texto);
  external void detenerLectura();
  external JSBoolean soportaDictado();
  external JSBoolean iniciarDictado(
    JSFunction onResultado,
    JSFunction onError,
    JSFunction onFin,
  );
  external void detenerDictado();
}

bool soportaDictado() => _puente?.soportaDictado().toDart ?? false;

bool soportaLectura() => _puente?.soportaLectura().toDart ?? false;

void anunciar(String texto) {
  _puente?.anunciar(texto.toJS);
}

bool leerEnVozAlta(String texto) {
  return _puente?.leerEnVozAlta(texto.toJS).toDart ?? false;
}

void detenerLectura() {
  _puente?.detenerLectura();
}

bool iniciarDictado({
  required void Function(String texto) alRecibirTexto,
  required void Function(String error) alFallar,
  required void Function() alTerminar,
}) {
  final puente = _puente;
  if (puente == null) {
    alTerminar();
    return false;
  }
  return puente
      .iniciarDictado(
        ((JSString t) => alRecibirTexto(t.toDart)).toJS,
        ((JSString e) => alFallar(e.toDart)).toJS,
        (() => alTerminar()).toJS,
      )
      .toDart;
}

void detenerDictado() {
  _puente?.detenerDictado();
}
