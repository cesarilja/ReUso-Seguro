import '../models/equipo.dart';

/// Entrega los equipos del catálogo.
///
/// Por ahora devuelve datos de prueba. Cuando conectemos una base de datos,
/// solo hay que cambiar este archivo: las pantallas no se enteran.
class CatalogoService {
  const CatalogoService();

  List<Equipo> obtenerEquipos() => _equiposDePrueba;
}

const String _carpeta = 'assets/images/equipos';

const List<Equipo> _equiposDePrueba = [
  Equipo(
    id: 'eq-01',
    titulo: 'Laptop Lenovo ThinkPad T480',
    descripcion:
        'Core i5 de 8va generación, 8 GB de RAM y SSD de 256 GB. '
        'Incluye cargador original.',
    estadoDeclarado: 'Usado, en buen estado. Batería con 2 horas de duración.',
    precio: 180.0,
    imagen: '$_carpeta/thinkpad.png',
    vendedor: 'Andrea Rivas',
  ),
  Equipo(
    id: 'eq-02',
    titulo: 'iPhone 11 de 64 GB',
    descripcion: 'Color negro, liberado para cualquier operadora. Con forro.',
    estadoDeclarado: 'Usado, con detalles leves en el marco.',
    precio: 210.0,
    imagen: '$_carpeta/iphone.png',
    vendedor: 'Luis Paredes',
  ),
  Equipo(
    id: 'eq-03',
    titulo: 'iPad de 6ta generación',
    descripcion: 'Pantalla de 9,7 pulgadas, 32 GB, solo WiFi.',
    estadoDeclarado: 'Usado, pantalla sin rayones.',
    precio: 150.0,
    imagen: '$_carpeta/ipad.png',
    vendedor: 'Mariana Colmenares',
    estado: EstadoPublicacion.reservado,
  ),
  Equipo(
    id: 'eq-04',
    titulo: 'MacBook Air 2017',
    descripcion: 'Core i5, 8 GB de RAM y SSD de 128 GB. Teclado en español.',
    estadoDeclarado: 'Usado, con marcas de uso en la tapa.',
    precio: 320.0,
    imagen: '$_carpeta/macbook.png',
    vendedor: 'Andrea Rivas',
  ),
  Equipo(
    id: 'eq-05',
    titulo: 'Samsung Galaxy A52',
    descripcion: '128 GB de almacenamiento y 6 GB de RAM. Doble SIM.',
    estadoDeclarado: 'Usado, funciona todo.',
    precio: 120.0,
    imagen: '$_carpeta/galaxy.png',
    vendedor: 'José Graterol',
  ),
  Equipo(
    id: 'eq-06',
    titulo: 'PlayStation 4 Slim de 500 GB',
    descripcion: 'Incluye un control, cable de corriente y cable HDMI.',
    estadoDeclarado: 'Usado, el control tiene desgaste en las palancas.',
    precio: 160.0,
    imagen: '$_carpeta/ps4.png',
    vendedor: 'Luis Paredes',
  ),
  Equipo(
    id: 'eq-07',
    titulo: 'Laptop HP Pavilion 15',
    descripcion: 'Ryzen 5, 12 GB de RAM y SSD de 512 GB.',
    estadoDeclarado: 'Usado, como nuevo.',
    precio: 240.0,
    imagen: '$_carpeta/hp.png',
    vendedor: 'Mariana Colmenares',
    estado: EstadoPublicacion.reservado,
  ),
  Equipo(
    id: 'eq-08',
    titulo: 'Audífonos Sony WH-CH710N',
    descripcion: 'Inalámbricos, con cancelación de ruido. Incluye cable USB.',
    estadoDeclarado: 'Usado, almohadillas en buen estado.',
    precio: 45.0,
    imagen: '$_carpeta/audifonos.png',
    vendedor: 'José Graterol',
  ),
];
