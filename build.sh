rdmd --build-only -m64 -debug -gs -g -w -Ilib/pegged gg.d
./gg
rdmd --build-only -m64 -debug -gs -g -w -ofgelato -Ilib/pegged main.d
