; программа проверки цветов и видеопамяти

	org 234				; 234 = 0100h - 16 - 3*2

	db 'ISKRA1080', 0D0h, 'CCHECK'
	dw entry
	dw code_end
	dw entry

entry: 					; адрес 0100h
	mvi a, 006h
	out 091h 			; светло-красный для режима 4 цвета

	mvi a, 005h
	out 092h 			; цвет текста - светло-зеленый

	mvi a, 003h
	out 093h 			; светло-синий для режима 4 цвета

	xra a 				; A := 0
	out 090h 			; цвет фона - белый

	out 0F8h 			; переходим в режим 4 цветов
	out 0B9h

loop:
	mvi c, 000h
	call fill_main
	call delay
	call fill_secondary
	call delay

	mvi c, 0FFh
	call fill_main
	call delay
	call fill_secondary
	call delay

	jmp loop			; программа зациклена

fill_main:				; заполнить память D000..FFFF значнием C
	lxi h, 0D000h
@@:
	mov m, c
	inx h
	mvi a, 0FFh
	cmp h 				; HL достиг FFFF?
	jnz @B
	cmp l
	jnz @B
	mov m, c 			; запись последнего байта
	ret

fill_secondary:			; заполнить память 9000..BFFF значением C
	lxi h, 09000h
@@:
	mov m, c
	inx h
	mvi a, 0BFh
	cmp h 				; HL достиг BFFF?
	jnz @B
	mvi a, 0FFh
	cmp l
	jnz @B
	mov m, c 			; запись последнего байта
	ret

delay:					; задержка, не меняет значение C
	mvi a, 0FFh
@@:
	dcr a
	jnz @B
	ret
	
code_end:
