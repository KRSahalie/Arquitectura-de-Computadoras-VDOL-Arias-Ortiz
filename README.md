# Visualizador de Datos con Ordenamiento para Linux (Ensamblador x86-64)

**Autor:** Kendy Raquel Arias Ortiz  
**Fecha:** 22/09/2025  

## Descripción del Proyecto

Este proyecto consiste en un programa desarrollado en **lenguaje ensamblador x86-64 (NASM)** para **Linux**. Su objetivo es:

- Leer datos de inventario desde archivos de texto.
- Ordenarlos alfabéticamente.
- Generar un **gráfico de barras visualmente atractivo** directamente en la terminal, utilizando **códigos de escape ANSI** para personalizar colores y caracteres.

El programa demuestra control de bajo nivel sobre la memoria y las llamadas al sistema (**syscalls**) de Linux, sin depender de bibliotecas externas de alto nivel.

## Características Principales

- **Lectura de archivos:**
  - `inventario.txt`: Contiene nombres y cantidades de los productos.
  - `config.ini`: Permite personalizar el estilo del gráfico (carácter y colores).
  
- **Algoritmo de Ordenamiento:**  
  La lista de productos se ordena alfabéticamente utilizando **Bubble Sort** implementado en ensamblador.

- **Visualización en la Terminal:**  
  Muestra un gráfico de barras dinámico, donde la longitud de cada barra representa la cantidad del producto.

- **Personalización:**  
  Los colores y el carácter de la barra se pueden modificar fácilmente editando `config.ini`, sin necesidad de recompilar.

## Archivos de Entrada

### inventario.txt
Ejemplo de contenido:
```
manzanas:12
peras:8
naranjas:25
kiwis:5
piñas:3
```
### config.ini
Ejemplo de contenido:
```
caracter_barra:█
color_barra:92
color_fondo:40
```
## Compilación y Ejecución

Asegúrate de tener **NASM** y **ld** instalados en Linux.

### 1. Preparación
Coloca los siguientes archivos en el mismo directorio:

- `inventario_final.asm`(archivo principal)
- `inventario.txt`
- `config.ini`

### 2. Compilación
Abre una terminal en el directorio del proyecto y ejecuta:

```bash
nasm -f elf64 inventario_final.asm -o inventario_final.o
ld inventario_final.o -o inventario_final
```

### 3. Ejecución

Después de compilar, ejecuta:

```bash
./inventario_final
```

El programa leerá los archivos y mostrará el gráfico de barras ordenado en la terminal.
```
kiwis:    █████5
manzanas: ██████████████████████████████30
naranjas: █████████████████████████25
peras:    ████████8
piñas:    ███3
```

