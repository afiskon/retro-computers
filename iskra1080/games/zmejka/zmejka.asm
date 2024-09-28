	; Игра "Змейка" для ПЭВМ Искра 1080 Тарту
	; Александр Алексеев, 2024
	; https://eax.me/

	org 234				; 234 = 0100h - 16 - 3*2

	; Заголовок LVT файла общим размером 16+3*2 байт
	; Этих данных реально не будет в программе

	db 'ISKRA1080', 0D0h, 'ZMEJKA'
	dw entry
	dw code_end
	dw entry

	; ----------- Адреса глобальных переменных -----------
	;   Под них я выделил адреса 08000h..08FFFh
	;   Важно! Эту память нужно инициализировать в коде
	; --- vvv ------------------------------------ vvv ---

	; Следующие два буфера должны иметь адреса выравненные до 256 байт,
	; то есть, ??00h. Это нужно для корректной работы с head_idx и tail_idx.
	; Также код использует тот факт, что xs и ys расположены подряд.

	xs equ 08000h 				; буфер X-координат змейки, 256 значений
	ys equ 08100h 				; буфер Y-координат змейки, 256 значений

	; Код использует тот факт, что что следующие значения идут подряд
	head_idx equ 08200h 		; хранит текущий индекс головы, 0..255
	tail_idx equ 08201h 		; хранит текущий индекс хвоста, 0..255
	delta_x  equ 08202h 		; (dx, dy) задают направление движения
	delta_y  equ 08203h
	fruit_x  equ 08204h 		; текущие координаты фрукта
	fruit_y  equ 08205h

	random_x_ptr  equ 08206h	; указатель внутри random_xs, размер: 2 байта
	random_y_ptr  equ 08208h 	; указатель внутри random_ys, размер: 2 байта

	; --- ^^^ --- Адреса глобальных переменных --- ^^^ ---

entry: 							; адрес точки входа: 0100h
	call show_intro				; информация об игре и инициализация ГПСЧ

new_game:
	mvi a, 009h					; темно-бирюзовый фон
	out 090h
	mvi a, 008h         		; серый
	out 091h
	mvi a, 00Eh         		; темно-красный текст
	out 092h
	mvi a, 007h        			; черный
	out 093h

	out 0F8h 					; режим 4-х цветов
	out 0B9h

	call draw_game_field 		; нарисовать игровое поле
	call init_game_state 		; инициализация состояния змейки
	call place_random_fruit 	; размещаем первый фрукт

game_loop: 						; основной цикл игры
	call game_loop_wait
	call move_head 				; передвинуть голову

	ora a 						; влетели в стену или в себя?
	jnz game_over 				; если да, то игра окончена

	call fruit_was_eaten 		; фрукт был съеден?
	ora a
	jz fruit_not_eaten

	lxi h, current_score
	inr m 						; увеличиваем счетчик фруктов
	mov a, m
	ani 003h 					; увеличиваем скорость каждые 4 фрукта
	jnz @F

	lxi h, game_loop_current_delay
	dcr m

@@: 							; увеличиваем человеко-читаемый счетчик фруктов
	lxi h, score_digits_last
@@:
	mov a, m
	cpi '9'
	jnz @F
	mvi m, '0' 					; текущий разряд равен девяти, пишем ноль ...
	dcx h 						; ... и переходим к более старшему разряду
	jmp @B

@@:
	inr m 						; увеличиваем значение разряда

	call place_random_fruit 	; если да, то нужен новый фрукт
	jmp game_loop 				; хвост не втягивается, благодаря чему и растем

fruit_not_eaten:
	call move_tail 				; втягиваем хвост
	jmp game_loop 				; в начало основного цикла игры

game_over:						; конец игры
	mvi a, 008h 				; перекрасить сцену в черно-белый (точнее, черно-серый)
	out 090h
	mvi a, 007h
	out 092h

	mvi a, 13
	call 0F7BEh					; X = 13
	mvi a, 23
	call 0F7DCh					; Y = 23

	mvi c, 0
	lxi h, score_message
	call 0F137h					; вывести "Score: "

	lxi h, score_digits
	call 0F137h 				; вывести количество фруктов

	lxi h, continue_message
	call 0F137h 				; вывести остаток сообщения

@@:
	call 0FB94h 				; опрос клавиатуры
	cpi 020h 					; если нажат пробел или enter, начать заново
	jz new_game
	cpi 00Dh
	jz new_game
	jmp @B						; иначе - ждать дальше

; Проверить, был ли съеден фрукт
; Возвращает:
;   A == 0 - фрукт не съеден
;   A != 0 - фрукт съеден
fruit_was_eaten:
	lxi h, head_idx
	mov a, m 					; A := индекс головы

	lxi h, xs 					; HL указывает на XS[0]
	mov l, a 					; HL указывает на XS[A]
	mov a, m 					; A := координата X головы

	inr h 						; Теперь HL указывает на YS[A]
	mov b, m 					; B := координата Y головы

	lxi h, fruit_x 				; HL указывает на fruit_x
	cmp m 						; координаты X головы и фрукта совпадают?
	jnz @F

	inx h 						; HL указывает на fruit_y
	mov a, b
	cmp m 						; координаты Y головы и фрукта совпадают?
	rz 							; если да, то фрукт съеден, вернуть A != 0

@@:
	xra a 						; фрукт не съеден, вернуть A == 0
	ret

; Вытянуть голову
;
; Важно _сначала_ проверить, не врежится ли будущая голова
; в тело змейки, и только _потом_ менять состояние тела.
;
; Возвращает:
;   A == 0 - игра продолжается
;   A != 0 - игра окончена
move_head:
	lxi h, head_idx
	mov a, m 					; A - индекс головы

	lxi h, xs
	mov l, a  					; HL указывает на X-координату головы

	mov b, m 					; B := X головы
	inr h 						; HL указывает на Y-координату головы
	mov c, m 					; C := Y головы

	push b 						; запомнить BC на стеке
	push h 						; запомнить HL на стеке

	lxi h, delta_x 				; HL указывает на delta_x
	mov d, m 					; D := delta_x, пригодится ниже
	mov a, d
	add b
	mov b, a 					; B := новая координата X головы

	inx h 						; HL указывает на delta_y
	mov e, m 					; E := delta_y, пригодится ниже
	mov a, e
	add c
	mov c, a 					; C := новая координата Y головы

	pop h 						; восстанавливаем HL (старое значение BC еще на стеке)

	call xy_is_snakes_body 		; сами в себя не врезались?
	ora a
	jz @F
	pop b 						; восстанавливаем состояние стека
	ret 						; гейм овер, вернуть A != 0

@@:
	call xy_is_field_border		; в границу игрового поля не врезались?
	ora a
	jz @F
	pop b 						; восстанавливаем состояние стека
	ret 						; гейм овер, вернуть A != 0

@@:
	inr l 						; HL указывает на ячейку для новой Y-координаты головы

	mov m, c 					; записываем новую Y-координат головы
	dcr h 						; HL указывает на ячейку для новой X-координаты головы
	mov m, b 					; записываем новую X-координату головы

	push h 						; запомнили HL на стеке (старое значение BC все еще на стеке)

	lxi h, head_idx
	inr m 						; head_idx = (head_idx + 1) % 256

	; На данный момент D хранит копию delta_x, а E хранит копию delta_y
	; В зависимости от их значений выбираем одно из 4-х изображений головы
	mov a, e
	cpi 1 						; delta_y == 1 ?
	jnz @F
	lxi h, img_head_top
	jmp _move_head_draw_head_image
@@:
	cpi 0FFh 					; delta_y == -1 ?
	jnz @F
	lxi h, img_head_bottom
	jmp _move_head_draw_head_image
@@:
	mov a, d
	cpi 1 						; delta_x == 1 ?
	jnz @F
	lxi h, img_head_left 		; delta_x == 1 это влево, так как (0,0) у нас в правом нижнем углу
	jmp _move_head_draw_head_image
@@:
	lxi h, img_head_right

_move_head_draw_head_image:

	call draw_image

	pop h 						; восстановили HL, он указывает на X-координату головы
	pop b 						; восстановить (X,Y) того где раньше была голова

	dcr l
	dcr l 						; перемещаемся на две ячейки тела назад

	mov a, m 					; читаем X-координату
	inr h
	mov l, m 					; читаем Y-координату
	mov h, a 					; помещаем их в (H,L)

	; Итак, на данный момент:
	;  (B,C) = старые (X,Y) головы
	;  (H,L) = координаты (X,Y) за шаг до этого
	;  (D,E) = (delta_x, delta_y)
	;
	; Первым делом определим, изменилось ли направление движения

	mov a, b 					; если B - H != D, значит направление сменилось
	sub h
	cmp d
	jnz _move_head_direction_changed

	; Направление движения не изменилось, нужно выбрать
	; между img_body_vert и img_body_horiz

	mov a, d
	ora a 						; delta_x == 0 ?
	jnz @F
	lxi h, img_body_vert
	jmp _move_head_draw_body_image
@@:
	lxi h, img_body_horiz
	jmp _move_head_draw_body_image

	; Направление движения изменилось, нужно выбрать
	; один из 4-х вариантов изображения поворота

_move_head_direction_changed: 	; направление движения сменилось, но пока не ясно куда

	; если раньше двигались по X и направление сменилось,
	; значит свернули либо вверх, либо вниз

	ora a
	jnz _move_head_direction_changed_y

_move_head_direction_changed_x: ; свернули налево или направо
	mov a, c
	sub l
	dcr a 						; C - L == 1 ?
	jnz _previously_moved_bottom

	mov a, d
	dcr a 						; delta_x == 1 ?
	jnz @F

	; двигались вверх по Y и свернули налево
	lxi h, img_turn_bottom_left
	jmp _move_head_draw_body_image

@@:
	; двигались вверх по Y и свернули направо
	lxi h, img_turn_bottom_right
	jmp _move_head_draw_body_image

_previously_moved_bottom:

	mov a, d
	dcr a 						; delta_x == 1 ?
	jnz @F

	; двигались вниз по Y и свернули налево
	lxi h, img_turn_top_left
	jmp _move_head_draw_body_image

@@:
	; двигались вниз по Y и свернули направо
	lxi h, img_turn_top_right
	jmp _move_head_draw_body_image

_move_head_direction_changed_y: ; свернули вверх или вниз
	mov a, b
	sub h
	dcr a 						; B - H == 1 ?
	jnz _previously_moved_right

	mov a, e
	dcr a
	jnz @F 						; delta_y == 1 ?

	; двигались влево и свернули вверх
	lxi h, img_turn_top_right
	jmp _move_head_draw_body_image

@@:
	; двигались влево и свернули вниз
	lxi h, img_turn_bottom_right
	jmp _move_head_draw_body_image

_previously_moved_right:

	mov a, e
	dcr a
	jnz @F 						; delta_y == 1 ?

	; двигались вправо и свернули вверх
	lxi h, img_turn_top_left
	jmp _move_head_draw_body_image

@@:
	; двигались вправо и свернули вниз
	lxi h, img_turn_bottom_left

_move_head_draw_body_image:
	call draw_image

	xra a 						; игра продолжается, вернуть A == 0
	ret

; Втянуть хвост
move_tail:
	lxi h, tail_idx
	mov a, m 					; A - индекс хвоста
	inr m 	 					; увеличиваем индекс хвоста

	lxi h, xs
	mov l, a 					; HL указывает на X-координату хвоста

	mov b, m 					; B := X хвоста
	inr h 						; HL указывает на Y-координату хвоста
	mov c, m 					; C := Y хвоста

	xchg 						; запомнили HL в DE
	lxi h, img_grass
	call draw_image 			; затираем хвост
	xchg 						; восстановили HL

	inr l 						; HL указывает на Y-координату нового хвоста
	mov c, m
	dcr h 						; HL указывает на X-координату нового хвоста
	mov b, m 					; (B,C) = (X,Y) нового хвоста

	inr l 						; HL указывает на X-координату следующей части тела
	mov d, m
	inr h 						; HL указывает на Y-координату следующей части тела
	mov e, m 					; (D,E) = (X,Y) следующей за кончиком хвоста части тела

	; В зависимости от значений (B,C) и (D,E) выбрать одно из 4-х изображений кончика хвоста

	mov a, d
	sub b 						; A := D - B
	cpi 1 						; dx хвоста = 1 ?
	jnz @F
	lxi h, img_tail_left
	jmp _move_tail_draw_tail_image
@@:
	cpi 0FFh 					; dx хвоста = -1 ?
	jnz @F
	lxi h, img_tail_right
	jmp _move_tail_draw_tail_image
@@:
	mov a, e
	sub c 						; A := E - C
	cpi 1 						; dy хвоста = 1 ?
	jnz @F
	lxi h, img_tail_top
	jmp _move_tail_draw_tail_image
@@:
	lxi h, img_tail_bottom

_move_tail_draw_tail_image:

	call draw_image
	ret

; Поместить фрукт по случайным координатам не принадлежащим змейке
; Обновляет fruit_x и fruit_y
; Возвращает:
;   (B,C) = копия значения (fruit_x, fruit_y)
; Портит значение всех остальных регистров
place_random_fruit:
	call gen_random_xy			; (B,C) := случайные (X,Y)
	call xy_is_snakes_body
	ora a
	jnz place_random_fruit		; фрукт попал на змейку - попробовать снова

	; Чтобы выбрать между картинками fruit1 и fruit2
	; воспользуемся текущим значением head_idx как
	; относительно случайным

	lxi h, head_idx
	mov a, m
	ani 1
	jnz @F 						; head_idx & 1 == 1 ?

	lxi h, img_fruit1
	jmp _draw_random_fruit

@@:
	lxi h, img_fruit2

_draw_random_fruit:
	call draw_image

	lxi h, fruit_x 				; сохранить (X,Y) фрукта
	mov m, b
	inx h
	mov m, c
	ret

; Проверить, принадлежит ли координата (X,Y) границе игрового поля
;
; Аргументы:
;   B - координата X
;   C - координата Y
;
; Возвращает:
;   A == 0 - не принадлежит
;   A != 0 - принадлежит
xy_is_field_border:
	mov a, b
	cpi 2 						; X == 2 ?
	rz 							; X на границе поля, вернуть A != 0
	cpi 21 						; X == 21 ?
	rz 							; X на границе поля, вернуть A != 0

	mov a, c
	ora a 						; Y == 0 ?
	jnz @F
	inr a 						; Y на границе поля, вернуть A != 0
	ret
@@:
	cpi 15 						; Y == 15 ?
	rz 							; Y на границе поля, вернуть A != 0

	xra a 						; (X,Y) не на границе поля, вернуть A == 0
	ret

; Проверить, принадлежит ли координата (X,Y) змейке
; Аргументы:
;   B - координата X
;   C - координата Y
; Возвращает:
;   A == 0 - не принадлежит
;   A != 0 - принадлежит
xy_is_snakes_body:
	push h 						; запоминаем HL для удобства вызывающих
	push d 						; запоминаем DE для удобства вызывающих

	push b 						; запомнили BC на стеке
	lxi b, xs 					; BC := XS
	lxi d, ys 					; DE := YS
	lxi h, head_idx
	mov a, m 					; A хранит индекс головы
	mov c, a 					; BC указывает на X-координату головы
	mov e, a 					; DE указывает на Y-координату головы

	inx h 						; Теперь ссылается на tail_idx
	sub m
	inr a 						; A := (head_idx - tail_idx) + 1 то есть, длина змейки

	push b
	pop h 						; HL указывает на X-координату головы
	pop b 						; (B,C) = (X,Y) проверяемой точки

	; Итого перед входом в цикл:
	; HL указывает на X-координату головы
	; DE указывает на Y-координату головы
	; (B,C) = (X,Y) проверяемой точки
	; A - длина змейки
_check_next_body_coordinate:
	push psw					; запомнить A на стеке

	mov a, m
	cmp b 						; X == XS[i] ?
	jnz @F

	xchg 						; HL <-> DE
	mov a, m
	cmp c 						; Y == YS[i] ?
	xchg 						; не меняет состояние флагов
	jnz @F

	pop psw
	pop d
	pop h
	ret 						; точка принадлежит змейке, вернуть A != 0

@@:
	dcr l 						; идем по кольцевому списку назад, от головы к хвосту
	dcr e
	pop psw 					; восстановить A со стека
	dcr a
	jnz _check_next_body_coordinate

	pop d
	pop h
	ret 						; точка не принадлежит змейке, вернуть A == 0

; Инициализация состояния игры
; Вызывается после draw_game_field
init_game_state:
	; рисуем змейку из трех клеток
	mvi b, 11 					; X := 11
	mvi c, 1 					; Y := 1
	lxi h, img_tail_top
	call draw_image

	inr c
	lxi h, img_body_vert
	call draw_image

	inr c
	lxi h, img_head_top
	call draw_image

	; заполняем состояние игры
	lxi h, xs					; координаты X: 11, 11, 11
	mov m, b
	inx h
	mov m, b
	inx h
	mov m, b

	lxi h, ys					; координаты Y: 1, 2, 3
	mvi m, 1
	inx h
	mvi m, 2
	inx h
	mvi m, 3

	lxi h, head_idx				; индекс головы: 2
	mvi m, 2
	inx h
	xra a
	mov m, a            		; индекс хвоста: 0
	inx h
	mov m, a					; delta_x = 0
	inx h
	mvi m, 1 					; delta_y = 1

	lxi h, game_loop_current_delay
	mvi m, 67 					; сбрасываем скорость, если это не первая игра
	inx h						; HL := current_score
	mov m, a
	inx h 						; HL := score_digits
	mvi a, '0'
	mov m, a
	inx h
	mov m, a
	inx h
	mov m, a

	ret

; Рисуем игровое поле
draw_game_field:
	xra a
	mov b, a 					; B := 0, координата X
	mov c, a 					; C := 0, координата Y

_choose_field_image:
	lxi h, img_black			; рассмотрим вариант img_black
	mov a, b
	cpi 2               		; (X < 2) || (X >= 22) ?
	jm @F
	cpi 22
	jp @F

	lxi h, img_wall				; рассмотрим вариант img_wall
	call xy_is_field_border
	ora a
	jnz @F 						; рисуем стену по границе игрового поля

	lxi h, img_grass 			; если не img_black и не img_wall, то img_grass

@@:
	call draw_image

	inr b 						; X++
	mov a, b
	cpi 24 						; дошли до левого края экрана?
	jnz _choose_field_image

	mvi b, 0 					; X := 0
	inr c 						; Y++
	mov a, c
	cpi 16 						; дошли до верхнего края экрана?
	jnz _choose_field_image

	ret

; Нарисовать картинку 16x16 по координатам (X, Y)
;   (0, 0) - правый нижний угол
;   (23, 15) - левый верхний угол
;
; Аргументы:
;   B - координата X
;   C - координата Y
;   HL - адрес картинки
;
; Портит регистр A
;
; Примечание:
;   Как будто бы код можно переписать так, чтобы процедура
;   draw_image_calc_offset вызывалась только один раз.
;   Есть ли в этом  практический смысл - вопрос дискуссионный.
draw_image:
	push d 						; запомнить DE для удобства вызывающих

	push b 						; запомнить BC четыре раза
	push b
	push b
	push b

	mvi d, 090h 				; BC = 0x9000 + (X << 9) + (Y << 4)
	call draw_image_calc_offset
	call draw_image_copy_16_bytes

	pop b
	mvi d, 091h 				; BC = 0x9100 + (X << 9) + (Y << 4)
	call draw_image_calc_offset
	call draw_image_copy_16_bytes

	pop b
	mvi d, 0D0h 				; BC = 0xD000 + (X << 9) + (Y << 4)
	call draw_image_calc_offset
	call draw_image_copy_16_bytes

	pop b
	mvi d, 0D1h 				; BC = 0xD100 + (X << 9) + (Y << 4)
	call draw_image_calc_offset
	call draw_image_copy_16_bytes

	pop b
	pop d 						; восстановить DE
	ret

; Внутренняя подпрограмма для draw_image
; Вычисляет:
;   BC = 0x(ZZ)00 + (X << 9) + (Y << 4)
;   где ZZ передается через регистр D
;   B - координата X
;   C - координата Y
draw_image_calc_offset:
	mov a, b            
	rlc
	add d
	mov b, a
	mov a, c
	rlc
	rlc
	rlc
	rlc
	mov c, a
	ret

; Внутренняя подпрограмма для draw_image
; Копирует 16 байт из (HL) в (BC)
draw_image_copy_16_bytes:
	mvi d, 16 
@@:
	mov a, m
	stax b
	inx h
	inx b
	dcr d
	jnz @B
	ret

; Инициализация состояния для gen_random_xy
; При возврате HL хранит значение из random_x_ptr
init_random_xy:
	lxi h, random_ys
	shld random_y_ptr			; random_y_ptr указывает на random_ys[0]

	lxi h, random_xs
	shld random_x_ptr			; random_x_ptr указыввает на random_xs[0]
	ret

; Сгенерировать случайную координату (X, Y) на игровом поле
; Возвращаемые значения:
;   B - координата X, 3 .. 20
;   C - координата Y, 1 .. 14
; Портит значение регистра A
gen_random_xy:
	push h

	lhld random_x_ptr			; HL := random_x_ptr
	mov a, m
	ora a 						; достигли маркера конца массива 000h ?
	cz init_random_xy			; если да, перейти к началу массивов и обновить HL
	mov b, m
	inx h
	shld random_x_ptr

	lhld random_y_ptr			; HL := random_y_ptr
	mov c, m
	inx h
	shld random_y_ptr

	pop h
	ret

; Задержка основного цикла программы, плюс опрос клавиатуры
; За один вызов принимается одна смена направления движения
game_loop_wait:
	lxi h, game_loop_current_delay
	mov b, m 					; регистр B хранит счетчик вызовов short_delay
	mov c, b 					; если C != 0, то в этом вызове еще не меняли направление

@@:
	call short_delay

	mov a, c 					; в этом вызове game_loop_wait уже меняли направление?
	ora a
	jz _game_loop_wait_continue

	call 0FB94h 				; опрос клавиатуры
	cpi 088h 					; стрелка вверх
	jz _up_pressed
	cpi 077h 					; W
	jz _up_pressed
	cpi 082h 					; стрелка вниз
	jz _down_pressed
	cpi 073h 					; S
	jz _down_pressed
	cpi 084h 					; стрелка влево
	jz _left_pressed
	cpi 061h 					; A
	jz _left_pressed
	cpi 086h 					; стрелка вправо
	jz _right_pressed
	cpi 064h 					; D
	jz _right_pressed

_game_loop_wait_continue:
	dcr b
	jnz @B
	ret

_up_pressed: 					; (D,E) - потенциальные новые значения delta_x, delta_y
	mvi d, 0
	mvi e, 1
	jmp _try_changing_direction

_down_pressed:
	mvi d, 0
	mvi e, 0FFh
	jmp _try_changing_direction

_left_pressed:
	mvi d, 1
	mvi e, 0
	jmp _try_changing_direction

_right_pressed:
	mvi d, 0FFh
	mvi e, 0

_try_changing_direction:
	; пытаемся сменить (delta_x, delta_y) на (D, E)
	; смену направление движения на противоположное игорируем, иначе влетим сами в себя
	; если (delta_x + D == 0) && (delta_y + E == 0) то изменение игнорируется

	lxi h, delta_x
	mov a, m
	add d
	jnz @F

	inx h
	mov a, m
	add e
	jz _game_loop_wait_continue

@@:
	lxi h, delta_x
	mov m, d					; delta_x := D
	inx h
	mov m, e 					; delta_y := E
	mvi c, 0 					; C := 0, смена направления не принимается до следующего хода
	jmp _game_loop_wait_continue

; Вспомогательная программа для game_loop_wait
short_delay:
	mvi a, 0FFh
@@:
	dcr a
	jnz @B
	ret

; Показать информацию об игре и проинициализировать ГПСЧ
show_intro:
	call init_random_xy
	call 0F9A0h					; очистить экран
	mvi a, 18
	call 0F7BEh					; X = 18
	mvi a, 9
	call 0F7DCh					; Y = 9
	lxi h, hello_message
	mvi c, 0
	call 0F137h					; вывести строку на экран

@@:
	call gen_random_xy			; инициализация ГПСЧ
	call 0FB94h					; опрос клавиатуры
	inr a
	jz @B 						; A == 0FFh ?

	ret

; Регулировка скорости игры
; Начальная задержка: 67
; Отнимаем 1 каждые 4 фрукта
; Максимум в игре можем съесть 252-3 = 249 фруктов
; 249 / 4 = 62
; 67 - 62 = 5 это минимальная задержка
; Важно! Код использует тот факт, что current_score и score_digits идут следом
game_loop_current_delay:
	db 67

; Сколько было съедено фруктов
current_score:
	db 0

; То же самое в десятичной системе, для отображения на экране
; в конце игры
score_digits:
	db '0'
	db '0'
score_digits_last:
	db '0'
	db 0

; см shuffled_field.py
random_xs:
	db 16, 13, 12, 18, 18, 7, 7, 7, 3, 15, 18, 5, 19, 8, 19, 18
	db 9, 8, 14, 3, 12, 7, 18, 20, 10, 10, 11, 3, 17, 19, 6, 11
	db 14, 16, 5, 14, 19, 4, 5, 7, 14, 20, 6, 3, 15, 4, 19, 20
	db 9, 16, 15, 17, 6, 9, 3, 8, 17, 9, 4, 20, 3, 17, 4, 19
	db 15, 11, 18, 4, 16, 9, 9, 15, 16, 12, 4, 14, 14, 12, 13, 7
	db 11, 6, 9, 5, 8, 18, 3, 7, 14, 17, 7, 13, 6, 5, 16, 10
	db 13, 18, 11, 17, 13, 14, 4, 4, 18, 15, 9, 13, 5, 6, 3, 7
	db 7, 19, 12, 13, 14, 20, 19, 20, 16, 15, 12, 4, 6, 8, 13, 12
	db 4, 6, 16, 13, 3, 8, 19, 10, 6, 8, 14, 9, 4, 17, 10, 13
	db 7, 20, 14, 7, 8, 10, 19, 12, 9, 5, 11, 18, 13, 12, 8, 17
	db 15, 10, 12, 18, 9, 17, 4, 4, 10, 17, 9, 16, 11, 10, 19, 16
	db 6, 10, 18, 8, 11, 10, 16, 12, 9, 20, 9, 14, 6, 15, 20, 11
	db 5, 10, 13, 15, 6, 13, 12, 10, 17, 20, 5, 7, 14, 17, 4, 12
	db 19, 19, 11, 17, 5, 7, 8, 3, 6, 14, 8, 20, 12, 5, 11, 16
	db 15, 17, 3, 16, 15, 11, 15, 20, 11, 5, 5, 5, 13, 6, 15, 20
	db 20, 11, 10, 18, 18, 3, 8, 19, 16, 8, 3, 3
	db 0 ; маркер конца массива

random_ys:
	db 11, 1, 4, 11, 5, 10, 6, 12, 14, 12, 13, 5, 1, 8, 7, 4
	db 10, 13, 2, 4, 12, 8, 9, 9, 1, 9, 10, 10, 7, 8, 5, 7
	db 9, 2, 3, 8, 2, 1, 1, 2, 4, 14, 8, 7, 3, 9, 6, 12
	db 8, 7, 9, 12, 1, 9, 2, 7, 3, 5, 7, 1, 1, 8, 4, 5
	db 8, 13, 12, 2, 5, 2, 14, 1, 4, 1, 5, 10, 6, 11, 3, 9
	db 8, 6, 13, 11, 5, 8, 9, 13, 7, 6, 11, 9, 3, 14, 8, 6
	db 12, 14, 2, 5, 13, 5, 10, 6, 7, 4, 11, 11, 2, 4, 3, 14
	db 7, 3, 7, 10, 12, 10, 12, 2, 10, 10, 3, 3, 13, 9, 8, 14
	db 8, 10, 6, 7, 12, 10, 4, 3, 7, 2, 14, 3, 14, 2, 12, 5
	db 3, 11, 13, 4, 12, 7, 11, 6, 12, 9, 14, 2, 4, 2, 6, 1
	db 14, 4, 10, 6, 6, 14, 11, 12, 11, 10, 7, 9, 3, 14, 14, 14
	db 14, 5, 1, 14, 1, 2, 13, 9, 1, 13, 4, 3, 12, 7, 4, 4
	db 4, 8, 14, 2, 2, 2, 13, 13, 4, 5, 8, 1, 1, 11, 13, 8
	db 13, 9, 11, 9, 7, 5, 4, 8, 11, 11, 3, 8, 5, 6, 5, 12
	db 5, 13, 11, 1, 6, 9, 11, 6, 6, 12, 13, 10, 6, 9, 13, 7
	db 3, 12, 10, 10, 3, 13, 11, 10, 3, 1, 6, 5

img_wall:
	db 000h, 0EFh, 0EFh, 0EFh, 000h, 0FEh, 0FEh, 0FEh, 000h, 0EFh, 0EFh, 0EFh, 000h, 0FEh, 0FEh, 0FEh
	db 000h, 0EFh, 0EFh, 0EFh, 000h, 0FEh, 0FEh, 0FEh, 000h, 0EFh, 0EFh, 0EFh, 000h, 0FEh, 0FEh, 0FEh
	db 0FFh, 010h, 010h, 010h, 0FFh, 001h, 001h, 001h, 0FFh, 010h, 010h, 010h, 0FFh, 001h, 001h, 001h
	db 0FFh, 010h, 010h, 010h, 0FFh, 001h, 001h, 001h, 0FFh, 010h, 010h, 010h, 0FFh, 001h, 001h, 001h

img_grass:
	db 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h
	db 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h
	db 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h
	db 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h

img_black:
	db 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh
	db 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh
	db 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh
	db 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh

img_fruit1:
	db 000h, 000h, 000h, 000h, 000h, 000h, 010h, 020h, 020h, 0A0h, 0C0h, 080h, 080h, 000h, 000h, 000h
	db 000h, 000h, 000h, 000h, 000h, 000h, 004h, 002h, 001h, 000h, 000h, 003h, 007h, 006h, 000h, 000h
	db 000h, 038h, 07Ch, 07Ch, 074h, 038h, 010h, 020h, 020h, 0A0h, 0C0h, 080h, 080h, 000h, 000h, 000h
	db 000h, 00Eh, 01Fh, 01Fh, 01Fh, 00Eh, 004h, 002h, 001h, 000h, 000h, 003h, 007h, 006h, 000h, 000h

img_fruit2:
	db 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 080h, 060h, 070h, 030h, 000h, 000h
	db 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 001h, 006h, 000h, 000h, 000h
	db 000h, 0E0h, 0F0h, 0F8h, 0FCh, 0FEh, 0FEh, 0FEh, 0F6h, 0FCh, 0B8h, 060h, 070h, 030h, 000h, 000h
	db 000h, 003h, 007h, 00Fh, 01Fh, 03Fh, 03Fh, 03Fh, 03Fh, 01Fh, 00Eh, 001h, 006h, 000h, 000h, 000h

img_head_top:
	db 0C0h, 0C0h, 0C0h, 0E0h, 0F0h, 0F8h, 0F8h, 0F8h, 0F8h, 0D8h, 098h, 0F0h, 0E0h, 0C0h, 000h, 000h
	db 003h, 003h, 003h, 007h, 00Fh, 01Fh, 01Fh, 01Fh, 01Fh, 01Bh, 019h, 00Fh, 007h, 003h, 000h, 000h
	db 020h, 020h, 020h, 010h, 008h, 004h, 004h, 004h, 004h, 024h, 064h, 008h, 010h, 020h, 0C0h, 000h
	db 004h, 004h, 004h, 008h, 010h, 020h, 020h, 020h, 020h, 024h, 026h, 010h, 008h, 004h, 003h, 000h
	
img_head_left:
	db 000h, 000h, 000h, 0E0h, 0F0h, 0F8h, 0FFh, 0FFh, 0FFh, 0FFh, 0F8h, 0F0h, 0E0h, 000h, 000h, 000h
	db 000h, 000h, 000h, 007h, 00Fh, 019h, 03Bh, 03Fh, 03Fh, 03Bh, 019h, 00Fh, 007h, 000h, 000h, 000h
	db 000h, 000h, 0E0h, 010h, 008h, 007h, 000h, 000h, 000h, 000h, 007h, 008h, 010h, 0E0h, 000h, 000h
	db 000h, 000h, 007h, 008h, 010h, 026h, 044h, 040h, 040h, 044h, 026h, 010h, 008h, 007h, 000h, 000h

img_head_right:
	db 000h, 000h, 000h, 0E0h, 0F0h, 098h, 0DCh, 0FCh, 0FCh, 0DCh, 098h, 0F0h, 0E0h, 000h, 000h, 000h
	db 000h, 000h, 000h, 007h, 00Fh, 01Fh, 0FFh, 0FFh, 0FFh, 0FFh, 01Fh, 00Fh, 007h, 000h, 000h, 000h
	db 000h, 000h, 0E0h, 010h, 008h, 064h, 022h, 002h, 002h, 022h, 064h, 008h, 010h, 0E0h, 000h, 000h
	db 000h, 000h, 007h, 008h, 010h, 0E0h, 000h, 000h, 000h, 000h, 0E0h, 010h, 008h, 007h, 000h, 000h

img_head_bottom:
	db 000h, 000h, 0C0h, 0E0h, 0F0h, 098h, 0D8h, 0F8h, 0F8h, 0F8h, 0F8h, 0F0h, 0E0h, 0C0h, 0C0h, 0C0h
	db 000h, 000h, 003h, 007h, 00Fh, 019h, 01Bh, 01Fh, 01Fh, 01Fh, 01Fh, 00Fh, 007h, 003h, 003h, 003h
	db 000h, 0C0h, 020h, 010h, 008h, 064h, 024h, 004h, 004h, 004h, 004h, 008h, 010h, 020h, 020h, 020h
	db 000h, 003h, 004h, 008h, 010h, 026h, 024h, 020h, 020h, 020h, 020h, 010h, 008h, 004h, 004h, 004h

img_turn_top_right:
	db 000h, 000h, 000h, 000h, 000h, 000h, 0FFh, 0D7h, 0EBh, 0FFh, 060h, 0C0h, 040h, 0C0h, 0C0h, 0C0h
	db 000h, 000h, 000h, 000h, 000h, 000h, 000h, 001h, 003h, 003h, 003h, 002h, 003h, 002h, 003h, 003h
	db 000h, 000h, 000h, 000h, 000h, 0FFh, 000h, 028h, 014h, 000h, 09Fh, 020h, 0A0h, 020h, 020h, 020h
	db 000h, 000h, 000h, 000h, 000h, 000h, 001h, 002h, 004h, 004h, 004h, 005h, 004h, 005h, 004h, 004h

img_turn_top_left:
	db 000h, 000h, 000h, 000h, 000h, 000h, 000h, 080h, 0C0h, 0C0h, 040h, 0C0h, 040h, 0C0h, 0C0h, 0C0h
	db 000h, 000h, 000h, 000h, 000h, 000h, 0FFh, 0D7h, 0EBh, 0FFh, 007h, 002h, 003h, 002h, 003h, 003h
	db 000h, 000h, 000h, 000h, 000h, 000h, 080h, 040h, 020h, 020h, 0A0h, 020h, 0A0h, 020h, 020h, 020h
	db 000h, 000h, 000h, 000h, 000h, 0FFh, 000h, 028h, 014h, 000h, 0F8h, 005h, 004h, 005h, 004h, 004h

img_turn_bottom_right:
	db 0C0h, 0C0h, 040h, 0C0h, 040h, 0E0h, 0FFh, 0D7h, 0EBh, 0FFh, 000h, 000h, 000h, 000h, 000h, 000h
	db 003h, 003h, 003h, 002h, 003h, 002h, 003h, 003h, 001h, 000h, 000h, 000h, 000h, 000h, 000h, 000h
	db 020h, 020h, 0A0h, 020h, 0A0h, 01Fh, 000h, 028h, 014h, 000h, 0FFh, 000h, 000h, 000h, 000h, 000h
	db 004h, 004h, 004h, 005h, 004h, 005h, 004h, 004h, 002h, 001h, 000h, 000h, 000h, 000h, 000h, 000h

img_turn_bottom_left:
	db 0C0h, 0C0h, 040h, 0C0h, 040h, 0C0h, 0C0h, 0C0h, 080h, 000h, 000h, 000h, 000h, 000h, 000h, 000h
	db 003h, 003h, 003h, 002h, 003h, 006h, 0FFh, 0D7h, 0EBh, 0FFh, 000h, 000h, 000h, 000h, 000h, 000h
	db 020h, 020h, 0A0h, 020h, 0A0h, 020h, 020h, 020h, 040h, 080h, 000h, 000h, 000h, 000h, 000h, 000h
	db 004h, 004h, 004h, 005h, 004h, 0F9h, 000h, 028h, 014h, 000h, 0FFh, 000h, 000h, 000h, 000h, 000h

img_tail_top:
	db 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 080h, 080h, 0C0h, 040h, 0C0h, 040h, 0C0h, 0C0h
	db 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 001h, 001h, 003h, 003h, 002h, 003h, 002h, 003h
	db 000h, 000h, 000h, 000h, 000h, 000h, 000h, 080h, 040h, 040h, 020h, 0A0h, 020h, 0A0h, 020h, 020h
	db 000h, 000h, 000h, 000h, 000h, 000h, 000h, 001h, 002h, 002h, 004h, 004h, 005h, 004h, 005h, 004h

img_tail_left:
	db 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h
	db 000h, 000h, 000h, 000h, 000h, 000h, 0FCh, 0AFh, 0D7h, 0FCh, 000h, 000h, 000h, 000h, 000h, 000h
	db 000h, 000h, 000h, 000h, 000h, 000h, 000h, 080h, 080h, 000h, 000h, 000h, 000h, 000h, 000h, 000h
	db 000h, 000h, 000h, 000h, 000h, 0FCh, 003h, 050h, 028h, 003h, 0FCh, 000h, 000h, 000h, 000h, 000h

img_tail_right:
	db 000h, 000h, 000h, 000h, 000h, 000h, 03Fh, 0EBh, 0F5h, 03Fh, 000h, 000h, 000h, 000h, 000h, 000h
	db 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h
	db 000h, 000h, 000h, 000h, 000h, 03Fh, 0C0h, 014h, 00Ah, 0C0h, 03Fh, 000h, 000h, 000h, 000h, 000h
	db 000h, 000h, 000h, 000h, 000h, 000h, 000h, 001h, 001h, 000h, 000h, 000h, 000h, 000h, 000h, 000h

img_tail_bottom:
	db 0C0h, 040h, 0C0h, 040h, 0C0h, 0C0h, 080h, 080h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h
	db 003h, 003h, 002h, 003h, 002h, 003h, 001h, 001h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h
	db 020h, 0A0h, 020h, 0A0h, 020h, 020h, 040h, 040h, 080h, 000h, 000h, 000h, 000h, 000h, 000h, 000h
	db 004h, 004h, 005h, 004h, 005h, 004h, 002h, 002h, 001h, 000h, 000h, 000h, 000h, 000h, 000h, 000h

img_body_horiz:
	db 000h, 000h, 000h, 000h, 000h, 000h, 0FFh, 0D7h, 0EBh, 0FFh, 000h, 000h, 000h, 000h, 000h, 000h
	db 000h, 000h, 000h, 000h, 000h, 000h, 0FFh, 0D7h, 0EBh, 0FFh, 000h, 000h, 000h, 000h, 000h, 000h
	db 000h, 000h, 000h, 000h, 000h, 0FFh, 000h, 028h, 014h, 000h, 0FFh, 000h, 000h, 000h, 000h, 000h
	db 000h, 000h, 000h, 000h, 000h, 0FFh, 000h, 028h, 014h, 000h, 0FFh, 000h, 000h, 000h, 000h, 000h

img_body_vert:
	db 0C0h, 0C0h, 040h, 0C0h, 040h, 0C0h, 0C0h, 0C0h, 0C0h, 0C0h, 040h, 0C0h, 040h, 0C0h, 0C0h, 0C0h
	db 003h, 003h, 003h, 002h, 003h, 002h, 003h, 003h, 003h, 003h, 003h, 002h, 003h, 002h, 003h, 003h
	db 020h, 020h, 0A0h, 020h, 0A0h, 020h, 020h, 020h, 020h, 020h, 0A0h, 020h, 0A0h, 020h, 020h, 020h
	db 004h, 004h, 004h, 005h, 004h, 005h, 004h, 004h, 004h, 004h, 004h, 005h, 004h, 005h, 004h, 004h

hello_message:
	db 'ZMEJKA for Iskra 1080 Tartu', 00Dh
	db '                  ' ; 18 пробелов для выравнивания по центру
	db '        version 1.0', 00Dh
	db '                  '
	db ' Aleksander Alekseev  2024', 00Dh
	db 00Dh, 00Dh, 00Dh
	db '                  '
	db 'Press any key to start ...'
	db 0 ; маркер конца текста

score_message:
	db 'Score: '
	db 0

continue_message:
	db '. Press SPACE to continue.'
	db 0

code_end:
