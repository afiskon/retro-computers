	org 234				; 234 = 0100h - 16 - 3*2

	db 'ISKRA1080', 0D0h, 'KCODES'
	dw entry
	dw code_end
	dw entry

; Некоторые коды:
; 020h - пробел
; 00Dh - enter
; 090h, 091h, 092h - F1, F2, F3
; 088h - стрелка вверх
; 082h - стрелка вниз
; 084h - стрелка влево
; 086h - стрелка вправо
; 085h - "5" на цифровой клавиатуре
; 077h - W
; 061h - A
; 073h - S
; 064h - D
; 030h..039h - клавиши 0..9 на основной клавиатуре

entry: 					; адрес 0100h
	lxi h, code_end

loop:
	call 0FB94h 		; опрос клавиатуры
	cpi 0FFh
	jz loop

	call 0F2C6h 		; вывод A на экран
	jmp loop
	
code_end: