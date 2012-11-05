module interpret.declrfinder;

import common, parse.ast, validate.remarks, interpret.builtins;


@safe nothrow:


ExpAssign setIdentDeclaredBy (ExpIdent ident)
{
    if (ident.declaredBy)
        return ident.declaredBy;

    auto bfn = ident.text in builtinFns;
    if (bfn)
    {
        auto d = new ExpAssign(null, null);
        d.value = *bfn;
        ident.declaredBy = d;
        return d;
    }

    auto d = findIdentDelr (ident.parent, ident);

    if (!d)
    {
        d = new ExpAssign(null, ident);
        d.value = new ValueUnknown(ident);
    }

    ident.declaredBy = d;
    return d;
}


private:


ExpAssign findIdentDelr (Exp e, ExpIdent ident)
{
    ExpAssign d;
    d = findIdentDelrInExpOrParent(e, ident.text);
    if (d)
        return d;
    return null;
}


ExpAssign findIdentDelrInExpOrParent (Exp e, dstring ident)
{
    ExpAssign d;
    while (e && !d)
    {
        d = findIdentDelrInExp(e, ident);
        e = e.parent;
    }
    return d;
}


ExpAssign findIdentDelrInExp (Exp e, dstring ident)
{
    Exp[] exps;

    auto s = cast(ValueStruct)e;
    if (s)
        exps = s.exps;

    if (exps.length)
    {
        foreach (e2; exps)
        {
            auto d = cast(ExpAssign)e2;
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
            auto d = cast(ExpAssign)e2;
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