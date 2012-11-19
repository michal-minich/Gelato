module interpret.builtins;

import std.algorithm, std.array, std.conv, std.string;
import common, ast, validate.remarks, tester, validate.inferer;


ValueBuiltinFn[dstring] builtinFns;


@trusted nothrow void initBuiltinFns ()
{
    try
    {
        if (builtinFns.length)
            return;

        builtinFns = [
        "print"   : new ValueBuiltinFn(&customPrint, new TypeFn(null, [TypeAny.single], TypeVoid.single))
       ,"readln"  : new ValueBuiltinFn(&customReadln, new TypeFn(null, [], TypeText.single))
       ,"toNum"   : new ValueBuiltinFn(&toNum, new TypeFn(null, [TypeText.single], TypeNum.single))
       ,"inc"     : new ValueBuiltinFn(&incNum, new TypeFn(null, [TypeNum.single], TypeNum.single))
       ,"dec"     : new ValueBuiltinFn(&decNum, new TypeFn(null, [TypeNum.single], TypeNum.single))
       ,"=="      : new ValueBuiltinFn(&eq, new TypeFn(null, [TypeAny.single, TypeAny.single], TypeNum.single))
       ,"==="     : new ValueBuiltinFn(&eqTyped, new TypeFn(null, [TypeAny.single, TypeAny.single], TypeNum.single))
       ,"+"       : new ValueBuiltinFn(&plusNum, new TypeFn(null, [TypeNum.single, TypeNum.single], TypeNum.single))
       ,"["       : new ValueBuiltinFn(&array, new TypeFn(null, [TypeAny.single], new TypeArray(null, null)))
       ,"TypeOf"  : new ValueBuiltinFn(&typeOf, new TypeFn(null, [TypeAny.single], new TypeType(null ,null)))
        ];
    }
    catch
    {
        assert (false);
    }
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


Exp customReadln (IInterpreterContext context, Exp[] exps)
{
    auto ln = context.readln();
    return new ValueText(null, ln[0 .. $ - 1]);
}


Exp toNum (IInterpreterContext context, Exp[] exps)
{
    auto n = sureCast!ValueText(exps[0]);
    return new ValueNum(null, n.value.to!long());
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


Exp array (IInterpreterContext context, Exp[] exps)
{
    return new ValueArray(null, exps);
}


Exp typeOf (IInterpreterContext context, Exp[] exps)
{
    auto i = new TypeInferer(context);
    return new TypeType(null, exps[0].infer(i));
}