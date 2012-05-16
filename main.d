module main;

import std.stdio, std.array, std.algorithm, std.conv;
import pegged.grammar;
import gel;

int main (string[] argv)
{
    auto parseTree1 = Gel.parse("abc");

    writeln(parseTree1);

    return 0;
}
