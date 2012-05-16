module gg;

import std.file,
       std.utf,
       pegged.grammar;

void main ()
{
   /+ auto g = grammar("
        Expressions         <- Expression+
        Expression          <- ValueIdentifier / OperatorIdentifier / Expression
        OperatorIdentifier  <~ ([+*/] / '-')+
        ValueIdentifier     <~ [a-z_] [a-z_0-9]+
        EOI                 <- !.
        ");+/

    auto g = grammar (toUTF32(readText!string("gel.peg")));

    write("gel.d", "module gel;\r\nimport pegged.grammar;\r\n"d);
    append("gel.d", g);
}
