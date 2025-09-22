; config_parser.asm  (NASM, x86_64)
; Lee config.ini, separa las claves y guarda los valores.
; Versión corregida: match_key deja rsi apuntando al ':' y read_value
; coloca rsi en el inicio del valor; copy/ store usan ese puntero.

section .data
    config_file    db "config.ini",0
    msg_err_open   db "ERROR: no se pudo abrir config.ini",10
    msg_err_open_len equ $ - msg_err_open
    newline        db 10

section .bss
    buffer      resb 512
    fd          resq 1
    caracter_barra resb 4    ; 1 char + terminador
    color_barra    resb 8    ; p.ej. "92"
    color_fondo    resb 8    ; p.ej. "40"

section .text
    global read_config

; -------------------------------------------------------------------------
; read_config
; Abre config.ini, parsea y guarda cada valor en variables globales.
; -------------------------------------------------------------------------
read_config:
    ; open(config_file, O_RDONLY)
    mov rax, 2
    lea rdi, [rel config_file]
    xor rsi, rsi
    xor rdx, rdx
    syscall
    cmp rax, 0
    js .open_error
    mov [fd], rax

    ; read(fd, buffer, 512)
    mov rax, 0
    mov rdi, [fd]
    lea rsi, [rel buffer]
    mov rdx, 512
    syscall
    cmp rax, 0
    jle .close_and_return
    ; bytes leídos en rax (no necesitamos guardarlo ahora)

    ; close(fd)
    mov rax, 3
    mov rdi, [fd]
    syscall

    ; parse: rsi = inicio del buffer
    lea rsi, [rel buffer]

.parse_loop:
    mov al, [rsi]
    cmp al, 0
    je .done_parse

    ; probar key "caracter_barra"
    lea rdi, [rel key_caracter]
    call match_key        ; si coincide: rax=1 y rsi = direccion del ':'
    test rax, rax
    jnz .found_caracter

    ; probar key "color_barra"
    lea rdi, [rel key_color_barra]
    call match_key
    test rax, rax
    jnz .found_color_barra

    ; probar key "color_fondo"
    lea rdi, [rel key_color_fondo]
    call match_key
    test rax, rax
    jnz .found_color_fondo

    inc rsi
    jmp .parse_loop

.found_caracter:
    call read_value       ; deja rsi = inicio del valor
    ; Guardar solo el primer byte (si usas '█' UTF-8 será multibyte; ver nota abajo)
    mov al, [rsi]
    mov [caracter_barra], al
    mov byte [caracter_barra+1], 0
    jmp .skip_to_next

.found_color_barra:
    call read_value       ; rsi = inicio del valor
    call strlen_at_rsi    ; devuelve rax = longitud del valor
    mov rdx, rax
    lea rdi, [rel color_barra]
    call store_string_len ; copia rdx bytes desde rsi -> rdi y termina con 0
    jmp .skip_to_next

.found_color_fondo:
    call read_value
    call strlen_at_rsi
    mov rdx, rax
    lea rdi, [rel color_fondo]
    call store_string_len
    jmp .skip_to_next

.skip_to_next:
    ; avanzar rsi hasta el final de la línea actual y luego una posición más
.skip_loop:
    mov al, [rsi]
    cmp al, 10
    je .inc_after
    cmp al, 0
    je .inc_after
    inc rsi
    jmp .skip_loop
.inc_after:
    inc rsi
    jmp .parse_loop

.done_parse:
    ; DEBUG: imprimir las variables (caracter, newline, color_barra, newline, color_fondo)
    ; imprimir caracter_barra (1 byte)
    mov rax, 1
    mov rdi, 1
    lea rsi, [rel caracter_barra]
    mov rdx, 1
    syscall
    ; newline
    mov rax, 1
    mov rdi, 1
    lea rsi, [rel newline]
    mov rdx, 1
    syscall
    ; imprimir color_barra
    lea rsi, [rel color_barra]
    call strlen_at_rsi
    mov rdx, rax
    mov rax, 1
    mov rdi, 1
    lea rsi, [rel color_barra]
    syscall
    ; newline
    mov rax, 1
    mov rdi, 1
    lea rsi, [rel newline]
    mov rdx, 1
    syscall
    ; imprimir color_fondo
    lea rsi, [rel color_fondo]
    call strlen_at_rsi
    mov rdx, rax
    mov rax, 1
    mov rdi, 1
    lea rsi, [rel color_fondo]
    syscall

    ret

.open_error:
    mov rax, 1
    mov rdi, 1
    lea rsi, [rel msg_err_open]
    mov rdx, msg_err_open_len
    syscall
    ret

.close_and_return:
    ret

; -------------------------------------------------------------------------
; match_key: compara la cadena en [rsi] con la clave en [rdi].
; Si coincide, devuelve rax=1 y deja rsi apuntando al ':' en el buffer.
; Si no coincide devuelve rax=0 y no modifica rsi.
; -------------------------------------------------------------------------
match_key:
    mov rdx, rsi        ; iterador sobre buffer
.loop_key:
    mov al, [rdi]
    cmp al, 0
    je .check_colon
    mov bl, [rdx]
    cmp bl, al
    jne .no_match
    inc rdx
    inc rdi
    jmp .loop_key
.check_colon:
    mov al, [rdx]
    cmp al, ':'
    jne .no_match
    mov rax, 1
    mov rsi, rdx        ; dejar rsi apuntando al ':' para read_value
    ret
.no_match:
    xor rax, rax
    ret

; -------------------------------------------------------------------------
; read_value: parte con rsi apuntando al ':' y deja rsi apuntando al primer
; byte del valor (salta ':' y espacios). No modifica otras regs.
; -------------------------------------------------------------------------
read_value:
    inc rsi             ; saltar ':'
.skip_spaces:
    mov al, [rsi]
    cmp al, ' '
    je .inc_sp
    cmp al, 9           ; tab
    je .inc_sp
    cmp al, 10          ; newline -> valor vacío
    je .done_read
    cmp al, 0
    je .done_read
    ret
.inc_sp:
    inc rsi
    jmp .skip_spaces
.done_read:
    ret

; -------------------------------------------------------------------------
; strlen_at_rsi: calcula la longitud de la cadena comenzando en RSI
; devuelve RAX = longitud (no cuenta '\n' ni '\0')
; -------------------------------------------------------------------------
strlen_at_rsi:
    xor rcx, rcx
.len_loop:
    mov al, [rsi + rcx]
    cmp al, 10
    je .len_done
    cmp al, 0
    je .len_done
    inc rcx
    jmp .len_loop
.len_done:
    mov rax, rcx
    ret

; -------------------------------------------------------------------------
; store_string_len: copia RDX bytes desde RSI -> RDI y añade terminador 0
; (usa RCX como contador interno)
; Entrada: RDI = dest, RSI = src, RDX = length
; -------------------------------------------------------------------------
store_string_len:
    mov rcx, rdx
    cmp rcx, 0
    je .store_done
.copy_loop:
    mov al, [rsi]
    mov [rdi], al
    inc rsi
    inc rdi
    dec rcx
    jnz .copy_loop
.store_done:
    mov byte [rdi], 0
    ret

section .rodata
key_caracter     db "caracter_barra",0
key_color_barra  db "color_barra",0
key_color_fondo  db "color_fondo",0

