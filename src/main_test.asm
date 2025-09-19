; main_test.asm - Llama a read_config y sale
section .text
    global _start
    extern read_config

_start:
    ; Llamamos a la función que lee el config y lo imprime
    call read_config

    ; Exit(0)
    mov rax, 60     ; sys_exit
    xor rdi, rdi
    syscall
