assume cs:kod , ds:dane

dane segment
	cannot_read_arguments_msg db "nie mozna odczytac argumentow",10,13,"poprawne wywolanie:",10,13,'szyfr.exe  plik_wej  plik_wyj  "klucz do szyfrowania tekstu"$'
	cannot_open_file_msg db "nie mozna otworzyc pliku$"
	cannot_create_file_msg db "nie mozna stworzyc pliku$"
	cannot_read_file_msg db "nie mozna odczytac z pliku$"
	cannot_write_to_file_msg db "nie mozna wpisac do pliku$"
	cannot_close_file_msg db "nie mozna zamknac pliku$"
	message_encrypted_msg db "wiadomosc zaszyfrowana$"
	
	file_in dw ?
	file_out dw ?
	file_name_in db 128 dup(?),'$'
	file_name_out db 128 dup(?), '$'
	key db 128 dup(?),'$'
	buffer db 128 dup(?), '$'
dane ends

stos segment stack
	dw 255 dup(?)
	stack_top	dw ?						; wierzchoek stosu
stos ends

kod segment
start:
	
	mov ax,seg stos 
	mov ss,ax								; inicjowanie stosu
	mov sp,offset stack_top

	call read_arguments
	
	mov ax, seg dane
	mov ds, ax

	call open_file
	
	call create_file
	
read_write:
	mov ax, 128
	call read_file							; wczytaj bajty z file_in i wypisz ilosc bajtow do ax
	
	cmp ax, 0								; sprawdzenie czy cos zostalo wczytane
	je finish_read_write
	
	call encrypt

	call write_to_file						; wypisz bajty do file_out
	jmp read_write
	
finish_read_write:
	
	mov bx, word ptr ds:[file_in]
	call close_file
	jc cannot_close_file
	
	mov bx, word ptr ds:[file_out]
	call close_file
	jc cannot_close_file
	
	jmp message_encrypted
	
cannot_read_arguments:
	mov dx, offset cannot_read_arguments_msg
	call print
	call finish_program
cannot_open_file:
	mov dx, offset cannot_open_file_msg
	call print
	call finish_program
cannot_create_file:
	mov dx, offset cannot_create_file_msg
	call print
	call finish_program
cannot_read_file:
	mov dx, offset cannot_read_file_msg
	call print
	call finish_program
cannot_write_to_file:
	mov dx, offset cannot_write_to_file_msg
	call print
	call finish_program
cannot_close_file:
	mov dx, offset cannot_close_file_msg
	call print
	call finish_program
message_encrypted:
	mov dx, offset message_encrypted_msg
	call print
	call finish_program


;==================================
open_file:
	push dx
	push ax
	
	mov dx, offset file_name_in			; laduje adres pliku do dx
	xor al,al							; ustawia tryb otwarcia pliku na read
	mov ah,3dh							; przerwanie otwierajace plik z dx, przy niepowodzeniu cf=1
	int 21h								; uchwyt pliku w ax
	jc cannot_open_file
	mov word ptr ds:[file_in], ax						; przeniesienie uchwytu pliku z ax do file_in
	
	pop ax
	pop dx
	ret
;==================================

;==================================
create_file:
	push dx
	push ax
	
 	mov dx, offset file_name_out		; nazwa pliku do utworzenia
	xor cl,cl							; zerowanie atrybutow pliku
	mov ah,3ch							; przerwanie tworzace plik
	int 21h								; uchwyt pliku w ax	
	jc cannot_create_file
	mov word ptr ds:[file_out], ax					; przeniesienie uchwytu pliku z ax do file_in

	pop ax
	pop dx
	ret
;==================================

;=================================
; input	ax - ilosc danych do odczytu
read_file:
	push bx
	push cx
	push dx
	
	mov cx, ax							; liczba bajtow do odczytania
	mov bx, word ptr ds:[file_in]						; przeniesienie uchwytu pliku do bx
	mov dx, offset buffer				; przeniesienie bufora danych do dx
	mov ah,3fh							; przerwanie wpisujace bajty z pliku do bx, przy niepowodzeniu cf=1
	int 21h								; odczytane dane w dx
	jc cannot_read_file
	
	pop dx
	pop cx
	pop bx
	ret
;==================================

;==================================
; input	ax - ilosc danych do odczytu
write_to_file:
	push bx
	push cx
	push dx
	push ax
	
	mov bx,file_out						; przeniesienie uchwytu pliku do bx
	mov al,2							; poczatek przesuniecia jako koniec pliku
	mov cx,0							; przesuniecie ustawione na 0
	mov dx,0							; przesuniecie ustawione na 0
	mov ah,42h							; przerwanie ustawiajace pozycje w pliku
	int 21h
	jc cannot_write_to_file
	
	pop ax
	
	mov cx,ax							; liczba bajtow do odczytania
	mov dx, offset buffer				; przeniesienie bufora danych do dx
	mov ah,40h							; przerwanie wpisujace bajty z bx do pliku, przy niepowodzeniu cf=1
	int 21h								; wpisuje do ax ilosc wpisanych bajtow
	
	pop dx
	pop cx
	pop bx
	ret
;==================================

;==================================
; input	ax - ilosc danych do odczytu
encrypt:
	push di
	push si
	push cx
	
	mov cx, ax							; wstawienie do cx dlugosci buforu
	dec cx			
	mov di, offset buffer				; zaladowanie buforu do di
restart_cipher_string:
	mov si, offset key					; zaladowanie buforu do si
encrypt_string:
	cmp byte ptr ds:[si], 0				; sprawdzenie czy klucz sie nie skonczyl
	je restart_cipher_string			; zresetowanie pozycji klucza
	mov dl, ds:[si]						; przeniesienie aktualnego znaku z klucza do dl
	xor byte ptr ds:[di], dl			; zaszywrowanie znaku z bufora ze znakiem klucza
	inc di								; przejscie do kolejnego znaku bufora
        inc si							; przejscie do kolejnego znaku klucza
        loop encrypt_string

	pop cx
	pop si
	pop di
	ret
;==================================

;==================================
;	si - buffer do przewiniecia
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
;	dx - tekst do wypisania
print:
	push ax
	
	mov ax,seg dane	
	mov ds,ax							; ustawinie segmentu ds na dane
	mov ah,09h							; wypisanie tekst z dx
	int 21h
	
	pop ax
	ret
;==================================

;==================================
read_arguments:
	push ax

	mov si, 81h							; zaladowanie adresu pierwszego znaku lini polecen do ds:si
	mov ax, seg dane
	mov es,ax
	mov di, offset file_name_in			; zaladowanie adresu file_name_in do es:di
	call skip_whitespace		
get_file_in_loop:
	cmp byte ptr ds:[si], 0dh			; sprawdzenie czy podano za malo argumentow
	je read_error
	cmp byte ptr ds:[si], 20h			; sprawdzenie czy dany argument sie skonczyl
	je get_file_out						; przejscie do wczytywania kolejnego argumentu
	mov dl,ds:[si]						; przeniesienie aktualnego znaku wiersza polecen do dl
	mov byte ptr es:[di], dl			; zapisanie znaku do file_name_in
	inc di
	inc si
	jmp get_file_in_loop
get_file_out:
	mov byte ptr es:[di], 0				; dodanie null termination do file_name_in
	mov di, offset file_name_out		; zaladowanie adresu file_name_out do es:di
	call skip_whitespace
get_file_out_loop:
	cmp byte ptr ds:[si], 0dh			; sprawdzenie czy podano za malo argumentow
	je read_error
	cmp byte ptr ds:[si], 20h			; sprawdzenie czy dany argument sie skonczyl
	je get_key							; przejscie do wczytywania kolejnego argumentu
	mov dl,ds:[si]						; przeniesienie aktualnego znaku wiersza polecen do dl
	mov byte ptr es:[di], dl			; zapisanie znaku do file_name_in
	inc di
	inc si
	jmp get_file_out_loop
get_key:
	mov byte ptr es:[di], 0				; dodanie null termination do file_name_out
	mov di, offset key					; zaladowanie adresu key do es:di
	call skip_whitespace
	cmp byte ptr ds:[si], 22h			; sprawdzenie czy argument klucza zaczyna sie od "
	jne read_error			
	inc si								; przejscie do pierwszego znaku klucza
	cmp byte ptr ds:[si], 22h			; sprawdzenie czy klucz nie jest pusty
	je read_error			
get_key_loop:
	cmp byte ptr ds:[si], 0dh			; sprawdzenie czy argumenty nie skonczyly sie przed skonczenie klucza
	je read_error
	cmp byte ptr ds:[si], 22h			; sprawdzenie czy klucz sie skonczyl
	je finish_read_arguments
	mov dl,ds:[si]						; przeniesienie aktualnego znaku wiersza polecen do dl
	mov byte ptr es:[di], dl			; zapisanie znaku do key
	inc di
	inc si
	jmp get_key_loop
read_error:
	jmp cannot_read_arguments
finish_read_arguments:
	mov byte ptr es:[di], 0				; dodanie null termination do key

	pop ax
	ret
;==================================

;==================================
;	bx - uchwyt pliku
close_file:
	push ax
	
	mov ah,3eh							; przerwanie zamykajace plik z bx, przy niepowodzeniu cf=1
	int 21h								; ax zniszczone
	
	pop ax
	ret
;==================================

;==================================
finish_program:							; konczy prace programu
	mov ah,4ch
	int 21h
	ret
;==================================

kod ends
end start
