#!/usr/bin/env python3

# Deps: pip3 install Pillow

from PIL import Image
import argparse
import sys

parser = argparse.ArgumentParser(
    description='Convert PNG image to an ASM source code'
    )
parser.add_argument(
    '-i', '--input', metavar='F', type=str, required=True,
    help='Input file, 16x16 PNG image')
args = parser.parse_args()

im = Image.open(args.input)
if im.height != 16:
    print("Image height should be 16px")
    sys.exit(1)

if im.width != 16:
    print("Image width should be 16px")
    sys.exit(1)

# Primary = 0xD000+
# Secondary = 0x9000+
#
# Цвет    Primary   Secondary
#
# Blue    0         0
# Red     1         0
# Grey    0         1
# Black   1         1

blue = (54, 143, 180, 255)
red = (103, 46, 44, 255)
grey = (114, 114, 114, 255)
black = (0, 0, 0, 255)

rp = []
rs = []
lp = []
ls = []

# Сканируем картинку снизу вверх
for y in reversed(range(0, 16)):
    right_value_primary = 0
    right_value_secondary = 0
    left_value_primary = 0
    left_value_secondary = 0
    for x in range(0, 8):
        left_value_primary <<= 1
        left_value_secondary <<= 1

        px = im.getpixel((x, y))
        if px != blue and px != red and px != grey and px != black:
            print("Wrong color! x = {}, y = {}, px = {}".format(x, y, px))
            sys.exit(1)

        if px == red or px == black:
            left_value_primary |= 1

        if px == grey or px == black:
            left_value_secondary |= 1

    for x in range(8, 16):
        right_value_primary <<= 1
        right_value_secondary <<= 1

        px = im.getpixel((x, y))
        if px != blue and px != red and px != grey and px != black:
            print("Wrong color! x = {}, y = {}, px = {}".format(x, y, px))
            sys.exit(1)

        if px == red or px == black:
            right_value_primary |= 1

        if px == grey or px == black:
            right_value_secondary |= 1

    rp += [ right_value_primary ]
    rs += [ right_value_secondary ]
    lp += [ left_value_primary ]
    ls += [ left_value_secondary ]


for lst in [ rs, ls, rp, lp ]:
    print("\tdb " +  ", ".join([ "0{:02X}h".format(x) for x in lst ]))
