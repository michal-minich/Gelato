dmd -m64 -debug -property -gs -g -w -ofgelato main.d common.d tokenizer.d ast.d parser.d interpreter.d
rm gelato.o
./gelato test.gel
