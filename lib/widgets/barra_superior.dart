import 'package:flutter/material.dart';

import '../screens/mis_compras_screen.dart';
import '../screens/publicar_screen.dart';
import '../services/sesion_service.dart';
import '../tema.dart';
import 'avisos.dart';
import 'pegatina.dart';

/// Barra fija de arriba: el logo, el botón para publicar y la cuenta.
class BarraSuperior extends StatelessWidget {
  const BarraSuperior({
    super.key,
    this.alTocarLogo,
    this.mostrarAcciones = true,
  });

  /// Qué pasa al tocar el logo. En el catálogo no hace nada.
  final VoidCallback? alTocarLogo;

  /// En la pantalla de acceso solo se muestra el logo.
  final bool mostrarAcciones;

  Future<void> _publicar(BuildContext context) async {
    final listo = await asegurarSesion(context);
    if (!listo || !context.mounted) return;

    // HU11: abre el formulario para publicar un equipo.
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const PublicarScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ancho = MediaQuery.sizeOf(context).width;
    // En teléfonos los textos largos no caben.
    final corta = ancho < 640;
    final muyCorta = ancho < 400;

    return Container(
      height: 72,
      padding: EdgeInsets.symmetric(horizontal: margenLateral(context)),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: ColoresApp.tinta, width: 2),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: InkWell(
              onTap: alTocarLogo,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/images/logo.png',
                      width: 36,
                      height: 36,
                    ),
                    if (ancho >= 480 || !mostrarAcciones) ...[
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          'ReUso Seguro',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Tipos.subtitulo.copyWith(fontSize: 20),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          if (mostrarAcciones) ...[
            const SizedBox(width: 16),
            // Se vuelve a dibujar cada vez que alguien entra o sale.
            ListenableBuilder(
              listenable: SesionService.instancia,
              builder: (context, _) {
                final usuario = SesionService.instancia.usuario;

                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    BotonPegatina(
                      texto: corta ? 'Publicar' : 'Publicar un equipo',
                      principal: false,
                      compacto: muyCorta,
                      alTocar: () => _publicar(context),
                    ),
                    const SizedBox(width: 12),
                    if (usuario == null)
                      BotonPegatina(
                        texto: corta ? 'Entrar' : 'Iniciar sesión',
                        compacto: muyCorta,
                        alTocar: () => asegurarSesion(context),
                      )
                    else
                      _MenuUsuario(usuario: usuario),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

/// Círculo con la inicial del usuario. Al tocarlo abre el menú de la cuenta.
class _MenuUsuario extends StatelessWidget {
  const _MenuUsuario({required this.usuario});

  final Usuario usuario;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Tu cuenta',
      position: PopupMenuPosition.under,
      onSelected: (opcion) {
        if (opcion == 'compras') {
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const MisComprasScreen()),
          );
        }
        if (opcion == 'salir') SesionService.instancia.cerrarSesion();
      },
      itemBuilder: (context) => <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(usuario.nombre, style: Tipos.subtitulo.copyWith(fontSize: 15)),
              Text(usuario.correo, style: Tipos.pequeno),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'compras',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.receipt_long_outlined),
            title: Text('Mis compras'),
          ),
        ),
        const PopupMenuItem<String>(
          value: 'salir',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.logout),
            title: Text('Cerrar sesión'),
          ),
        ),
      ],
      child: Container(
        width: 46,
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: ColoresApp.cielo,
          shape: BoxShape.circle,
          border: Border.all(color: ColoresApp.tinta, width: 2),
        ),
        child: Text(
          usuario.inicial,
          style: Tipos.subtitulo.copyWith(fontSize: 18),
        ),
      ),
    );
  }
}
