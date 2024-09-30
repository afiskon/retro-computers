#!/bin/sh

set -e

asm80 ccheck.asm -o ccheck.lvt
lvt2wav ccheck.lvt
