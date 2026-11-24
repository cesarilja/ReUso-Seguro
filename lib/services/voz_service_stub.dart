/// Implementación de respaldo para plataformas sin DOM (pruebas unitarias/VM).
bool soportaDictado() => false;

bool soportaLectura() => false;

void anunciar(String texto) {}

bool leerEnVozAlta(String texto) => false;

void detenerLectura() {}

bool iniciarDictado({
  required void Function(String texto) alRecibirTexto,
  required void Function(String error) alFallar,
  required void Function() alTerminar,
}) {
  alTerminar();
  return false;
}

void detenerDictado() {}
