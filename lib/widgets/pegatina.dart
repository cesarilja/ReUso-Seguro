import 'package:flutter/material.dart';

import '../tema.dart';

/// Caja con borde oscuro y sombra dura, como una pegatina.
///
/// Es el estilo que identifica a la app: lo usan las tarjetas, los botones
/// y los recuadros. Si recibe [alTocar], responde al pasar el mouse.
class Pegatina extends StatefulWidget {
  const Pegatina({
    super.key,
    required this.child,
    this.alTocar,
    this.color = Colors.white,
    this.colorSombra = ColoresApp.tinta,
    this.radio = 18,
    this.sombra = 5,
  });

  final Widget child;
  final VoidCallback? alTocar;
  final Color color;
  final Color colorSombra;
  final double radio;
  final double sombra;

  @override
  State<Pegatina> createState() => _PegatinaState();
}

class _PegatinaState extends State<Pegatina> {
  bool _conMouse = false;
  bool _conFoco = false;

  @override
  Widget build(BuildContext context) {
    final sePuedeTocar = widget.alTocar != null;
    final resaltada = sePuedeTocar && (_conMouse || _conFoco);
    final sombra = resaltada ? widget.sombra + 2 : widget.sombra;
    final radioInterior = BorderRadius.circular(widget.radio - 2);

    final contenido = ClipRRect(
      borderRadius: radioInterior,
      child: widget.child,
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      decoration: BoxDecoration(
        color: widget.color,
        borderRadius: BorderRadius.circular(widget.radio),
        border: Border.all(color: ColoresApp.tinta, width: 2),
        boxShadow: [
          BoxShadow(
            color: resaltada ? ColoresApp.orquidea : widget.colorSombra,
            offset: Offset(sombra, sombra),
          ),
        ],
      ),
      child: sePuedeTocar
          ? Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: widget.alTocar,
                onHover: (valor) => setState(() => _conMouse = valor),
                onFocusChange: (valor) => setState(() => _conFoco = valor),
                borderRadius: radioInterior,
                child: contenido,
              ),
            )
          : contenido,
    );
  }
}

/// Botón con el estilo de pegatina.
///
/// El principal es oscuro con sombra morada; el secundario es blanco.
class BotonPegatina extends StatelessWidget {
  const BotonPegatina({
    super.key,
    required this.texto,
    required this.alTocar,
    this.icono,
    this.principal = true,
    this.expandido = false,
    this.compacto = false,
  });

  final String texto;
  final VoidCallback alTocar;
  final IconData? icono;
  final bool principal;

  /// Si es verdadero, ocupa todo el ancho disponible.
  final bool expandido;

  /// Si es verdadero, usa menos espacio a los lados (pantallas pequeñas).
  final bool compacto;

  @override
  Widget build(BuildContext context) {
    final colorTexto = principal ? Colors.white : ColoresApp.tinta;

    return Pegatina(
      alTocar: alTocar,
      color: principal ? ColoresApp.tinta : Colors.white,
      colorSombra: principal ? ColoresApp.orquidea : ColoresApp.tinta,
      radio: 14,
      sombra: 4,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compacto ? 14 : 22,
          vertical: 13,
        ),
        child: Row(
          mainAxisSize: expandido ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icono != null) ...[
              Icon(icono, size: 20, color: colorTexto),
              const SizedBox(width: 8),
            ],
            Text(texto, style: Tipos.boton.copyWith(color: colorTexto)),
          ],
        ),
      ),
    );
  }
}
