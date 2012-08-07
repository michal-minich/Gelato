@echo off
dmd -debug -property -gs -g -w -ofgelato main.d common.d tokenizer.d
del gelato.obj
gelato.exe test.gel
