module gg;

import std.file,
       std.utf,
       pegged.grammar;


void main ()
{
    auto g = grammar (toUTF32(readText!string("gel.peg")));

    write("gel.d", "module gel;\r\npublic import pegged.grammar;\r\n");
    append("gel.d", toUTF8(g));
}
