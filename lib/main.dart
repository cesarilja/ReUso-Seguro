import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'configuracion.dart';
import 'screens/catalogo_screen.dart';
import 'services/avisos_service.dart';
import 'services/tiempo_real_service.dart';
import 'services/vendedor_service.dart';
import 'tema.dart';
import 'widgets/avisos.dart';

Future<void> main() async {
  // Hace falta antes de usar Supabase, que se conecta al arrancar.
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: Configuracion.supabaseUrl,
    publishableKey: Configuracion.supabaseClave,
  );

  // Cambios en tiempo real: la app se actualiza sola, sin recargar.
  TiempoRealService.instancia.iniciar();

  // HU04: insignia de ventas nuevas del vendedor.
  VendedorService.instancia.iniciar();

  // HU10: avisos de cada cambio de estado (al comprador y al vendedor), en
  // cualquier pantalla. Al entrar se ven los que llegaron mientras no estaba.
  AvisosService.instancia.iniciar();
  AvisosService.instancia.avisos.listen(mostrarAvisoGlobal);

  runApp(const ReUsoSeguroApp());
}

/// Punto de entrada de la app: define el tema y la primera pantalla.
class ReUsoSeguroApp extends StatelessWidget {
  const ReUsoSeguroApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ReUso Seguro',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: avisosGlobales,
      theme: temaApp(),
      // El catálogo es público: se ve sin iniciar sesión.
      home: const CatalogoScreen(),
    );
  }
}
