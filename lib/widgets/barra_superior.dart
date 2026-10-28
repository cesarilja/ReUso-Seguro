import 'package:flutter/material.dart';

import '../screens/publicar_screen.dart';
import '../services/inspeccion_service.dart';
import '../services/sesion_service.dart';
import '../tema.dart';
import 'avisos.dart';
import 'navegacion.dart';
import 'pegatina.dart';

/// Barra fija de arriba: el logo, las secciones, el botón para publicar y
/// la cuenta.
///
/// En pantallas anchas las secciones se ven como enlaces (la actual queda
/// subrayada, para que la persona sepa dónde está). En pantallas angostas
/// se juntan en el botón «Menú».
class BarraSuperior extends StatelessWidget {
  const BarraSuperior({
    super.key,
    this.alTocarLogo,
    this.mostrarAcciones = true,
    this.seccion,
  });

  /// Qué pasa al tocar el logo. Si no se indica, vuelve al inicio.
  final VoidCallback? alTocarLogo;

  /// En la pantalla de acceso solo se muestra el logo.
  final bool mostrarAcciones;

  /// La sección en la que está la persona (se marca en la barra).
  final Seccion? seccion;

  Future<void> _publicar(BuildContext context) async {
    final listo = await asegurarSesion(context);
    if (!listo || !context.mounted) return;

    // HU11: abre el formulario para publicar un equipo.
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const PublicarScreen()),
    );
  }

  /// Las secciones que le corresponden a esta persona.
  static List<Seccion> seccionesVisibles() {
    final conSesion = SesionService.instancia.haySesion;
    return [
      Seccion.inicio,
      Seccion.comoFunciona,
      if (conSesion) Seccion.compras,
      if (conSesion) Seccion.ventas,
      if (conSesion && InspeccionService.instancia.soyInspector) Seccion.hub,
    ];
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
      child: ListenableBuilder(
        // Se vuelve a dibujar cada vez que alguien entra o sale.
        listenable: Listenable.merge([
          SesionService.instancia,
          InspeccionService.instancia,
        ]),
        builder: (context, _) => LayoutBuilder(
          builder: (context, limites) {
            final usuario = SesionService.instancia.usuario;
            final secciones = seccionesVisibles();
            final mostrarNombre = ancho >= 520 || !mostrarAcciones;

            // Todas las secciones van en la barra. Si no caben, la barra se
            // va compactando por niveles antes de recurrir al «Menú»
            // (que solo queda para tablets y teléfonos):
            //   1. todo completo, con íconos;
            //   2. el botón dice solo «Publicar»;
            //   3. además, los enlaces van sin ícono y más juntos.
            // El nombre «ReUso Seguro» nunca se corta.
            double anchoEnlaces({required bool conIcono}) =>
                secciones.fold<double>(
                  0,
                  (suma, s) => suma + s.nombre.length * 9 + (conIcono ? 52 : 26),
                );
            double anchoFijo({required bool publicarCorto}) =>
                (mostrarNombre ? 200 : 50) +
                20 +
                (publicarCorto ? 150 : 250) +
                12 +
                (usuario == null ? 170 : 80);
            final disponible = limites.maxWidth;

            var publicarCorto = corta;
            var conIcono = true;
            var enlaces = false;
            if (mostrarAcciones && !corta) {
              if (disponible >=
                  anchoFijo(publicarCorto: false) +
                      anchoEnlaces(conIcono: true)) {
                enlaces = true;
              } else if (disponible >=
                  anchoFijo(publicarCorto: true) +
                      anchoEnlaces(conIcono: true)) {
                enlaces = true;
                publicarCorto = true;
              } else if (disponible >=
                  anchoFijo(publicarCorto: true) +
                      anchoEnlaces(conIcono: false)) {
                enlaces = true;
                publicarCorto = true;
                conIcono = false;
              } else {
                publicarCorto = true;
              }
            }

            final logo = InkWell(
              onTap: alTocarLogo ?? () => irA(context, Seccion.inicio),
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
                    if (mostrarNombre) ...[
                      const SizedBox(width: 10),
                      Text(
                        'ReUso Seguro',
                        maxLines: 1,
                        softWrap: false,
                        style: Tipos.subtitulo.copyWith(fontSize: 20),
                      ),
                    ],
                  ],
                ),
              ),
            );

            return Row(
              children: [
                logo,
                if (enlaces) ...[
                  const SizedBox(width: 20),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final s in secciones)
                              _Enlace(
                                seccion: s,
                                activa: s == seccion,
                                conIcono: conIcono,
                                alTocar: () => irA(context, s),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ] else
                  const Spacer(),
                if (mostrarAcciones) ...[
                  if (!enlaces) ...[
                    _MenuSecciones(
                      secciones: secciones,
                      actual: seccion,
                      compacto: corta,
                    ),
                    const SizedBox(width: 8),
                  ],
                  BotonPegatina(
                    texto: publicarCorto ? 'Publicar' : 'Publicar un equipo',
                    icono: muyCorta ? null : Icons.add,
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
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Un enlace de la barra. La sección actual va en negrita y subrayada.
class _Enlace extends StatelessWidget {
  const _Enlace({
    required this.seccion,
    required this.activa,
    required this.alTocar,
    this.conIcono = true,
  });

  final Seccion seccion;
  final bool activa;
  final VoidCallback alTocar;

  /// En pantallas medianas el enlace va sin ícono para que quepan todos.
  final bool conIcono;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: activa,
      child: InkWell(
        onTap: alTocar,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 72,
          padding: EdgeInsets.symmetric(horizontal: conIcono ? 12 : 9),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: activa ? ColoresApp.orquidea : Colors.transparent,
                width: 4,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (conIcono) ...[
                Icon(
                  seccion.icono,
                  size: 19,
                  color: activa ? ColoresApp.tinta : ColoresApp.pizarra,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                seccion.nombre,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: activa ? FontWeight.w700 : FontWeight.w500,
                  color: activa ? ColoresApp.tinta : ColoresApp.pizarra,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// En pantallas angostas, las secciones se abren desde este botón.
class _MenuSecciones extends StatelessWidget {
  const _MenuSecciones({
    required this.secciones,
    required this.actual,
    required this.compacto,
  });

  final List<Seccion> secciones;
  final Seccion? actual;

  /// En teléfonos solo se ve el ícono.
  final bool compacto;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<Seccion>(
      tooltip: 'Menú',
      position: PopupMenuPosition.under,
      onSelected: (s) => irA(context, s),
      itemBuilder: (context) => [
        for (final s in secciones)
          PopupMenuItem<Seccion>(
            value: s,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(s.icono, color: ColoresApp.tinta),
              title: Text(
                s.nombre,
                style: TextStyle(
                  fontWeight: s == actual ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              trailing: s == actual
                  ? const Icon(Icons.check, color: ColoresApp.orquidea)
                  : null,
            ),
          ),
      ],
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ColoresApp.tinta, width: 2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.menu, color: ColoresApp.tinta),
            if (!compacto) ...[
              const SizedBox(width: 4),
              const Text(
                'Menú',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: ColoresApp.tinta,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Círculo con la inicial y una flecha, para que se note que es un menú
/// (heurística 6, hallazgo del taller de UX).
class _MenuUsuario extends StatelessWidget {
  const _MenuUsuario({required this.usuario});

  final Usuario usuario;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Tu cuenta',
      position: PopupMenuPosition.under,
      onSelected: (opcion) {
        if (opcion == 'compras') irA(context, Seccion.compras);
        if (opcion == 'ventas') irA(context, Seccion.ventas);
        if (opcion == 'hub') irA(context, Seccion.hub);
        if (opcion == 'salir') {
          SesionService.instancia.cerrarSesion();
          Navigator.of(context).popUntil((ruta) => ruta.isFirst);
        }
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
        if (InspeccionService.instancia.soyInspector)
          const PopupMenuItem<String>(
            value: 'hub',
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.fact_check_outlined),
              title: Text('Panel del Hub'),
            ),
          ),
        const PopupMenuItem<String>(
          value: 'compras',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.shopping_bag_outlined),
            title: Text('Mis compras'),
          ),
        ),
        const PopupMenuItem<String>(
          value: 'ventas',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.sell_outlined),
            title: Text('Mis ventas'),
          ),
        ),
        const PopupMenuDivider(),
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
        height: 46,
        padding: const EdgeInsets.only(left: 3, right: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: ColoresApp.tinta, width: 2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: ColoresApp.cielo,
              child: Text(
                usuario.inicial,
                style: Tipos.subtitulo.copyWith(fontSize: 16),
              ),
            ),
            const SizedBox(width: 2),
            const Icon(Icons.arrow_drop_down, color: ColoresApp.tinta),
          ],
        ),
      ),
    );
  }
}
