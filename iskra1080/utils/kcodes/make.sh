#!/bin/sh

set -e

asm80 kcodes.asm -o kcodes.lvt
lvt2wav kcodes.lvt
