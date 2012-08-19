module interpret.builtins;

import std.algorithm, std.array, std.conv, std.string;
import common, ast, remarks;


immutable Exp function (IInterpreterContext, Exp[])[dstring] customFns;


static this ()
{
    customFns = [
        "print" : &customPrint
        ];
}


private:


Exp customPrint (IInterpreterContext context, Exp[] exps)
{
    foreach (e; exps)
    {
        const txt = cast(AstText)e;
        context.print(txt ? txt.value : e.str(fv));
    }
    context.println();
    return null;
}