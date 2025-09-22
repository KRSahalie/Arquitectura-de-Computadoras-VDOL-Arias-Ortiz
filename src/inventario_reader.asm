; ---------------------------------------------------------
; config_reader.asm v2
; Lee config.ini, interpreta los parámetros y guarda valores
; ---------------------------------------------------------

SECTION .data
filename db "config.ini", 0

msg_error db "Error abriendo config.ini", 10, 0

; Variables donde guardaremos los valores extraídos
caracter_barra db 0              ; Ejemplo: "█" o "*"
color_barra db 4 dup(0)          ; Ejemplo: "92"
color_fondo db 4 dup(0)          ; Ejemplo: "40"

; Buffer para leer el archivo completo
buffer_size equ 512
buffer db buffer_size dup(0)

SECTION .bss
fd resd 1       ; file descriptor
nbytes resd 1   ; bytes leídos

SECTION .text
global _start

; --- SYSCALLS ---
SYS_OPEN  equ 5
SYS_READ  equ 3
SYS_CLOSE equ 6
SYS_WRITE equ 4
SYS_EXIT  equ 1

; --- STDOUT ---
STDOUT equ 1

_start:
    ; Abrir config.ini
    mov eax, SYS_OPEN
    mov ebx, filename
    mov ecx, 0          ; solo lectura
    int 0x80
    cmp eax, 0
    jl error_open
    mov [fd], eax

    ; Leer archivo
    mov eax, SYS_READ
    mov ebx, [fd]
    mov ecx, buffer
    mov edx, buffer_size
    int 0x80
    mov [nbytes], eax

    ; Cerrar archivo
    mov eax, SYS_CLOSE
    mov ebx, [fd]
    int 0x80

    ; Procesar el buffer
    mov esi, buffer        ; puntero a inicio del buffer

parse_loop:
    ; Revisar si llegamos al final
    mov al, [esi]
    cmp al, 0
    je done_parse

    ; Guardar inicio de la clave
    mov edi, esi

find_colon:
    mov al, [esi]
    cmp al, ':'
    je found_colon
    cmp al, 10          ; salto de línea
    je next_line
    inc esi
    jmp find_colon

found_colon:
    ; EDI = inicio de clave
    ; ESI = posición de ':'
    mov byte [esi], 0   ; terminar la clave como string
    inc esi             ; avanzar a inicio del valor
    mov ebx, esi        ; EBX = inicio de valor

    ; Ir hasta fin de línea
find_eol:
    mov al, [esi]
    cmp al, 10
    je end_value
    cmp al, 0
    je end_value
    inc esi
    jmp find_eol

end_value:
    mov byte [esi], 0   ; terminar el valor como string
    inc esi             ; avanzar a la siguiente línea

    ; Comparar clave con cada parámetro
    push esi            ; salvar ESI temporalmente

    mov esi, edi
    mov edi, key_caracter
    call str_compare
    cmp eax, 0
    jne check_color_barra
    ; clave == "caracter_barra"
    mov al, [ebx]
    mov [caracter_barra], al
    jmp restore_loop

check_color_barra:
    mov esi, edi        ; clave original
    mov edi, key_color_barra
    call str_compare
    cmp eax, 0
    jne check_color_fondo
    ; clave == "color_barra"
    mov esi, ebx
    mov edi, color_barra
    call str_copy
    jmp restore_loop

check_color_fondo:
    mov esi, edi
    mov edi, key_color_fondo
    call str_compare
    cmp eax, 0
    jne restore_loop
    ; clave == "color_fondo"
    mov esi, ebx
    mov edi, color_fondo
    call str_copy

restore_loop:
    pop esi
    jmp parse_loop

next_line:
    inc esi
    jmp parse_loop

done_parse:
    ; DEBUG: Mostrar valores leídos
    mov eax, SYS_WRITE
    mov ebx, STDOUT
    mov ecx, color_barra
    mov edx, 4
    int 0x80

    ; Terminar
    mov eax, SYS_EXIT
    xor ebx, ebx
    int 0x80

error_open:
    mov eax, SYS_WRITE
    mov ebx, STDOUT
    mov ecx, msg_error
    mov edx, 24
    int 0x80
    jmp done_parse

; ---------------------------
; Funciones auxiliares
; ---------------------------

; str_compare(ESI, EDI) -> eax=0 si iguales
str_compare:
    push esi
    push edi
.compare_loop:
    mov al, [esi]
    mov bl, [edi]
    cmp al, bl
    jne .not_equal
    cmp al, 0
    je .equal
    inc esi
    inc edi
    jmp .compare_loop
.not_equal:
    mov eax, 1
    pop edi
    pop esi
    ret
.equal:
    xor eax, eax
    pop edi
    pop esi
    ret

; str_copy(ESI->EDI)
str_copy:
.copy_loop:
    mov al, [esi]
    mov [edi], al
    cmp al, 0
    je .done
    inc esi
    inc edi
    jmp .copy_loop
.done:
    ret

; ---------------------------
; Claves esperadas
; ---------------------------
key_caracter db "caracter_barra",0
key_color_barra db "color_barra",0
key_color_fondo db "color_fondo",0
