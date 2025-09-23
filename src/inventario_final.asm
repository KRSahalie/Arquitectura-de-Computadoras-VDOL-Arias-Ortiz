; inventario_final.asm
; NASM x86_64 Linux - Inventario con barras ANSI, colores y cantidad
;
; Este programa lee un archivo de inventario y un archivo de configuración,
; ordena los datos del inventario alfabéticamente y luego los muestra
; en un gráfico de barras utilizando caracteres y colores ANSI definidos en
; el archivo de configuración.
;
; El programa sigue estos pasos:
; 1. Lee el archivo 'config.ini' para obtener los colores y el carácter de la barra.
; 2. Lee el archivo 'inventario.txt' para obtener la lista de productos y sus cantidades.
; 3. Analiza los datos de los archivos y los almacena en arreglos en memoria.
; 4. Ordena alfabéticamente los productos usando el algoritmo de burbuja.
; 5. Imprime los nombres de los productos seguidos de un gráfico de barras
;    coloreado con los ajustes del archivo de configuración.
; 6. Imprime el número de la cantidad y una nueva línea.
; 7. Sale del programa.

%define NAME_LEN 24       ; Longitud máxima del nombre del producto.
%define BLOCK_SIZE 32     ; Tamaño del bloque de memoria para cada nombre de producto.
%define MAX_ITEMS 100     ; Número máximo de productos que se pueden almacenar.

section .data
    ; Nombres de archivos utilizados por el programa.
    fname_inv       db "inventario.txt",0  ; Archivo de inventario.
    fname_cfg       db "config.ini",0      ; Archivo de configuración.

    ; Buffers de lectura para almacenar el contenido de los archivos.
    inv_buf         times 8192 db 0 ; Buffer para el inventario (8 KB).
    cfg_buf         times 1024 db 0 ; Buffer para la configuración (1 KB).
    
    ; Cadenas de texto usadas para buscar las claves de configuración en 'config.ini'.
    caracter_barra_str db "caracter_barra:",0
    color_barra_str    db "color_barra:",0
    color_fondo_str    db "color_fondo:",0

    ; Buffers para almacenar los valores de configuración leídos del archivo.
    ; Los tamaños son suficientes para los códigos ANSI y el terminador nulo.
    cfg_barchar     times 5 db 0 
    cfg_color_fg    times 5 db 0
    cfg_color_bg    times 5 db 0
    
    ; Valores de color por defecto en caso de que el archivo de configuración
    ; no exista o no contenga los valores.
    default_fg_color db '92',0 ; Verde brillante por defecto para la barra.
    default_bg_color db '40',0 ; Fondo negro por defecto.

    ; Cadenas de salida que se imprimen en la consola.
    colon_str       db ": ",0        ; Separador entre el nombre y las barras.
    nl              db 0x0A,0        ; Carácter de nueva línea.
    ansi_prefix     db 0x1B,'[',0    ; Prefijo de la secuencia de escape ANSI.
    ansi_suffix     db 'm',0         ; Sufijo de la secuencia de escape ANSI.

    ; Almacenamiento de datos del inventario.
    item_names      times MAX_ITEMS*BLOCK_SIZE db 0 ; Arreglo para los nombres de los productos.
    item_counts     times MAX_ITEMS dq 0            ; Arreglo para los conteos de los productos (quad-word).
    item_count      dq 0                            ; Contador de la cantidad de productos leídos.

    ; Secuencia ANSI para resetear el color a los valores por defecto del terminal.
    reset_ansi      db 0x1B,'[','0','m',0

section .bss
    ; Sección para variables no inicializadas.
    tmp_byte resb 1     ; Buffer temporal para intercambiar bytes durante el ordenamiento.
    ansi_seq resb 16    ; Buffer para construir la secuencia ANSI de color dinámicamente.
    num_buf  resb 20    ; Buffer para convertir números a cadenas de texto para la impresión.
    
section .text
    global _start

; -------------------------
; syscall write
; Wrapper para la llamada al sistema 'write'.
; Imprime el contenido de un buffer en la pantalla.
; Parámetros:
; rdi = file descriptor (1 para stdout)
; rsi = puntero al buffer
; rdx = longitud del buffer
;
; Registros usados: rax, rdi, rsi, rdx.
write_buf:
    mov rax,1       ; Llamada al sistema `write`.
    mov rdi,1       ; Usar stdout (salida estándar).
    syscall
    ret

; -------------------------
; parse_config
; Parsea el archivo de configuración y establece los valores
; de cfg_barchar, cfg_color_fg y cfg_color_bg.
;
; Parámetros:
; rsi = puntero al inicio del buffer `cfg_buf` (el contenido del archivo).
;
; La función recorre el buffer línea por línea, buscando las claves de
; configuración y copiando sus valores en los buffers correspondientes.
; Si no se encuentran los valores, se usan los por defecto.
;
; Registros usados: rbx, rcx, rdi, rsi, r12, r13, r14.
parse_config:
    push rbx
    push rcx
    push rdi
    push rsi
    push r12 ; Puntero a la ubicación de lectura.
    push r13 ; Búfer de destino.
    push r14 ; Longitud máxima.

    mov r12, rsi ; rsi es el puntero al inicio del buffer cfg_buf.

.parse_loop:
    ; Comprobar si hemos llegado al final del buffer.
    cmp byte [r12], 0
    je .done

    ; Buscar la clave "caracter_barra:".
    lea rdi, [rel caracter_barra_str]
    mov rsi, r12
    call line_starts_with
    cmp rax, 1
    jne .check_color_fg ; No coincide, pasar a la siguiente comprobación.

    lea r13, [rel cfg_barchar]
    mov r14, 4 ; Longitud máxima del valor.
    jmp .parse_value ; Coincide, parsear el valor.

.check_color_fg:
    ; Buscar la clave "color_barra:".
    lea rdi, [rel color_barra_str]
    mov rsi, r12
    call line_starts_with
    cmp rax, 1
    jne .check_color_bg

    lea r13, [rel cfg_color_fg]
    mov r14, 4 ; Longitud máxima del valor.
    jmp .parse_value

.check_color_bg:
    ; Buscar la clave "color_fondo:".
    lea rdi, [rel color_fondo_str]
    mov rsi, r12
    call line_starts_with
    cmp rax, 1
    jne .next_line ; No coincide, avanzar a la siguiente línea.

    lea r13, [rel cfg_color_bg]
    mov r14, 4 ; Longitud máxima del valor.
    jmp .parse_value

.parse_value:
    ; Encontrar el inicio del valor después de los dos puntos ':'.
    mov rbx, r12
.find_colon_val:
    cmp byte [rbx], ':'
    je .skip_colon
    inc rbx
    jmp .find_colon_val
.skip_colon:
    inc rbx
.find_value_start:
    cmp byte [rbx], ' '
    jne .value_found
    inc rbx
    jmp .find_value_start
.value_found:
    ; Copiar el valor en el buffer de destino.
    mov rsi, rbx
    mov rdi, r13
    xor rcx, rcx
.copy_loop:
    cmp rcx, r14
    jge .end_copy ; Límite de longitud alcanzado.
    mov al, [rsi]
    cmp al, 0x0A ; Parar en nueva línea.
    je .end_copy
    cmp al, 0 ; Parar en terminador nulo.
    je .end_copy
    mov [rdi], al
    inc rsi
    inc rdi
    inc rcx
    jmp .copy_loop
.end_copy:
    mov byte [rdi], 0 ; Terminar la cadena con un nulo.
    jmp .next_line

.next_line:
    ; Avanzar el puntero a la siguiente línea.
.find_newline:
    cmp byte [r12], 0x0A
    je .newline_found
    cmp byte [r12], 0
    je .done
    inc r12
    jmp .find_newline
.newline_found:
    inc r12
    jmp .parse_loop

.done:
    ; Si no se encontraron los valores de configuración, usar los por defecto.
    ; Se comprueba si el primer byte del buffer está vacío.
    cmp byte [cfg_barchar], 0
    jne .barchar_ok
    mov byte [cfg_barchar], 0xe2 ; Byte 1 del carácter unicode '█'.
    mov byte [cfg_barchar+1], 0x96 ; Byte 2.
    mov byte [cfg_barchar+2], 0x88 ; Byte 3.
    mov byte [cfg_barchar+3], 0  ; Terminador nulo.
.barchar_ok:

    cmp byte [cfg_color_fg], 0
    jne .fg_ok
    lea rsi, [rel default_fg_color]
    lea rdi, [rel cfg_color_fg]
    mov rcx, 3
    rep movsb
.fg_ok:

    cmp byte [cfg_color_bg], 0
    jne .bg_ok
    lea rsi, [rel default_bg_color]
    lea rdi, [rel cfg_color_bg]
    mov rcx, 3
    rep movsb
.bg_ok:

    ; Restaurar los registros guardados.
    pop r14
    pop r13
    pop r12
    pop rsi
    pop rdi
    pop rcx
    pop rbx
    ret

; -------------------------
; line_starts_with
; Comprueba si una cadena comienza con otra.
; Parámetros:
; rsi = puntero a la línea a comprobar.
; rdi = puntero a la cadena de comparación.
; Retorna:
; rax = 1 si coincide, 0 si no.
line_starts_with:
    push rbx
    push rdx
    mov rdx,0
    xor rax,rax
.compare_loop:
    mov bl,[rdi+rdx]
    cmp bl,0
    je .match ; Fin de la cadena de comparación, hay coincidencia.
    mov al,[rsi+rdx]
    cmp al,bl
    jne .no_match ; No coincide.
    inc rdx
    jmp .compare_loop
.match:
    mov rax,1
.no_match:
    pop rdx
    pop rbx
    ret

; -------------------------
; swap_items_by_index
; Intercambia dos elementos completos (nombre y conteo) en los arreglos de datos.
; Parámetros:
; rdi = indice 1.
; rsi = indice 2.
swap_items_by_index:
    push rax
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi

    ; Intercambiar nombres (bloques de 32 bytes).
    mov rdx,rdi
    imul rdx,BLOCK_SIZE
    lea r8,[item_names+rdx] ; Dirección del primer nombre.
    mov rdx,rsi
    imul rdx,BLOCK_SIZE
    lea r9,[item_names+rdx] ; Dirección del segundo nombre.
    mov rcx,BLOCK_SIZE
    xor rdx,rdx
.swap_name_loop:
    cmp rdx,rcx
    je .done_swap_name
    ; Intercambio de byte a byte.
    mov al,[r8+rdx]
    mov bl,[r9+rdx]
    mov [tmp_byte],al
    mov [r8+rdx],bl
    mov al,[tmp_byte]
    mov [r9+rdx],al
    inc rdx
    jmp .swap_name_loop
.done_swap_name:

    ; Intercambiar conteos (quad-words).
    mov rax,[item_counts+rdi*8] ; Cargar el conteo 1.
    mov rbx,[item_counts+rsi*8] ; Cargar el conteo 2.
    mov [item_counts+rdi*8],rbx ; Guardar el conteo 2 en la posición 1.
    mov [item_counts+rsi*8],rax ; Guardar el conteo 1 en la posición 2.
    
    ; Restaurar registros.
    pop rsi
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

; -------------------------
; bubble_sort
; Implementación del algoritmo de ordenamiento de burbuja.
; Ordena los productos alfabéticamente por su nombre.
bubble_sort:
    push r12            ; Guardar registros callee-saved.
    push r13
    push r14
    push r15
    mov r12, [item_count] ; r12 = número de items.
    cmp r12, 1
    jle .done_bs ; No hay nada que ordenar si hay 0 o 1 item.
    mov r14, 0 ; r14 = flag de intercambio (0 = no hubo, 1 = si hubo).

.outer_loop:
    mov r14, 0
    mov r13, 0 ; r13 = índice del bucle interno.
    mov r15, r12
    dec r15 ; r15 = límite del bucle interno.

.inner_loop:
    cmp r13, r15
    jge .end_inner_loop

    ; Cargar las direcciones de los nombres para la comparación.
    mov rax, r13
    imul rax, BLOCK_SIZE
    lea rdi, [item_names + rax]
    mov rbx, r13
    inc rbx
    imul rbx, BLOCK_SIZE
    lea rsi, [item_names + rbx]
    
    ; Llamar a `strcmp_str` para comparar los nombres.
    call strcmp_str
    
    cmp rax, 0
    jle .no_swap ; Si el resultado es <= 0, no hay que intercambiar.
    
    ; Si el resultado es > 0, swap los items.
    mov rdi, r13
    mov rsi, r13
    inc rsi
    call swap_items_by_index
    mov r14, 1 ; Se realizó un intercambio, así que se debe continuar el bucle externo.

.no_swap:
    inc r13
    jmp .inner_loop

.end_inner_loop:
    dec r12
    cmp r14, 0
    jnz .outer_loop ; Si hubo intercambios, continuar el bucle externo.
    
.done_bs:
    ; Restaurar registros callee-saved.
    pop r15
    pop r14
    pop r13
    pop r12
    ret

; -------------------------
; print_number
; Imprime un número decimal.
; Parámetro:
; rdi = número a imprimir.
print_number:
    push rbx
    push rcx
    push rsi
    push rdx
    mov rax,rdi
    lea rsi,[num_buf+19] ; Puntero al final del buffer.
    mov rcx,0
.convert_loop:
    xor rdx,rdx
    mov rbx,10
    div rbx             ; rax = rax / 10, rdx = rax % 10.
    add dl,'0'          ; Convierte el dígito a su carácter ASCII.
    dec rsi             ; Mover el puntero hacia atrás en el buffer.
    mov [rsi],dl        ; Almacenar el carácter.
    inc rcx             ; Incrementar el contador de dígitos.
    test rax,rax
    jnz .convert_loop   ; Continuar hasta que rax sea 0.
    mov rdx,rcx         ; rdx = longitud del número.
    mov rax,1           ; syscall `write`.
    mov rdi,1           ; stdout.
    syscall             ; Imprimir el número.
    pop rdx
    pop rsi
    pop rcx
    pop rbx
    ret

; -------------------------
; print_bars
; Dibuja el gráfico de barras en la consola.
;
; La función recorre todos los items, imprime su nombre, la barra
; coloreada y el número de la cantidad.
print_bars:
    push r12
    push r13
    push r14
    push r15            ; Guardar registros callee-saved.
    mov r12,[item_count] ; r12 = número de items.
    xor r13,r13          ; r13 = índice del item.

    ; Calcular la longitud del carácter de la barra (ej: █ es 3 bytes).
    lea rbx,[cfg_barchar]
    xor rdx, rdx
.find_char_len:
    cmp byte [rbx+rdx], 0
    je .char_len_found
    inc rdx
    jmp .find_char_len
.char_len_found:
    mov r15, rdx ; Guardar la longitud en r15.

.print_loop:
    cmp r13,r12
    jge .done_print ; Si el índice es mayor o igual al conteo, terminar.

    ; Imprimir nombre del item.
    mov rax,r13
    imul rax,BLOCK_SIZE
    lea rsi,[item_names+rax]

    ; Calcular la longitud del nombre para `write`.
    mov rdx, rsi
.find_name_len:
    cmp byte [rdx], 0
    je .name_len_found
    inc rdx
    jmp .find_name_len
.name_len_found:
    sub rdx, rsi

    ; Imprimir el nombre.
    mov rax,1
    mov rdi,1
    syscall

    ; Imprimir el ": ".
    lea rsi,[rel colon_str]
    mov rdx,2
    mov rax,1
    mov rdi,1
    syscall

    ; Construir y escribir la secuencia ANSI de color.
    lea rdi, [ansi_seq]
    mov byte [rdi], 0x1B
    mov byte [rdi+1], '['
    mov r9, 2
    
    ; Copiar el código del color de fondo (`cfg_color_bg`).
    lea rsi, [cfg_color_bg]
    .copy_bg_loop:
        mov al, [rsi]
        cmp al, 0
        je .bg_done
        mov [rdi+r9], al
        inc rsi
        inc r9
        jmp .copy_bg_loop
    .bg_done:
    mov byte [rdi+r9], ';'
    inc r9

    ; Copiar el código del color de la barra (`cfg_color_fg`).
    lea rsi, [cfg_color_fg]
    .copy_fg_loop:
        mov al, [rsi]
        cmp al, 0
        je .fg_done
        mov [rdi+r9], al
        inc rsi
        inc r9
        jmp .copy_fg_loop
    .fg_done:
    mov byte [rdi+r9], 'm'
    inc r9
    
    ; Escribir la secuencia de color en la consola.
    mov rdx, r9
    lea rsi, [ansi_seq]
    mov rax, 1
    mov rdi, 1
    syscall

    ; Imprimir las barras.
    mov r14,[item_counts+r13*8] ; r14 = conteo del item actual.

.bar_loop:
    cmp r14,0
    je .after_bar
    lea rsi,[cfg_barchar]
    mov rdx, r15        ; Usar la longitud del caracter de la barra.
    
    mov rax,1
    mov rdi,1
    syscall
    dec r14
    jmp .bar_loop

.after_bar:
    ; Resetear el formato de la consola a los valores por defecto.
    lea rsi,[rel reset_ansi]
    mov rdx,4
    mov rax,1
    mov rdi,1
    syscall

    ; Imprimir el conteo numérico del item.
    mov rax,[item_counts+r13*8]
    mov rdi,rax
    call print_number

    ; Imprimir una nueva línea para el siguiente item.
    lea rsi,[rel nl]
    mov rdx,1
    mov rax,1
    mov rdi,1
    syscall

    inc r13
    jmp .print_loop

.done_print:
    ; Restaurar registros callee-saved.
    pop r15
    pop r14
    pop r13
    pop r12
    ret

; -------------------------
; strcmp_str
; Compara dos cadenas terminadas en nulo.
; Parámetros:
; rdi = puntero a la cadena 1.
; rsi = puntero a la cadena 2.
; Retorna:
; rax < 0 si la cadena 1 < cadena 2 (alfabéticamente).
; rax = 0 si las cadenas son iguales.
; rax > 0 si la cadena 1 > cadena 2.
strcmp_str:
    push rbx
    push rcx
    push rdx
    mov rcx, rdi
    mov rdx, rsi
.compare_loop:
    mov al, [rcx]
    mov bl, [rdx]
    cmp al, bl
    jne .not_equal
    cmp al, 0
    je .equal ; Ambas cadenas terminaron al mismo tiempo.
    inc rcx
    inc rdx
    jmp .compare_loop
.not_equal:
    movsx rax, al
    movsx rbx, bl
    sub rax, rbx
    jmp .exit_strcmp
.equal:
    xor rax, rax
.exit_strcmp:
    pop rdx
    pop rcx
    pop rbx
    ret

; -------------------------
; parse_inventory
; Lee el archivo `inventario.txt`, lo parsea y llena los arrays
; `item_names` y `item_counts`.
parse_inventory:
    push r12            ; item_count.
    push r13            ; inv_buf index.
    push r14            ; name/number value.
    push r15            ; temp register.

    mov r12, 0 ; item_count.
    mov r13, 0 ; inv_buf index.

.parse_loop:
    ; Saltar espacios en blanco y nuevas líneas al principio.
.skip_leading_chars:
    mov al, [inv_buf+r13]
    cmp al, 0
    je .done_parsing
    cmp al, 0x0A
    je .advance_and_skip
    cmp al, 0x0D
    je .advance_and_skip
    cmp al, ' '
    je .advance_and_skip
    cmp al, 0x09
    je .advance_and_skip
    jmp .read_name_and_count

.advance_and_skip:
    inc r13
    jmp .skip_leading_chars

.read_name_and_count:
    ; Comprobar el límite de items.
    cmp r12, MAX_ITEMS
    jge .done_parsing

    ; Leer el nombre del item.
    mov r14, 0 ; Contador de caracteres del nombre.
.name_loop:
    mov al, [inv_buf+r13]
    cmp al, 0x0A ; Nueva línea.
    je .name_done
    cmp al, 0x0D ; Retorno de carro.
    je .name_done
    cmp al, ':' ; Separador.
    je .name_done
    cmp al, 0
    je .name_done

    mov r15, r12
    imul r15, BLOCK_SIZE
    add r15, r14
    mov byte [item_names+r15], al
    inc r13
    inc r14
    cmp r14, BLOCK_SIZE-1
    jge .name_done ; Límite de longitud del nombre alcanzado.
    jmp .name_loop

.name_done:
    ; Terminar el nombre con un byte nulo.
    mov r15, r12
    imul r15, BLOCK_SIZE
    add r15, r14
    mov byte [item_names+r15], 0

    ; Si encontramos ':', avanzar el puntero.
    cmp al, ':'
    je .found_colon
    jmp .read_number

.found_colon:
    inc r13

    ; Saltar espacios en blanco después de los dos puntos.
.skip_whitespace:
    mov al, [inv_buf+r13]
    cmp al, ' '
    je .is_space
    cmp al, 0x09
    je .is_space
    jmp .read_number
.is_space:
    inc r13
    jmp .skip_whitespace

.read_number:
    xor r14, r14 ; Resetear r14 para el parsing del número.
.number_loop:
    mov al, [inv_buf+r13]
    cmp al, '0'
    jl .number_done
    cmp al, '9'
    jg .number_done
    
    sub al, '0'
    mov rbx, 10
    imul r14, rbx ; Multiplicar el valor actual por 10.
    add r14, rax  ; Añadir el nuevo dígito.
    inc r13
    jmp .number_loop

.number_done:
    mov r15, r12
    shl r15, 3 ; Multiplicar por 8 para el índice del `quad-word`.
    mov [item_counts+r15], r14 ; Almacenar el conteo.
    inc r12
    jmp .parse_loop

.done_parsing:
    mov [item_count], r12 ; Almacenar el número total de items.
    pop r15
    pop r14
    pop r13
    pop r12
    ret
; -------------------------
; MAIN
; Punto de entrada del programa.
_start:
    ; Abrir y leer 'config.ini'.
    ; rax=2 (syscall open), rdi=nombre del archivo, rsi=0 (flags).
    mov rax,2
    lea rdi,[rel fname_cfg]
    xor rsi,rsi
    syscall
    cmp rax,0
    js .no_cfg ; Si el archivo no existe o hay un error, saltar.
    mov rdi,rax
    mov rax,0 ; syscall `read`.
    mov rsi,cfg_buf
    mov rdx,1024
    syscall
    mov rax,3 ; syscall `close`.
    syscall
    call parse_config ; Parsear el contenido del archivo de configuración.
.no_cfg:

    ; Abrir y leer 'inventario.txt'.
    mov rax,2
    lea rdi,[rel fname_inv]
    xor rsi,rsi
    syscall
    cmp rax,0
    js .no_inv ; Si el archivo no existe o hay un error, saltar.
    mov rdi,rax
    mov rax,0 ; syscall `read`.
    mov rsi,inv_buf
    mov rdx,8192
    syscall
    mov rax,3
    syscall
    call parse_inventory ; Parsear el contenido del archivo de inventario.
.no_inv:

    ; Ordenar los productos alfabéticamente.
    call bubble_sort
    ; Imprimir el gráfico de barras.
    call print_bars

    ; Salir del programa.
    mov rax,60 ; syscall `exit`.
    xor rdi,rdi ; Código de salida 0.
    syscall

