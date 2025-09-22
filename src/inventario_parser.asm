; inventario_parser.asm  (NASM x86_64)
; Lee inventario.txt y produce un buffer de salida donde
; ":" -> " " y se ignora el espacio inmediatamente siguiente.
; Finalmente hace un único write del buffer de salida.

section .data
    file_name      db "inventario.txt",0
    msg_err_open   db "ERROR abriendo inventario.txt",10,0

section .bss
    inbuf       resb 512
    outbuf      resb 512
    bytes_read  resq 1
    fd          resq 1

section .text
    global _start

_start:
    ; open(file_name, O_RDONLY)
    mov rax, 2
    lea rdi, [rel file_name]
    xor rsi, rsi
    xor rdx, rdx
    syscall
    cmp rax, 0
    js .open_error
    mov [fd], rax

    ; read(fd, inbuf, 512)
    mov rax, 0
    mov rdi, [fd]
    lea rsi, [rel inbuf]
    mov rdx, 512
    syscall
    cmp rax, 0
    jle .close_and_exit
    mov [bytes_read], rax

    ; close(fd)
    mov rax, 3
    mov rdi, [fd]
    syscall

    ; ---- transformar inbuf -> outbuf ----
    lea rsi, [rel inbuf]     ; rsi = puntero lectura
    lea rdi, [rel outbuf]    ; rdi = puntero escritura
    mov rbx, [bytes_read]    ; rbx = bytes a procesar (contador)
    xor r10d, r10d           ; r10 = flag skipNextSpace (0/1)

.process_loop:
    cmp rbx, 0
    je .done_build
    mov al, [rsi]            ; al = siguiente byte
    cmp al, ':'              ; si ':' -> poner espacio y activar skip
    je .handle_colon

    cmp r10d, 1
    jne .copy_char
    ; si r10 == 1 (debemos ignorar un espacio), y el char actual es espacio -> saltarlo
    cmp al, ' '
    jne .copy_char           ; si no es espacio, procesarlo normalmente
    ; si es espacio y skip flag = 1 -> ignorar este espacio
    inc rsi
    dec rbx
    xor r10d, r10d          ; resetear skip flag
    jmp .process_loop

.handle_colon:
    ; colocar un espacio en outbuf en lugar de ':'
    mov byte [rdi], ' '
    inc rdi
    inc rsi
    dec rbx
    mov r10d, 1              ; indicar que debemos ignorar un espacio si viene
    jmp .process_loop

.copy_char:
    mov byte [rdi], al
    inc rdi
    inc rsi
    dec rbx
    xor r10d, r10d          ; resetear skip flag (si estaba)
    jmp .process_loop

.done_build:
    ; longitud salida = rdi - outbuf
    lea rax, [rel outbuf]
    mov rdx, rdi
    sub rdx, rax            ; rdx = longitud final

    ; write(1, outbuf, rdx)
    mov rax, 1
    mov rdi, 1
    lea rsi, [rel outbuf]
    syscall

    ; exit(0)
    mov rax, 60
    xor rdi, rdi
    syscall

.open_error:
    mov rax, 1
    mov rdi, 1
    lea rsi, [rel msg_err_open]
    mov rdx, 22
    syscall

.close_and_exit:
    mov rax, 60
    xor rdi, rdi
    syscall

