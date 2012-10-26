module interpret.declrfinder;

import std.algorithm, std.array, std.conv;
import common, parse.ast, validate.remarks, interpret.preparer, interpret.builtins;


@safe StmDeclr findDeclr (Exp[] exps, dstring name)
{
    foreach (e; exps)
    {
        auto d = cast(StmDeclr)e;
        if (d)
        {
            auto i = cast(ExpIdent)d.slot;
            if (i && i.text == name)
                return d;
        }
    }
    return null;
}


@safe StmDeclr getIdentDeclaredBy (ExpIdent ident)
{
    if (ident.declaredBy)
        return ident.declaredBy;

    auto bfn = ident.text in builtinFns;
    if (bfn)
    {
        auto d = new StmDeclr(null, null);
        d.value = *bfn;
        return d;
    }

    auto d = findIdentDelr (ident.parent, ident);
    if (!d)
    {
        d = new StmDeclr(ident.parent, ident);
        d.value = new AstUnknown(ident);
    }

    return d;
}


@trusted private StmDeclr findIdentDelr (Exp e, ExpIdent ident)
{
    StmDeclr d;
    d = findIdentDelrInExpOrParent(e, ident.text);
    if (d)
        return d;
else
        assert (false, ident.text.to!string() ~ " identifer is undefined");

    /*idents = idents[1 .. $];
    e = d;
    while (e && idents.length)
    {
    d = findIdentDelrInExp(idents[0], e);
    if (d)
    return d;
    idents = idents[1 .. $];
    e = d.value;
    }
    return d;*/
}


@safe StmDeclr findIdentDelrInExpOrParent (Exp e, dstring ident)
{
    StmDeclr d;
    while (e && !d)
    {
        d = findIdentDelrInExp(e, ident);
        e = e.parent;
    }
    return d;
}


@trusted private StmDeclr findIdentDelrInExp (Exp e, dstring ident)
{
    Exp[] exps;

    auto f = cast(ValueFile)e;
    if (f)
        exps = f.exps;

    auto s = cast(ValueStruct)e;
    if (s)
        exps = s.exps;

    if (exps.length)
    {
        foreach (e2; exps)
        {
            auto d = cast(StmDeclr)e2;
            if (d)
            {
                auto i = cast(ExpIdent)d.slot;
                if (i && i.text == ident)
                    return d;
            }
        }
        return null;
    }

    auto fn = cast(ValueFn)e;
    if (!fn)
    {
        auto lambda = (cast(ExpLambda)e);

        if (lambda)
        fn = lambda.fn;
    }

    if (fn)
    {
        foreach (p; fn.params)
        {
            auto i = cast(ExpIdent)p.slot;
                if (i && i.text == ident)
                    return p;
        }

        foreach (e2; fn.exps)
        {
            if (e2 is e)
                break;
            auto d = cast(StmDeclr)e2;
            if (d)
            {
                auto i = cast(ExpIdent)d.slot;
                if (i && i.text == ident)
                    return d;
            }
        }
    }

    return null;
}