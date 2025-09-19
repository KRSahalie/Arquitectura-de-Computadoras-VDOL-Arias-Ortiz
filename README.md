## Proyecto 1: Visualizador de Datos con Ordenamiento para Linux 

# Proyecto: Gráfico de Barras en Ensamblador x86 (NASM)

## Descripción
Este proyecto consiste en desarrollar un programa en ensamblador x86 para Linux que:
1. Lee un archivo de configuración `config.ini`.
2. Lee un archivo de inventario `inventario.txt`.
3. Ordena alfabéticamente los productos.
4. Muestra un gráfico de barras en la terminal con colores ANSI y caracteres definidos en la configuración.

## Flujo del Programa
1. Leer y procesar `config.ini`.
2. Leer y procesar `inventario.txt`.
3. Ordenar los datos alfabéticamente.
4. Dibujar el gráfico con los parámetros.

## Archivos actuales
- `src/hola.asm`: primer programa de prueba en NASM (Hola Mundo).
- `src/color.asm`: ejemplo proporcionado por el profesor para imprimir texto con colores.
- `src/config.ini`: archivo de configuración de ejemplo.

## Cómo compilar y ejecutar
Ejemplo con `hola.asm`:
```bash
cd src
nasm -f elf64 hola.asm -o hola.o
ld hola.o -o hola
./hola

Ejemplo con color.asm:
cd src
nasm -f elf64 color.asm -o color.o
ld color.o -o color
./color


