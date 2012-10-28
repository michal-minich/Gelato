module interpret.builtins;

import std.algorithm, std.array, std.conv, std.string;
import common, parse.ast, validate.remarks, tester;


BuiltinFn[dstring] builtinFns;


static this ()
{
    builtinFns = [
    "print"   : new BuiltinFn(&customPrint, new TypeFn([new TypeAny], new TypeVoid))
   ,"inc"     : new BuiltinFn(&incNum, new TypeFn([new TypeNum], new TypeNum))
   ,"dec"     : new BuiltinFn(&decNum, new TypeFn([new TypeNum], new TypeNum))
   ,"=="      : new BuiltinFn(&eq, new TypeFn([new TypeAny, new TypeAny], new TypeNum))
   ,"==="     : new BuiltinFn(&eqTyped, new TypeFn([new TypeAny, new TypeAny], new TypeNum))
   ,"+"       : new BuiltinFn(&plusNum, new TypeFn([new TypeNum, new TypeNum], new TypeNum))
   ,"["       : new BuiltinFn(&array3test, new TypeFn([new TypeAny, new TypeAny, new TypeAny], new TypeNum))
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


Exp decNum (IInterpreterContext context, Exp[] exps)
{
    auto n = exps[0].sureCast!ValueNum();
    return new ValueNum(null, n.value - 1);
}


Exp eq (IInterpreterContext context, Exp[] exps)
{
    auto tfv = new TestFormatVisitor;
    auto a = exps[0].str(tfv);
    auto b = exps[1].str(tfv);
    return new ValueNum(null, a == b);
}


Exp eqTyped (IInterpreterContext context, Exp[] exps)
{
    return typeid(exps[0]) == typeid(exps[1])
        ? eq(context, exps)
        : new ValueNum(null, 0);
}


Exp plusNum (IInterpreterContext context, Exp[] exps)
{
    auto a = exps[0].sureCast!ValueNum();
    auto b = exps[1].sureCast!ValueNum();
    return new ValueNum(null, a.value + b.value);
}


Exp array3test (IInterpreterContext context, Exp[] exps)
{
    return new ValueText(null, "array3test");
}