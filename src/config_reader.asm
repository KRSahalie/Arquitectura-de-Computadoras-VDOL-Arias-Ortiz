; config_reader.asm  (NASM, x86_64)
; Abre "config.ini", lee hasta 512 bytes y los imprime en pantalla.
; Esto es el primer paso: verificar que podemos abrir y leer el archivo.
; Posteriormente añadiremos el parseo de "clave:valor".

section .data
    config_file    db "config.ini", 0
    msg_err_open   db "ERROR: no se pudo abrir config.ini", 10
    msg_err_open_len equ $ - msg_err_open

section .bss
    buffer resb 512        ; buffer donde leeremos el contenido
    bytes_read resq 1      ; guardar número de bytes leídos
    fd resq 1              ; file descriptor

section .text
    global read_config

; -------------------------------------------------------------------------
; read_config
; Abre config.ini, lee su contenido en 'buffer' y lo escribe en stdout.
; Usa syscalls en x86_64 (syscall instruction).
; -------------------------------------------------------------------------
read_config:
    ; -----------------------
    ; syscall: open(config_file, O_RDONLY)
    ; rax = 2 (sys_open), rdi = pointer filename, rsi = flags (0)
    ; -----------------------
    mov rax, 2                      ; sys_open
    lea rdi, [rel config_file]      ; pointer a "config.ini"
    xor rsi, rsi                    ; flags = 0 (O_RDONLY)
    xor rdx, rdx                    ; mode (no usado)
    syscall
    cmp rax, 0
    js .open_error                  ; si rax < 0 -> error
    mov [fd], rax                   ; guardar file descriptor

    ; -----------------------
    ; syscall: read(fd, buffer, 512)
    ; rax = 0 (sys_read), rdi = fd, rsi = buffer, rdx = len
    ; -----------------------
    mov rax, 0                      ; sys_read
    mov rdi, [fd]                   ; file descriptor
    lea rsi, [rel buffer]           ; buffer
    mov rdx, 512                    ; bytes max a leer
    syscall
    cmp rax, 0
    jle .close_and_return           ; si 0 o negativo, no hay nada
    mov [bytes_read], rax           ; guardar bytes leídos

    ; -----------------------
    ; syscall: write(1, buffer, bytes_read)
    ; rax = 1 (sys_write), rdi = 1 (stdout), rsi = buffer, rdx = nbytes
    ; -----------------------
    mov rax, 1                      ; sys_write
    mov rdi, 1                      ; stdout
    lea rsi, [rel buffer]
    mov rdx, [bytes_read]
    syscall

.close_and_return:
    ; cerrar el fd (si existe)
    mov rax, 3                      ; sys_close
    mov rdi, [fd]
    syscall
    ret

.open_error:
    ; en caso de error al abrir, imprimimos mensaje
    mov rax, 1
    mov rdi, 1
    lea rsi, [rel msg_err_open]
    mov rdx, msg_err_open_len
    syscall
    ret

