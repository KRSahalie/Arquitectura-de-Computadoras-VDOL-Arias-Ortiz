; inventario_visual_config.asm
; Lee config.ini y luego muestra inventario ordenado con barras coloreadas
; Ensamblador: NASM, x86_64 Linux

%define NAME_LEN 32
%define NUM_ITEMS 4
%define BLOCK_SIZE (NAME_LEN + 8) ; 40

section .data
; --- inventario por defecto (si quieres leer desde archivo más adelante, reemplazar) ---
names:
    db "kiwis",0
    times (32-6) db 0
    db "manzanas",0
    times (32-9) db 0
    db "naranjas",0
    times (32-9) db 0
    db "peras",0
    times (32-6) db 0

qtys:
    dq 5
    dq 12
    dq 25
    dq 8

newline db 10,0
sep     db ": ",0
space   db " ",0

; config file name
config_file db "config.ini",0

; default color/reset placeholders (se usarán si config falta o tiene problema)
default_color_start db 0x1b,"[92;40m",0   ; verde brillante sobre fondo negro
default_color_reset db 0x1b,"[0m",0

; buffer estático para imprimir una barra (se reemplaza en tiempo de ejecución con caracter de config)
barbuf db '*',0

section .bss
; where we will construct color_start dynamically: ESC [ <fg> ; <bg> m  0
color_start_buf resb 16
color_reset_buf resb 4    ; ESC [0m\0

; buffers to hold config tokens
cfg_buf resb 512          ; read config file here
cfg_nbytes resq 1
cfg_barchar resb 4        ; store bar char (1 byte + null)
cfg_color_bar resb 4      ; e.g. "92", null-terminated
cfg_color_bg  resb 4      ; e.g. "40", null-terminated

; sorted inventory storage
sorted resb BLOCK_SIZE * NUM_ITEMS

; utility buffer for numbers
numBuf resb 32

section .text
global _start

; -------------------------------------------------------
; sys_write string in RSI (null-terminated)
; -------------------------------------------------------
print_str:
    push rbx
    push rcx
    xor rcx, rcx
.ps_len:
    cmp byte [rsi + rcx], 0
    je .ps_done
    inc rcx
    jmp .ps_len
.ps_done:
    mov rax, 1      ; sys_write
    mov rdi, 1
    mov rdx, rcx
    syscall
    pop rcx
    pop rbx
    ret

; -------------------------------------------------------
; print_num: imprime entero positivo en RAX (decimal)
; usa numBuf
; -------------------------------------------------------
print_num:
    push rbx
    push rcx
    push rdx
    mov rbx, 10
    mov rcx, 0
    lea rdi, [numBuf + 31]
    mov byte [rdi], 0
.pn_loop:
    xor rdx, rdx
    div rbx
    add dl, '0'
    dec rdi
    mov [rdi], dl
    inc rcx
    test rax, rax
    jnz .pn_loop
    mov rsi, rdi
    call print_str
    pop rdx
    pop rcx
    pop rbx
    ret

; -------------------------------------------------------
; Helper: string compare rdi vs rsi (C-strings)
; retorna rax <0, =0, >0
; -------------------------------------------------------
str_cmp:
    push rbx
    push rcx
.cmp_loop:
    mov al, [rdi]
    mov bl, [rsi]
    cmp al, bl
    jne .diff
    test al, al
    je .equal
    inc rdi
    inc rsi
    jmp .cmp_loop
.diff:
    movsx rax, al
    movsx rbx, bl
    sub rax, rbx
    pop rcx
    pop rbx
    ret
.equal:
    xor rax, rax
    pop rcx
    pop rbx
    ret

; -------------------------------------------------------
; swap_block: intercambia BLOCK_SIZE bytes en [rdi] <-> [rsi]
; -------------------------------------------------------
swap_block:
    push rcx
    mov rcx, BLOCK_SIZE
.swap_loop:
    mov al, [rdi]
    mov bl, [rsi]
    mov [rdi], bl
    mov [rsi], al
    inc rdi
    inc rsi
    loop .swap_loop
    pop rcx
    ret

; -------------------------------------------------------
; parse_config: parse cfg_buf to fill cfg_barchar, cfg_color_bar, cfg_color_bg
; Simple parser: busca líneas 'clave:valor' trim espacios.
; Entradas: cfg_buf (contenido), cfg_nbytes (n)
; -------------------------------------------------------
parse_config:
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi

    mov rsi, cfg_buf        ; pointer scanning
    mov rbx, [cfg_nbytes]   ; bytes read
    add rbx, rsi            ; rbx = end pointer

.parse_loop:
    cmp rsi, rbx
    jge .done_parse

    ; skip leading newlines/spaces
    mov al, [rsi]
    cmp al, 10
    je .skip_nl
    cmp al, 13
    je .skip_nl
    cmp al, ' '
    je .skip_nl
    ; else process key until ':'
    lea rdi, [rsi]          ; key start
.find_colon:
    cmp rsi, rbx
    jge .done_parse
    mov al, [rsi]
    cmp al, ':'
    je .got_colon
    cmp al, 10
    je .skip_nl
    inc rsi
    jmp .find_colon

.got_colon:
    mov byte [rsi], 0       ; terminate key
    inc rsi                 ; now rsi at start of value (maybe space)
    ; skip spaces after colon
    .skip_spaces_after:
        cmp rsi, rbx
        jge .done_parse
        mov al, [rsi]
        cmp al, ' '
        jne .value_start
        inc rsi
        jmp .skip_spaces_after
    .value_start:
    ; rsi now at value start
    mov rdi, rsi            ; value start
.find_eol:
    cmp rsi, rbx
    jge .end_val
    mov al, [rsi]
    cmp al, 10
    je .end_val
    cmp al, 13
    je .end_val
    inc rsi
    jmp .find_eol

.end_val:
    mov byte [rsi], 0       ; terminate value
    inc rsi                 ; advance to next line

    ; Now key is at [rdi_key] (we saved earlier)
    ; compare key (its start is at memory location we set zero) by temporarily computing its pointer
    ; key start = pointer stored earlier at (we used lea rdi,[rsi] before find_colon) - but we overwrote...
    ; Simpler: we reconstruct key start scanning backwards from (rsi-1) until previous newline or start.
    ; Let's find key_start: scan backwards from (rdi-1)
    mov rdx, rdi
    dec rdx
    ; rdx is char at end of value null; find colon's null position earlier; we will search backwards to find start of key
    ; But easier: we stored key by setting byte at colon to 0 and had earlier lea rdi,[rsi] before colon - we don't have that.
    ; To avoid complexity, we will parse by re-scanning line start: find start by backing to previous newline.
    mov rcx, rdi
    sub rcx, 2              ; position before value (should be null we set)
    ; step back to find start of line
    .back_to_line:
        cmp rcx, cfg_buf
        jb .key_is_start
        mov al, [rcx]
        cmp al, 10
        je .key_after_nl
        dec rcx
        jmp .back_to_line
    .key_after_nl:
        inc rcx
    .key_is_start:
    ; rcx now points to start of key
    ; Compare key at rcx with known strings

    ; compare with "caracter_barra"
    lea rdi, [rel key_caracter]
    mov rsi, rcx
    call compare_key_local
    cmp rax, 0
    je .store_caracter

    ; compare with "color_barra"
    lea rdi, [rel key_color_barra]
    mov rsi, rcx
    call compare_key_local
    cmp rax, 0
    je .store_color_barra

    ; compare with "color_fondo"
    lea rdi, [rel key_color_fondo]
    mov rsi, rcx
    call compare_key_local
    cmp rax, 0
    je .store_color_fondo

    jmp .parse_loop

.store_caracter:
    ; copy first non-space char from value (value pointer was at rdi before)
    ; We can get value start: we placed null at end of value and earlier stored rdi = value start before finding eol.
    ; However to simplify, we locate value again: from rcx (line start), scan to ':' then skip spaces.
    mov rax, rcx
    ; find colon from line start
    .find_colon2:
        mov al, [rax]
        cmp al, 0
        je .no_value_found
        cmp al, ':'
        je .after_colon2
        inc rax
        jmp .find_colon2
    .after_colon2:
        inc rax
    .skip_spaces2:
        mov al, [rax]
        cmp al, ' '
        jne .take_char
        inc rax
        jmp .skip_spaces2
    .take_char:
        mov bl, [rax]
        mov [cfg_barchar], bl
        mov byte [cfg_barchar+1], 0
        jmp .parse_loop

.no_value_found:
    jmp .parse_loop

.store_color_barra:
    ; locate value (same method)
    mov rax, rcx
    .find_colon3:
        mov al, [rax]
        cmp al, 0
        je .no_val3
        cmp al, ':'
        je .after_colon3
        inc rax
        jmp .find_colon3
    .after_colon3:
        inc rax
    .skip_spaces3:
        mov al, [rax]
        cmp al, ' '
        jne .copy_digits_bar
        inc rax
        jmp .skip_spaces3
    .copy_digits_bar:
        ; copy up to 3 chars digits into cfg_color_bar
        mov rcx, 0
    .copy_loop_bar:
        mov al, [rax + rcx]
        cmp al, 0
        je .done_copy_bar
        cmp al, 10
        je .done_copy_bar
        mov [cfg_color_bar + rcx], al
        inc rcx
        cmp rcx, 3
        je .done_copy_bar
        jmp .copy_loop_bar
    .done_copy_bar:
        mov byte [cfg_color_bar + rcx], 0
        jmp .parse_loop
    .no_val3:
        jmp .parse_loop

.store_color_fondo:
    mov rax, rcx
    .find_colon4:
        mov al, [rax]
        cmp al, 0
        je .no_val4
        cmp al, ':'
        je .after_colon4
        inc rax
        jmp .find_colon4
    .after_colon4:
        inc rax
    .skip_spaces4:
        mov al, [rax]
        cmp al, ' '
        jne .copy_digits_bg
        inc rax
        jmp .skip_spaces4
    .copy_digits_bg:
        mov rcx, 0
    .copy_loop_bg:
        mov al, [rax + rcx]
        cmp al, 0
        je .done_copy_bg
        cmp al, 10
        je .done_copy_bg
        mov [cfg_color_bg + rcx], al
        inc rcx
        cmp rcx, 3
        je .done_copy_bg
        jmp .copy_loop_bg
    .done_copy_bg:
        mov byte [cfg_color_bg + rcx], 0
        jmp .parse_loop
    .no_val4:
        jmp .parse_loop

.skip_nl:
    inc rsi
    jmp .parse_loop

.done_parse:
    ; make sure defaults exist if not provided
    ; if cfg_barchar[0]==0 -> default *
    mov al, [cfg_barchar]
    cmp al, 0
    jne .has_bar
    mov byte [cfg_barchar], '*'
    mov byte [cfg_barchar+1], 0
.has_bar:
    ; if color strings empty -> use defaults (92 and 40)
    mov al, [cfg_color_bar]
    cmp al, 0
    jne .has_cbar
    mov byte [cfg_color_bar], '9'
    mov byte [cfg_color_bar+1], '2'
    mov byte [cfg_color_bar+2], 0
.has_cbar:
    mov al, [cfg_color_bg]
    cmp al, 0
    jne .has_cbg
    mov byte [cfg_color_bg], '4'
    mov byte [cfg_color_bg+1], '0'
    mov byte [cfg_color_bg+2], 0
.has_cbg:

    ; Build color_start in color_start_buf: ESC '[' + color_bar + ';' + color_bg + 'm' + 0
    lea rdi, [color_start_buf]
    mov byte [rdi], 0x1b
    mov byte [rdi + 1], '['
    ; copy cfg_color_bar
    lea rsi, [cfg_color_bar]
    mov rcx, 0
.copy_cbar:
    mov al, [rsi + rcx]
    cmp al, 0
    je .after_cbar
    mov [rdi + 2 + rcx], al
    inc rcx
    jmp .copy_cbar
.after_cbar:
    mov byte [rdi + 2 + rcx], ';'
    inc rcx
    ; copy cfg_color_bg
    lea rsi, [cfg_color_bg]
.copy_cbg:
    mov al, [rsi]
    cmp al, 0
    je .after_cbg
    mov [rdi + 2 + rcx], al
    inc rcx
    inc rsi
    jmp .copy_cbg
.after_cbg:
    mov byte [rdi + 2 + rcx], 'm'
    inc rcx
    mov byte [rdi + 2 + rcx], 0

    ; build reset: ESC [0m
    lea rdi, [color_reset_buf]
    mov byte [rdi], 0x1b
    mov byte [rdi + 1], '['
    mov byte [rdi + 2], '0'
    mov byte [rdi + 3], 'm'
    mov byte [rdi + 4], 0

    ; finally copy bar char into barbuf
    mov al, [cfg_barchar]
    mov [barbuf], al
    mov byte [barbuf+1], 0

    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    ret

; -------------------------------------------------------
; compare_key_local: compara (rdi=const key, rsi=line_key)
; Retorna rax = 0 si iguales (usa str_cmp)
; -------------------------------------------------------
compare_key_local:
    push rbx
    push rcx
    ; str_cmp expects pointers in rdi (first) and rsi (second)
    call str_cmp
    pop rcx
    pop rbx
    ret

; -------------------------------------------------------
; main program start
; 1) Leer config.ini y parsear
; 2) Copiar inventario estático a 'sorted'
; 3) Ordenar (bubble sort)
; 4) Imprimir usando barbuf y color_start_buf
; -------------------------------------------------------
_start:
    ; --- open config.ini ---
    mov rax, 2                  ; sys_open
    lea rdi, [rel config_file]
    xor rsi, rsi                ; O_RDONLY
    xor rdx, rdx
    syscall
    cmp rax, 0
    js .cfg_not_found
    mov rdi, rax                ; fd
    ; --- read config into cfg_buf ---
    mov rax, 0                  ; sys_read
    mov rsi, cfg_buf
    mov rdx, 512
    syscall
    mov [cfg_nbytes], rax
    ; close fd
    mov rax, 3
    syscall

    ; parse config
    call parse_config
    jmp .after_cfg

.cfg_not_found:
    ; no config -> use defaults, ensure barbuf and color_start_buf are set
    lea rdi, [rel default_color_start]
    mov rsi, rdi
    call print_nop             ; noop (we'll build color later)
    ; manually set barbuf to '*' (already default)
    mov byte [barbuf], '*'
    mov byte [barbuf+1], 0
    ; build color_start_buf from default_color_start (simple copy)
    lea rsi, [rel default_color_start]
    lea rdi, [color_start_buf]
    mov rcx, 8
    rep movsb
    ; build reset
    lea rsi, [rel default_color_reset]
    lea rdi, [color_reset_buf]
    mov rcx, 4
    rep movsb

.after_cfg:
    ; --- COPY inventory (static arrays) into sorted blocks ---
    xor rbx, rbx
.copy_loop_main:
    cmp rbx, NUM_ITEMS
    jge .after_copy_main

    ; source name = names + i*NAME_LEN
    mov rax, rbx
    imul rax, NAME_LEN
    lea rsi, [names]
    add rsi, rax

    ; dest block = sorted + i*BLOCK_SIZE
    mov rax, rbx
    imul rax, BLOCK_SIZE
    lea rdi, [sorted]
    add rdi, rax

    ; copy name (NAME_LEN bytes)
    mov rcx, NAME_LEN
    rep movsb

    ; copy qty (qword)
    mov rax, rbx
    imul rax, 8
    lea rsi, [qtys]
    add rsi, rax
    mov rax, [rsi]
    mov [rdi], rax      ; stored right after name

    inc rbx
    jmp .copy_loop_main

.after_copy_main:
    ; --- bubble sort by name on sorted blocks ---
    mov r8, NUM_ITEMS
    dec r8
.outer_loop_main:
    cmp r8, 0
    jle .print_section_main
    xor r9, r9
.inner_loop_main:
    cmp r9, r8
    jge .end_inner_main

    ; pointer to block j
    mov rax, r9
    imul rax, BLOCK_SIZE
    lea rdi, [sorted]
    add rdi, rax

    ; pointer to block j+1
    mov rax, r9
    inc rax
    imul rax, BLOCK_SIZE
    lea rsi, [sorted]
    add rsi, rax

    call str_cmp
    cmp rax, 0
    jle .no_swap_main

    ; swap block j & j+1
    mov rax, r9
    imul rax, BLOCK_SIZE
    lea rdi, [sorted]
    add rdi, rax

    mov rax, r9
    inc rax
    imul rax, BLOCK_SIZE
    lea rsi, [sorted]
    add rsi, rax

    call swap_block

.no_swap_main:
    inc r9
    jmp .inner_loop_main

.end_inner_main:
    dec r8
    jmp .outer_loop_main

.print_section_main:
    ; print each block: name + ": " + color + bars + reset + " " + number + \n
    xor rbx, rbx
.print_loop_main:
    cmp rbx, NUM_ITEMS
    jge .done_main

    ; pointer to block = sorted + i*BLOCK_SIZE -> rsi (name)
    mov rax, rbx
    imul rax, BLOCK_SIZE
    lea rsi, [sorted]
    add rsi, rax
    call print_str

    ; print ": "
    mov rsi, sep
    call print_str

    ; print color_start_buf
    lea rsi, [color_start_buf]
    call print_str

    ; load quantity into rax and save to r14
    mov rax, rbx
    imul rax, BLOCK_SIZE
    lea rdx, [sorted]
    add rdx, rax
    add rdx, NAME_LEN
    mov rax, [rdx]
    mov r14, rax        ; keep original qty for printing (r14 callee-saved)

    ; print bars using barbuf and counter in r13
    mov r13, rax
.bar_loop_main:
    cmp r13, 0
    je .bars_done_main
    lea rsi, [barbuf]
    call print_str      ; print one char (barbuf is null-terminated)
    dec r13
    jmp .bar_loop_main
.bars_done_main:

    ; print reset color
    lea rsi, [color_reset_buf]
    call print_str

    ; space
    mov rsi, space
    call print_str

    ; print number (rax should be quantity => we set rax from r14)
    mov rax, r14
    call print_num

    ; newline
    mov rsi, newline
    call print_str

    inc rbx
    jmp .print_loop_main

.done_main:
    mov rax, 60
    xor rdi, rdi
    syscall

; -------------------------------------------------------
; small no-op print used in cfg_not_found path (just returns)
; -------------------------------------------------------
print_nop:
    ret

; -------------------------------------------------------
; constant keys
; -------------------------------------------------------
section .rodata
key_caracter db "caracter_barra",0
key_color_barra db "color_barra",0
key_color_fondo db "color_fondo",0
