#rdmd --build-only -m64 -debug -gs -g -w -Ilib/pegged gg.d
./gg
#rdmd --build-only -m64 -debug -gs -g -w -ofgelato -Ilib/pegged main.d
dmd -m64 -debug -property -gs -g -w -ofgelato main.d gel.d interpreter.d ast.d lib/pegged/pegged/grammar.d lib/pegged/pegged/utils/associative.d lib/pegged/pegged/peg.d
rm gelato.o
./gelato
