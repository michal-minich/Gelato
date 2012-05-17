module main;

import std.stdio, std.array, std.algorithm, std.conv, std.utf, std.file;
import gel;

int main (string[] argv)
{
    auto parseTree1 = Gel.parse(toUTF32(readText!string("test.gel")));

    writeln(parseTree1);

    return 0;
}
