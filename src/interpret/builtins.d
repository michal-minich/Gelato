module interpret.builtins;

import std.algorithm, std.array, std.conv, std.string;
import common, parse.ast, validate.remarks;


BuiltinFn[dstring] builtinFns;


static this ()
{
    builtinFns = [
        "print"d : new BuiltinFn("print"d, &customPrint, new TypeFn([new TypeAny], new TypeVoid))
       ,"inc"d : new BuiltinFn("inc"d, &incNum, new TypeFn([new TypeNum], new TypeNum))
    ];
}


private:


Exp customPrint (IInterpreterContext context, Exp[] exps)
{
    foreach (e; exps)
    {
        const txt = cast(ValueText)e;
        context.print(txt ? txt.value : e.str(fv));
    }
    context.println();
    return null;
}


Exp incNum (IInterpreterContext context, Exp[] exps)
{
    auto n = exps[0].sureCast!ValueNum();
    return new ValueNum(null, n.value + 1);
}