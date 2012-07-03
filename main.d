module main;

import std.stdio, std.array, std.algorithm, std.conv, std.utf, std.file;
import gel, ast, interpreter;

int main (string[] argv)
{
    auto pt = Gel.parse(toUTF32(readText!string("test.gel")));

    auto ast1 = astAll(pt);

    writeln(ast1);

    interpret(pt);

    return 0;
}
