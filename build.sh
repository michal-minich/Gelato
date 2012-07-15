dmd -m64 -debug -property -gs -g -w -ofgelato main.d common.d tokenizer.d
rm gelato.o
./gelato test.gel
