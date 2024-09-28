#!/usr/bin/env python3

# Сгенерировать массив случайно перестановленных координат поля.
# Наличием такого массива решается сразу несколько проблем:
# - Координаты фруктов точно принадлежат игровому полю, меньше вычислений.
# - Если поле уже занято змейкой, просто берем следующее случайное поле из массива.
#   Можно было бы перебирать координаты, но тогда фрукты имели бы склонность
#   "прилипать" к змейке.
# - Не требуется сложный генератор случайных чисел

import random

xs = range(3, 21) # [3, 20]
ys = range(1, 15) # [1, 14]

points = [ (x, y) for x in xs for y in ys ]
random.shuffle(points)

cnt = 0
print("random_xs:", end = "")
for (x, _) in points:
	if cnt % 16 == 0:
		print("\n\tdb " + str(x), end = "")
	else:
		print(", " + str(x), end = "")
	cnt += 1

print("\n\tdb 0 ; маркер конца массива\n")

cnt = 0
print("random_ys:", end = "")
for (_, y) in points:
	if cnt % 16 == 0:
		print("\n\tdb " + str(y), end = "")
	else:
		print(", " + str(y), end = "")
	cnt += 1

print()
