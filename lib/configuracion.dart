/// Datos para conectarse al proyecto de Supabase.
///
/// La clave "publishable" está hecha para ir dentro de la app, así que no
/// hay problema en que esté aquí. Las claves secretas ("secret keys") nunca
/// se ponen en el código de la app.
class Configuracion {
  Configuracion._();

  static const String supabaseUrl = 'https://nfmfqnxhueqmhprewlqx.supabase.co';

  static const String supabaseClave =
      'sb_publishable_-zHmNo5ayR7gAvvPKH197g_6qEuZA3v';
}
