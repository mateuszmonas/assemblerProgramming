assume cs:kod, ds:dane

dane segment
    include letters.asm
    text db 128 dup(?)
    zoom_string db 4 dup(?)
    zoom dw 1
    cannot_read_arguments_msg db "nie mozna odczytac argumentow",10,13,"poprawne wywolanie:",10,13,'zoom.exe text zoom$'
dane ends

stos segment stack
    dw 255 dup(?)
    stack_top  dw ?
stos ends

kod segment
start:
    mov ax,seg stos
    mov ss,ax
    mov sp,offset stack_top

    call read_argument

    mov ax,seg dane
    mov ds,ax

    mov al,13h
    mov ah,0
    int 10h

    mov ax, 0A000h
    mov es, ax

    mov di, offset text

    xor bx, bx              ; currently written letter no

writing_loop: 
    xor ax, ax
    mov al, byte ptr ds:[zoom]
    mul bx                  ; multiply letter number by zoom
    push bx                 ; save letter number
    mov bx, 8               ; set bx to letter width
    mul bx                  ; [letter width]*[letter number]*[zoom]
    pop bx                  ; restore letter number
    mov dx, ax

    mov si, offset letters
    xor ax, ax
    mov al, byte ptr ds:[di]
    shl ax, 1
    shl ax, 1
    shl ax, 1
    add si, ax
    call write_letter


    inc bx
    inc di
    cmp byte ptr ds:[di], 0
    jne writing_loop

finish_writing_loop:

    xor ax,ax
    int 16h

    mov al,3h
    mov ah,0
    int 10h

    call finish_program

cannot_read_arguments:
	mov dx, offset cannot_read_arguments_msg
    mov ax,seg dane	
	mov ds,ax
	mov ah,09h
	int 21h
    call finish_program

;==================================
; ds:[si] - offset of letter to write
; es:[dx] - offset of memory to write to
write_letter:
    push di
    push bx
    push dx
    
    mov al, 00000001b               ; set checking registry

    mov cx, 8
fill_letter:
    push cx


    mov cx,word ptr ds:[zoom]       ; fill zoom rows
    fill_row:
        push cx

        mov di, dx
        mov cx, 8

        fill_fragment:
            push cx

            mov bl, byte ptr ds:[si]        ; mov given row of bitmap to bl
            and bl, al                      ; check if given bit of bitmap is 1
            rol al, 1                       ; rotate checking registy

            mov cx,word ptr ds:[zoom]       ; fill given value zoom times
            fill:
                cmp bl, 0                   ; check if pixel should be filled
                je continue
                mov byte ptr es:[di], 13    ; fill pixel
            continue:
                inc di
            loop fill

            pop cx
            loop fill_fragment

        add dx, 320                         

        pop cx
        loop fill_row

    inc si                                  ; move to next row of bitmap
    pop cx
    loop fill_letter

    pop dx
    pop bx
    pop di
    ret
;==================================


;==================================
;	si - buffer to skip
skip_whitespace:
skip_whitespace_loop:
	cmp byte ptr [si], 20h
	jne finish
	inc si
	jmp skip_whitespace_loop
finish:
	ret
;==================================

;==================================
read_argument:
    mov si, 81h
    mov ax, seg dane
    mov es, ax
    mov di, offset text
    call skip_whitespace
get_text_loop:
	cmp byte ptr ds:[si], 0dh			; check if arguments have ended too early
	je read_error
	cmp byte ptr ds:[si], 20h			; check if given argument is finished
	je get_zoom						    ; go to parsing next argument
	mov dl,ds:[si]						; move given sign to dl
	mov byte ptr es:[di], dl			; save sign to text
	inc di
	inc si
	jmp get_text_loop

get_zoom:
	mov byte ptr es:[di], 0				; add null terminator to zoom_string
	mov di, offset zoom_string
	call skip_whitespace
get_zoom_loop:
	cmp byte ptr ds:[si], 0dh
	je finish_read_arguments
	cmp byte ptr ds:[si], 22h
	je finish_read_arguments
    cmp byte ptr ds:[si], 30h           ; check if ascii code is not lower than 0 code
	jb read_error
    cmp byte ptr ds:[si], 39h           ; check if ascii code is not greater than 9 code
	ja read_error

	mov dl,ds:[si]
	mov byte ptr es:[di], dl
	inc di
	inc si
	jmp get_zoom_loop
read_error:
	jmp cannot_read_arguments
finish_read_arguments:
	mov byte ptr es:[di], 0

    mov ax,seg dane
    mov ds,ax
    mov di, offset zoom_string
    call string_to_int
    mov word ptr ds:[zoom], ax

    ret
;==================================

;==================================
; ds:[di] - string offset
; ax - result of conversion
string_to_int:
    push bx
    xor ax, ax
    mov bx, 10
convert:
    cmp byte ptr ds:[di], 0
    je finish_convert

    sub byte ptr ds:[di], '0'
    mul bx
    add al, byte ptr ds:[di]
    inc di
    jmp convert
finish_convert:
    pop bx
    ret
;==================================

;==================================
finish_program:
	mov ah,4ch
	int 21h
	ret
;==================================

kod ends
end start

