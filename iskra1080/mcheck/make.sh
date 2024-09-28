#!/bin/sh

set -e

# pip install suite8080
asm80 mcheck.asm -o mcheck.lvt
lvt2wav mcheck.lvt
