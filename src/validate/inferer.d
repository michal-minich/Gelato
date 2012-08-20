module validate.inferer;


import std.algorithm, std.array;
import common, parse.ast, parse.parser, validate.remarks;


Exp mergeTypesToSingle (Exp[] types...)
{
    auto ts = mergeTypes(types);
    return (ts.length == 1 && !cast(TypeOr)ts[0]) ? ts[0] : new TypeOr(ts);
}


Exp[] mergeTypes (Exp[] types...)
{
    Exp[] possible;
    foreach (t; types)
        possible ~= flatternType(t);
    return possible.sort!typeIdLess().uniq!typeIdEq().array();
}


bool typeIdLess (T) (T a, T b) { return typeid(a) < typeid(b); }

bool typeIdEq (T) (T a, T b) { return typeid(a) == typeid(b); }


Exp[] flatternType(Exp t)
{
    Exp[] res;
    auto tOr = cast(TypeOr)t;
    if (tOr)
        foreach (t2; tOr.types)
            res ~= flatternType(t2);
    else
        res ~= t;

    return res;
}


final class TypeInferer : IAstVisitor!(Exp)
{
    private IValidationContext vctx;
    private AstFn currentFn;


    this (IValidationContext validationContex) { vctx = validationContex; }



    Exp visit (AstUnknown u)
    {
        u.infType = new TypeVoid;
        return u.infType;
    }


    Exp visit (AstNum n)
    {
        n.infType = new TypeNum;
        return n.infType;
    }


    Exp visit (AstText t)
    {
        t.infType = new TypeText;
        return t.infType;
    }


    Exp visit (AstChar ch)
    {
        ch.infType = new TypeChar;
        return ch.infType;
    }


    Exp visit (BuiltinFn bfn)
    {
        bfn.infType = bfn.signature;
        return bfn.signature;
    }


    Exp visit (AstFn fn)
    {
        Exp[] paramTypes;
        foreach (e; fn.params)
            paramTypes ~= e.infer(this);

         fn.infType  = new TypeFn(paramTypes, new TypeVoid);

        foreach (e; fn.exps)
        {
            currentFn = fn;
            e.infer(this);
        }

        if (fn.exps.length == 1 && !cast(AstReturn)fn.exps[0])
            (cast(TypeFn)fn.infType).retType = fn.exps[0].infType;

        return fn.infType;
    }


    Exp visit (AstFnApply fna)
    {
        foreach (e; fna.args)
            e.infer(this);

        fna.infType = (cast(TypeFn)fna.ident.declaredBy.infer(this)).retType;

        return fna.infType;
    }


    Exp visit (AstLambda l)
    {
        visit(l.fn);
        return l.infType;
    }


    Exp visit (AstIdent i)
    {
        i.infType = i.declaredBy.value
            ? i.declaredBy.value.infer(this)
            : new AstUnknown(null, null);
        return i.infType;
    }


    Exp visit (AstDeclr d)
    {
        d.infType = d.value ? d.value.infer(this) : new TypeAny;
        return d.infType;
    }


    Exp visit (AstFile f)
    {
        foreach (e; f.exps)
            e.infer(this);
        return f.infType;
    }


    Exp visit (AstStruct s )
    {
        foreach (e; s.exps)
            e.infer(this);
        return s.infType;
    }


    Exp visit (AstLabel l)
    {
        l.infType = new TypeVoid;
        return l.infType;
    }


    Exp visit (AstGoto gt)
    {
        gt.infType = new TypeVoid;
        return gt.infType;
    }


    @trusted Exp visit (AstReturn r)
    {
        auto fnRetType = &(cast(TypeFn)currentFn.infType).retType;
        auto infType = r.exp.infer(this);

        *fnRetType = cast(TypeVoid)*fnRetType
             ? infType
             : mergeTypesToSingle(*fnRetType, infType);

        r.infType = new TypeVoid;
        return r.infType;
    }


    @trusted Exp visit (AstIf i)
    {
        i.infType = i.then.length == 1 && i.otherwise.length <= 1
            ? mergeTypesToSingle(i.then[0].infer(this), i.otherwise[0].infer(this))
            : new TypeVoid;

        return i.infType;
    }


    Exp visit (TypeAny ta)
    {
        ta.infType = new AstUnknown(null, null);
        return ta.infType;
    }


    Exp visit (TypeVoid tv)
    {
        tv.infType = new AstUnknown(null, null);
        return tv.infType;
    }


    Exp visit (TypeOr tor)
    {
        tor.infType = new AstUnknown(null, null);
        return tor.infType;
    }


    Exp visit (TypeFn tfn)
    {
        tfn.infType = new AstUnknown(null, null);
        return tfn.infType;
    }


    Exp visit (TypeNum tn)
    {
        tn.infType = new AstUnknown(null, null);
        return tn.infType;
    }


    Exp visit (TypeText tt)
    {
        tt.infType = new AstUnknown(null, null);
        return tt.infType;
    }


    Exp visit (TypeChar tch)
    {
        tch.infType = new AstUnknown(null, null);
        return tch.infType;
    }
}