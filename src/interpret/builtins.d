module interpret.builtins;

import std.algorithm, std.array, std.conv, std.string;
import common, syntax.ast, validate.remarks, test.TestFormatVisitor, interpret.TypeInferer, interpreter.DebugExpPrinter;


ExpAssign[dstring] builtinFns;


@trusted nothrow void initBuiltinFns ()
{
    try
    {
        if (builtinFns.length)
            return;

        builtinFns = [
        "print"   : bfn(&customPrint, new TypeFn(null, [TypeAny.single], TypeVoid.single))
       ,"readln"  : bfn(&customReadln, new TypeFn(null, [], TypeText.single))
       ,"toNum"   : bfn(&toNum, new TypeFn(null, [TypeText.single], TypeInt.single))
       ,"inc"     : bfn(&incNum, new TypeFn(null, [TypeInt.single], TypeInt.single))
       ,"dec"     : bfn(&decNum, new TypeFn(null, [TypeInt.single], TypeInt.single))
       ,"=="      : bfn(&eq, new TypeFn(null, [TypeAny.single, TypeAny.single], TypeInt.single))
       ,"==="     : bfn(&eqTyped, new TypeFn(null, [TypeAny.single, TypeAny.single], TypeInt.single))
       ,"+"       : bfn(&plusNum, new TypeFn(null, [TypeInt.single, TypeInt.single], TypeInt.single))
       ,"-"       : bfn(&minusNum, new TypeFn(null, [TypeInt.single, TypeInt.single], TypeInt.single))
       ,"*"       : bfn(&multiplyNum, new TypeFn(null, [TypeInt.single, TypeInt.single], TypeInt.single))
       ,"["       : bfn(&array, new TypeFn(null, [TypeAny.single], new TypeArray(null, null)))
       ,"!"       : bfn(&arrayIndex, new TypeFn(null, [TypeAny.single],TypeAny.single))
       ,"++"      : bfn(&arrayConcat, new TypeFn(null, [TypeAny.single],TypeAny.single))
       ,"TypeOf"  : bfn(&typeOf, new TypeFn(null, [TypeAny.single], new TypeType(null, null)))
       ,"dbg"     : bfn(&dbgExp, new TypeFn(null, [TypeAny.single], TypeVoid.single))
        ];
    }
    catch
    {
        assert (false);
    }
}


private:


nothrow ExpAssign bfn (A...) (A args) { return new ExpAssign(null, null, new ValueBuiltinFn(args)); }


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
    return new ValueInt(null, n.value.to!long());
}


Exp incNum (IInterpreterContext context, Exp[] exps)
{
    auto n = exps[0].sureCast!ValueInt();
    return new ValueInt(null, n.value + 1);
}


Exp decNum (IInterpreterContext context, Exp[] exps)
{
    auto n = exps[0].sureCast!ValueInt();
    return new ValueInt(null, n.value - 1);
}


Exp eq (IInterpreterContext context, Exp[] exps)
{
    auto tfv = new TestFormatVisitor;
    auto a = exps[0].str(tfv);
    auto b = exps[1].str(tfv);
    return new ValueInt(null, a == b);
}


Exp eqTyped (IInterpreterContext context, Exp[] exps)
{
    return typeid(exps[0]) == typeid(exps[1])
        ? eq(context, exps)
        : new ValueInt(null, 0);
}


Exp plusNum (IInterpreterContext context, Exp[] exps)
{
    auto a = exps[0].sureCast!ValueInt();
    auto b = exps[1].sureCast!ValueInt();
    return new ValueInt(null, a.value + b.value);
}


Exp minusNum (IInterpreterContext context, Exp[] exps)
{
    auto a = exps[0].sureCast!ValueInt();
    auto b = exps[1].sureCast!ValueInt();
    return new ValueInt(null, a.value - b.value);
}


Exp multiplyNum (IInterpreterContext context, Exp[] exps)
{
    auto a = exps[0].sureCast!ValueInt();
    auto b = exps[1].sureCast!ValueInt();
    return new ValueInt(null, a.value * b.value);
}


Exp array (IInterpreterContext context, Exp[] exps)
{
    return new ValueArray(null, exps);
}


Exp arrayIndex (IInterpreterContext context, Exp[] exps)
{
    auto arr = cast(ValueArray)exps[0];
    auto ix = cast(ValueInt)exps[1];
    return arr.items[cast(uint)ix.value];
}


Exp arrayConcat (IInterpreterContext context, Exp[] exps)
{
    auto arr1 = cast(ValueArray)exps[0];
    auto arr2 = cast(ValueArray)exps[1];
    return new ValueArray(null, arr1.items ~ arr2.items);
}


Exp typeOf (IInterpreterContext context, Exp[] exps)
{
    auto i = new TypeInferer(null, context);
    return new TypeType(null, exps[0].infer(i));
}


public Exp dbgExp (IInterpreterContext context, Exp[] exps)
{
    auto d = new DebugExpPrinter(context);
    auto e = exps[0];
    if (e)
        e.accept(d);
    return null;
}