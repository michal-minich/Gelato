@echo off
rem rdmd --build-only -debug -gs -g -w -Ilib/pegged gg.d
gg
rem rdmd --build-only -debug -gs -g -w -ofgelato -Ilib/pegged main.d
dmd -debug -gs -g -w -ofgelato main.d gel.d lib/pegged/pegged/grammar.d lib/pegged/pegged/utils/associative.d lib/pegged/pegged/peg.d
del gelato.obj
gelato