#!/bin/sh

set -e

asm80 zmejka.asm -o zmejka.lvt
lvt2wav zmejka.lvt
