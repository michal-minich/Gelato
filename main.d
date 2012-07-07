module main;

import std.stdio, std.array, std.algorithm, std.conv, std.utf, std.file;
import gel, ast, interpreter;




int main (string[] argv)
{
    auto pt = Gel.parse(toUTF32(readText!string("test.gel")));

    writeln(pt);

    auto ast1 = astFile(pt);

    //writeln(ast1);

    interpret(ast1);

    return 0;
}
