; inventario_visual.asm (fix final)
; Visualizador: ordena inventario y dibuja barras coloreadas (corrige SIGSEGV)
; - Guarda cantidad en r14 antes de hacer syscalls que pueden corromper punteros
; - Usa buffer estático para imprimir '*'

%define NAME_LEN 32
%define NUM_ITEMS 4
%define BLOCK_SIZE 40      ; NAME_LEN + 8 bytes (qword) para cantidad

section .data
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

newline     db 10,0
sep         db ": ",0
space       db " ",0

; ANSI color sequences (fijo por ahora)
color_start db 0x1b,"[92;40m",0  ; verde brillante (92) sobre fondo negro (40)
color_reset db 0x1b,"[0m",0

; buffer estático para imprimir una barra (un carácter)
barbuf      db '*',0

section .bss
sorted  resb BLOCK_SIZE * NUM_ITEMS
numBuf  resb 32

section .text
global _start

; -------------------------------------------------------
; print_str: imprime string en RSI (terminado en 0)
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
    mov rax, 1
    mov rdi, 1
    mov rdx, rcx
    syscall
    pop rcx
    pop rbx
    ret

; -------------------------------------------------------
; print_num: imprime entero positivo en RAX
; usa numBuf para construir el string
; -------------------------------------------------------
print_num:
    push rbx
    push rcx
    push rdx
    mov rbx, 10
    mov rcx, 0
    lea rdi, [numBuf + 31]   ; apuntador final
    mov byte [rdi], 0
.pn_loop:
    xor rdx, rdx
    div rbx          ; RAX = RAX / 10 ; RDX = RAX % 10
    add dl, '0'
    dec rdi
    mov [rdi], dl
    inc rcx
    test rax, rax
    jnz .pn_loop
    ; imprimir desde rdi (rcx bytes)
    mov rsi, rdi
    call print_str
    pop rdx
    pop rcx
    pop rbx
    ret

; -------------------------------------------------------
; str_cmp: compara cadenas en RDI vs RSI (C-strings)
; devuelve rax <0, =0, >0
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
; swap_block: intercambia BLOCK_SIZE bytes entre RDI y RSI
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
; START: copiar bloques nombre+cantidad a 'sorted'
; -------------------------------------------------------
_start:
    xor rbx, rbx                ; índice i = 0

.copy_loop:
    cmp rbx, NUM_ITEMS
    jge .after_copy

    ; src_name = names + i*NAME_LEN
    mov rax, rbx
    imul rax, NAME_LEN
    lea rsi, [names]
    add rsi, rax                ; rsi -> src_name

    ; dest_block = sorted + i*BLOCK_SIZE
    mov rax, rbx
    imul rax, BLOCK_SIZE
    lea rdx, [sorted]
    add rdx, rax                ; rdx -> dest_block_start

    ; copiar NAME_LEN bytes: rsi -> src_name, rdi -> dest_block
    mov rcx, NAME_LEN
    mov rdi, rdx
    rep movsb                   ; copia NAME_LEN bytes: rsi,rdi avanzan NAME_LEN

    ; copiar cantidad (8 bytes)
    mov rax, rbx
    imul rax, 8
    lea rsi, [qtys]
    add rsi, rax
    mov rax, [rsi]              ; rax = cantidad
    mov rdi, rdx
    add rdi, NAME_LEN
    mov [rdi], rax              ; store cantidad justo después del nombre

    inc rbx
    jmp .copy_loop

.after_copy:
    ; ---------------------------------------------------
    ; Bubble sort por nombre (usar blocks)
    ; ---------------------------------------------------
    mov r8, NUM_ITEMS
    dec r8                      ; r8 = n-1

.outer_loop:
    cmp r8, 0
    jle .print_section
    xor r9, r9                  ; r9 = j = 0

.inner_loop:
    cmp r9, r8
    jge .end_inner
    ; puntero block j = sorted + j*BLOCK_SIZE -> rdi
    mov rax, r9
    imul rax, BLOCK_SIZE
    lea rdi, [sorted]
    add rdi, rax

    ; puntero block j+1 -> rsi
    mov rax, r9
    inc rax
    imul rax, BLOCK_SIZE
    lea rsi, [sorted]
    add rsi, rax

    ; comparar nombres: rdi (name j), rsi (name j+1)
    call str_cmp               ; str_cmp lee rdi/rsi
    cmp rax, 0
    jle .no_swap_now

    ; swap blocks j <-> j+1
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

.no_swap_now:
    inc r9
    jmp .inner_loop

.end_inner:
    dec r8
    jmp .outer_loop

.print_section:
    ; imprimir sorted entries: nombre + ": " + barras color + cantidad
    xor rbx, rbx               ; i = 0

.print_items_loop:
    cmp rbx, NUM_ITEMS
    jge .done_print

    ; pointer to block = sorted + i*BLOCK_SIZE -> rsi (name)
    mov rax, rbx
    imul rax, BLOCK_SIZE
    lea rsi, [sorted]
    add rsi, rax
    call print_str

    ; imprimir ": "
    mov rsi, sep
    call print_str

    ; --- activar color ---
    mov rsi, color_start
    call print_str

    ; obtener cantidad (qword) en rax y guardar ptr cantidad en rdx
    mov rax, rbx
    imul rax, BLOCK_SIZE
    lea rdx, [sorted]
    add rdx, rax
    add rdx, NAME_LEN
    mov rax, [rdx]            ; rax = cantidad

    ; Guardar cantidad original en r14 y usar r13 como contador
    mov r14, rax              ; r14 = cantidad_original
    mov r13, rax              ; r13 = contador para barras

    ; imprimir barras: usar buffer estático barbuf
.bar_loop:
    cmp r13, 0
    je .bars_done
    ; imprimir 1 char desde buffer estático barbuf
    mov rax, 1
    mov rdi, 1
    lea rsi, [rel barbuf]
    mov rdx, 1
    syscall
    dec r13
    jmp .bar_loop

.bars_done:
    ; --- reset color ---
    mov rsi, color_reset
    call print_str

    ; espacio
    mov rsi, space
    call print_str

    ; imprimir número (usar r14 que guarda la cantidad original)
    mov rax, r14
    call print_num

    ; newline
    mov rsi, newline
    call print_str

    inc rbx
    jmp .print_items_loop

.done_print:
    mov rax, 60
    xor rdi, rdi
    syscall

