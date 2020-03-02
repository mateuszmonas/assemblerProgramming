assume cs:kod , ds:dane

read_file macro handle, length, buffer
	push bx
	push cx
	push dx

	mov bx, handle	; przeniesienie uchwytu pliku do bx
	mov cx, length	; liczba bajtow do odczytania
	lea dx, buffer		; przeniesienie bufora danych do dx
	mov ah,3fh		; przerwanie wpisujace bajty z pliku do bx, przy niepowodzeniu cf=1
	int 21h			; odczytane dane w dx
	jc cannot_read_file
	
	pop dx
	pop cx
	pop bx
endm

encrypt macro buffer, key, length
	push di
	push si
	push cx
	
	mov cx, length		; wstawienie do cx dlugosci buforu
	lea di, buffer			; zaladowanie buforu do di
restart_cipher_string:
	lea si, key			; zaladowanie buforu do si
encrypt_string:
	cmp byte ptr [si], 0	; sprawdzenie czy klucz sie nie skonczyl
	je restart_cipher_string	; zresetowanie pozycji klucza
	mov dl, [si]			; przeniesienie aktualnego znaku z klucza do dl
	xor byte ptr [di], dl	; zaszywrowanie znaku z bufora ze znakiem klucza
	inc di				; przejscie do kolejnego znaku bufora
        inc si				; przejscie do kolejnego znaku klucza
        loop encrypt_string	;

	pop cx
	pop si
	pop di
endm

write_to_file macro handle, length, buffer
	push bx
	push cx
	push dx
	push ax
	
	mov bx,handle		; przeniesienie uchwytu pliku do bx
	
	mov al,2			; poczatek przesuniecia jako koniec pliku
	mov cx,0			; przesuniecie ustawione na 0
	mov dx,0			; przesuniecie ustawione na 0
	mov ah,42h			; przerwanie ustawiajace pozycje w pliku
	int 21h
	jc cannot_write_to_file
	
	pop ax
	
	mov cx,length	; liczba bajtow do odczytania
	lea dx, buffer		; przeniesienie bufora danych do dx
	mov ah,40h		; przerwanie wpisujace bajty z bx do pliku, przy niepowodzeniu cf=1
	int 21h			; wpisuje do ax ilosc wpisanych bajtow
	
	pop dx
	pop cx
	pop bx
endm

dane segment
	cannot_read_arguments_msg db "nie mozna odczytac argumentow",10,13,"poprawne wywoalnie:",10,13,'szyfr.exe  plik_wej  plik_wyj  "klucz do szyfrowania tekstu"$'
	cannot_open_file_msg db "nie mozna otworzyc pliku$"
	cannot_create_file_msg db "nie mozna stworzyc pliku$"
	cannot_read_file_msg db "nie mozna odczytac z pliku$"
	cannot_write_to_file_msg db "nie mozna wpisac do pliku$"
	cannot_close_file_msg db "nie mozna zamknac pliku$"
	message_encrypted_msg db "wiadomosc zaszyfrowana$"

	file_name_in db 128 dup(?),'$'
	file_name_out db 128 dup(?), '$'
	key db 128 dup(?),'$'
	buffer db 1024 dup(?), '$'
	
	file_in dw ?
	file_out dw ?
dane ends

stos segment stack
	dw 255 dup(?)
	stack_top	dw ?			; wierzchoek stosu
stos ends

kod segment
start:
	mov ax, seg dane
	mov ds,ax
	
	mov ax,seg stos 
	mov ss,ax					; inicjowanie stosu
	mov sp,offset stack_top
	
	call read_arguments
	
	call open_file
	
	call create_file
	
read_write:
	read_file file_in, 1024, buffer		; wczytaj bajty z file_in i wypisz ilosc bajtow do ax
	
	cmp ax, 0					; sprawdzenie czy cos zostalo wczytane
	je finish_read_write
	
	encrypt buffer, key, ax

	write_to_file file_out, ax, buffer	; wypisz bajty do file_out
	jmp read_write
	
finish_read_write:
	
	mov bx, file_in
	call close_file
	jc cannot_close_file
	
	mov bx, file_out
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

open_file proc
	push dx
	push ax
	
	lea dx, file_name_in		; laduje adres pliku do dx
	xor al,al				; ustawia tryb otwarcia pliku na read
	mov ah,3dh				; przerwanie otwierajace plik z dx, przy niepowodzeniu cf=1
	int 21h					; uchwyt pliku w ax
	jc cannot_open_file
	mov file_in, ax			; przeniesienie uchwytu pliku z ax do file_in
	
	pop ax
	pop dx
open_file endp

;	si - buffer do przewiniecia
skip_whitespace proc
skip_whitespace_loop:
	cmp byte ptr [si], 20h
	jne finish
	inc si
	jmp skip_whitespace_loop
finish:
	ret
skip_whitespace endp

;	dx - tekst do wypisania
print proc
	push ax
	
	mov ax,seg dane	
	mov ds,ax				; ustawinie segmentu ds na dane
	mov ah,09h				; wypisanie tekst z dx
	int 21h
	
	pop ax
	ret
print endp

create_file proc
	push dx
	push ax

	lea dx, file_name_out		; nazwa pliku do utworzenia
	xor cl,cl					; zerowanie atrybutow pliku
	mov ah,3ch				; przerwanie tworzace plik
	int 21h					; uchwyt pliku w ax	
	jc cannot_create_file
	mov file_out,ax			; przeniesienie uchwytu pliku z ax do file_in

	pop ax
	pop dx
	ret
create_file endp

read_arguments proc
	push bx
	push ax

	mov ah,51h				; przerwanie wczytujace do do bx zawartosc cmd po nazwie programu
	int 21h
	mov ds,bx				; przeniesienie zawartosci cmd do ds
	lea si,ds:[81h]			; zaladowanie adresu pierwszego znaku lini polecen do ds:si
	mov ax, seg file_name_in	
	mov es,ax				; ustawinie segmentu es na file_name_in
	lea di, file_name_in		; zaladowanie adresu file_name_in do es:di
	call skip_whitespace		
get_file_in_loop:
	cmp byte ptr [si], 0dh		; sprawdzenie czy podano za malo argumentow
	je read_error
	cmp byte ptr [si], 20h		; sprawdzenie czy dany argument sie skonczyl
	je get_file_out			; przejscie do wczytywania kolejnego argumentu
	mov dl,[si]				; przeniesienie aktualnego znaku wiersza polecen do dl
	mov byte ptr [di], dl		; zapisanie znaku do file_name_in
	inc di
	inc si
	jmp get_file_in_loop
get_file_out:
	mov byte ptr [di], 0		; dodanie null termination do file_name_in
	mov ax, seg file_name_out	
	mov es,ax				; ustawinie segmentu es na file_name_out
	lea di, file_name_out		; zaladowanie adresu file_name_out do es:di
	call skip_whitespace
get_file_out_loop:
	cmp byte ptr [si], 0dh		; sprawdzenie czy podano za malo argumentow
	je read_error
	cmp byte ptr [si], 20h		; sprawdzenie czy dany argument sie skonczyl
	je get_key				; przejscie do wczytywania kolejnego argumentu
	mov dl,[si]				; przeniesienie aktualnego znaku wiersza polecen do dl
	mov byte ptr [di], dl		; zapisanie znaku do file_name_in
	inc di
	inc si
	jmp get_file_out_loop
get_key:
	mov byte ptr [di], 0		; dodanie null termination do file_name_out
	mov ax, seg key			
	mov es,ax				; ustawinie segmentu es na key
	lea di, key				; zaladowanie adresu key do es:di
	call skip_whitespace
	cmp byte ptr [si], 22h		; sprawdzenie czy argument klucza zaczyna sie od "
	jne read_error			
	inc si					; przejscie do pierwszego znaku klucza
	cmp byte ptr [si], 22h		; sprawdzenie czy klucz nie jest pusty
	je read_error			
get_key_loop:
	cmp byte ptr [si], 0dh		; sprawdzenie czy argumenty nie skonczyly sie przed skonczenie klucza
	je read_error
	cmp byte ptr [si], 22h		; sprawdzenie czy klucz sie skonczyl
	je finish_read_arguments
	mov dl,[si]				; przeniesienie aktualnego znaku wiersza polecen do dl
	mov byte ptr [di], dl		; zapisanie znaku do key
	inc di
	inc si
	jmp get_key_loop
read_error:
	jmp cannot_read_arguments
finish_read_arguments:
	mov byte ptr [di], 0		; dodanie null termination do key

	pop ax
	pop bx
	ret
read_arguments endp

;	bx - uchwyt pliku
close_file proc
	push ax
	
	mov ah,3eh				; przerwanie zamykajace plik z bx, przy niepowodzeniu cf=1
	int 21h					; ax zniszczone
	
	pop ax
	ret
close_file endp

finish_program proc			; konczy prace programu
	mov ah,4ch
	int 21h
	ret
finish_program endp


kod ends
end start