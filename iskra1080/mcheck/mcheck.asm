	org 234				; 234 = 0100h - 16 - 3*2

	db 'ISKRA1080', 0D0h, 'MCHECK'
	dw entry
	dw code_end
	dw entry

entry: 					; адрес 0100h
	lxi h, code_end

loop:
	mvi m, 055h			; пишем и читаем 55h
	mov a, m
	cpi 055h
	jnz error

	mvi m, 0AAh			; пишем и читаем AAh
	mov a, m
	cpi 0AAh
	jnz error

	inx h 				; инкремент HL
	mvi a, 0C7h			; HL == C700?
	cmp h
	jnz loop

	call 0F2BDh			; вывод значения HL
	lxi h, ok_message
	jmp show_message

error:
	call 0F2BDh			; вывод значения HL
	lxi h, fail_message

show_message:
	mvi c, 000h 		; маркер конца строки
	call 0F137h			; вывод строки
	ret

ok_message:
	db 00Dh, 'OK', 00Dh, 000h

fail_message:
	db 00Dh, 'FAIL', 00Dh, 000h
	
code_end: