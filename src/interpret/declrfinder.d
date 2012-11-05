module interpret.declrfinder;

import common, parse.ast, validate.remarks, interpret.builtins;


@safe nothrow:


ExpAssign setIdentDeclaredBy (ExpIdent ident)
{
    if (ident.declaredBy)
        return ident.declaredBy;

    auto d = findIdentDelrInExpOrParent(ident.parent, ident.text);
    if (!d)
    {
        auto bfn = ident.text in builtinFns;
        if (!bfn)
        {
            d = new ExpAssign(null, ident);
            d.value = new ValueUnknown(ident);
        }

        d = new ExpAssign(null, null);
        d.value = *bfn;
    }

    ident.declaredBy = d;
    return d;
}


private:



ExpAssign findIdentDelrInExpOrParent (Exp e, dstring ident)
{
    while (e)
    {
        auto d = findIdentDelrInExp(e, ident);
        if (d)
            return d;
        e = e.parent;
    }
    return null;
}


ExpAssign findIdentDelrInExp (Exp e, dstring ident)
{
    auto s = cast(ValueStruct)e;
    if (s)
    {
        foreach (e2; s.exps)
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

    Exp[] exps;

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