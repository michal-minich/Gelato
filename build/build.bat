@echo off
pushd src > NUL
dmd -debug -gs -g -ofgelato.exe @..\build\buildargs.txt | ddemangle
del gelato.obj
move /Y gelato.exe ..\rel\
popd > NUL
rel\gelato.exe test.gel