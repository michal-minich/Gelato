module validate.inferer;


import std.algorithm, std.array;
import common, parse.ast, parse.parser, validate.remarks;


Exp mergeTypes (Exp[] types...)
{
    Exp[] possible;
    foreach (t; types)
        possible ~= flatternType(t);
    auto ts = possible.sort!typeIdLess().uniq!typeIdEq().array();
    return ts.length == 1 ? ts[0] : new TypeOr(ts);
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
    private ValueFn currentFn;


    this (IValidationContext validationContex) { vctx = validationContex; }



    Exp visit (AstUnknown u)
    {
        u.infType = new TypeVoid;
        return u.infType;
    }


    Exp visit (ValueNum n)
    {
        n.infType = new TypeNum;
        return n.infType;
    }


    Exp visit (ValueText t)
    {
        t.infType = new TypeText;
        return t.infType;
    }


    Exp visit (ValueChar ch)
    {
        ch.infType = new TypeChar;
        return ch.infType;
    }


    Exp visit (BuiltinFn bfn)
    {
        bfn.infType = bfn.signature;
        return bfn.signature;
    }


    Exp visit (ValueFn fn)
    {
        if (fn.infType)
            return fn.infType;

        Exp[] paramTypes;
        foreach (e; fn.params)
            paramTypes ~= e.infer(this);

         fn.infType  = new TypeFn(paramTypes, new TypeVoid);

        foreach (e; fn.exps)
        {
            currentFn = fn;
            e.infer(this);
        }

        if (fn.exps.length == 1 && !cast(StmReturn)fn.exps[0])
            (cast(TypeFn)fn.infType).retType = fn.exps[0].infType;

        return fn.infType;
    }


    Exp visit (ExpFnApply fna)
    {
        foreach (e; fna.args)
            e.infer(this);

        auto applicableType = fna.applicable.infer(this);
        auto fn = cast(TypeFn)applicableType;

        fna.infType = fn ? fn.retType : applicableType /* struct */;

        return fna.infType;
    }


    Exp visit (ExpLambda l)
    {
        visit(l.fn);
        return l.infType;
    }


    Exp visit (ExpIdent i)
    {
        if (i.infType)
            return i.infType;

        i.infType = i.declaredBy.value
            ? i.declaredBy.value.infer(this)
            : new TypeAny;
        return i.infType;
    }


    Exp visit (StmDeclr d)
    {
        if (d.infType)
            return d.infType;

        d.infType = d.value ? d.value.infer(this) : new TypeAny;
        return d.infType;
    }


    Exp visit (ValueStruct s)
    {
        foreach (e; s.exps)
            e.infer(this);

        s.infType = new TypeStruct(null, s); // TODO: there should be identifier
        return s.infType;
    }


    Exp visit (StmLabel l)
    {
        l.infType = new TypeVoid;
        return l.infType;
    }


    Exp visit (StmGoto gt)
    {
        gt.infType = new TypeVoid;
        return gt.infType;
    }


    @trusted Exp visit (StmReturn r)
    {
        auto fnRetType = &(cast(TypeFn)currentFn.infType).retType;
        auto infType = r.exp.infer(this);

        *fnRetType = cast(TypeVoid)*fnRetType
             ? infType
             : mergeTypes(*fnRetType, infType);

        r.infType = new TypeVoid;
        return r.infType;
    }


    @trusted Exp visit (ExpIf i)
    {
        i.infType = i.then.length == 1 && i.otherwise.length == 1
            ? mergeTypes(i.then[0].infer(this), i.otherwise[0].infer(this))
            : new TypeVoid;

        return i.infType;
    }


    Exp visit (ExpDot dot)
    {
        return new AstUnknown(null);
    }


    Exp visit (ExpScope) { return new AstUnknown(null); }

    Exp visit (TypeType tt) { return new TypeType(null, tt); }

    Exp visit (TypeAny ta) { return new TypeType(null, ta); }

    Exp visit (TypeVoid tv) { return new TypeType(null, tv); }

    Exp visit (TypeOr tor) { return new TypeType(null, tor); }

    Exp visit (TypeFn tfn) { return new TypeType(null, tfn); }

    Exp visit (TypeNum tn) { return new TypeType(null, tn); }

    Exp visit (TypeText tt) { return new TypeType(null, tt); }

    Exp visit (TypeChar tch) { return new TypeType(null, tch); }

    Exp visit (TypeStruct s) { return new TypeType(null, s); }
}