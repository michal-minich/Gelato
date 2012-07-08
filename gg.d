module gg;

import std.file, std.utf;
import pegged.grammar;


void main (string[] cmdArgs)
{
    auto fileName = cmdArgs[1];

    auto g = grammar (toUTF32(readText!string(fileName ~ ".peg")));

    write(fileName ~ ".d", "module " ~ fileName ~ ";\r\npublic import pegged.grammar;\r\n");

    if (cmdArgs.length >= 3)
    {
        auto dependencies = cmdArgs[2];
        append(fileName ~ ".d", "import " ~ dependencies ~ ";\r\n");
    }

    append(fileName ~ ".d", toUTF8(g));
}
