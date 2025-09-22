; Punto de entrada para llamar a read_config
; Solo imprime el contenido de config.ini

global _start         ; punto de entrada para el linker
extern read_config    ; función que está en config_reader.asm

section .text
_start:
    call read_config  ; llama a la función que abre y lee config.ini

    ; salir del programa
    mov rax, 60       ; sys_exit
    xor rdi, rdi      ; código de salida = 0
    syscall
