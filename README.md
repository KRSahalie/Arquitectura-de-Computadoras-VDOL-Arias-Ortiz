# Proyecto 1: Visualizador de Datos con Ordenamiento para Linux
## Gráfico de Barras en Ensamblador x86 (NASM)

---

## 📋 Descripción
Este proyecto implementa un programa en **ensamblador x86 (NASM)** que:
1. Lee un archivo de configuración `config.ini`.
2. Lee un archivo de inventario `inventario.txt`.
3. Ordena los productos alfabéticamente.
4. Dibuja un **gráfico de barras** en la terminal usando **códigos de color ANSI** y el **carácter de barra** definido en el archivo de configuración.

El objetivo es reforzar conceptos de **manejo de archivos**, **ordenamiento** y **formato de salida** en bajo nivel.

---

## 🚀 Flujo del Programa
1. **Leer y procesar `config.ini`**  
   - Obtiene:  
     - `caracter_barra`: carácter para las barras (`█`, `*`, etc.).  
     - `color_barra`: código ANSI del color del texto (ej. `92` = verde brillante).  
     - `color_fondo`: código ANSI del fondo (ej. `40` = negro).

2. **Leer y procesar `inventario.txt`**  
   - Formato de cada línea:
     ```
     nombre:cantidad
     ```
   - Ejemplo:
     ```
     manzanas:12
     peras:8
     naranjas:25
     kiwis:5
     ```

3. **Ordenar los datos alfabéticamente**  
   - Algoritmo de ordenamiento implementado: **Bubble Sort**.

4. **Dibujar el gráfico de barras**  
   - Imprime cada producto con su nombre, la barra de longitud proporcional y su cantidad.

---

## 📂 Archivos del Proyecto
| Archivo | Descripción |
|---------|-------------|
| `src/inventario_visual.asm` | **Programa principal**: lectura de archivos, ordenamiento y visualización. |
| `src/inventario.txt` | Datos de inventario para las pruebas. |
| `src/config.ini` | Parámetros de configuración (carácter y colores ANSI). |
| `src/color.asm` | Ejemplo de impresión en colores proporcionado por el profesor. |
| `src/hola.asm` | Primer programa de prueba en NASM (“Hola Mundo”). |

---

## 💻 Compilación y Ejecución

Compilar:
```bash
cd src
nasm -f elf64 -g -F dwarf inventario_visual.asm -o inventario_visual.o
ld inventario_visual.o -o inventario_visual

