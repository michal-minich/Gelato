module interpret.preparer;

import std.algorithm, std.array, std.conv, std.string;
import common, parse.ast, validate.remarks, interpret.builtins;


@safe StmDeclr findDeclr (Exp[] exps, dstring name)
{
    foreach (e; exps)
    {
        auto d = cast(StmDeclr)e;
        if (d && d.ident.str(fv) == name)
            return d;
    }
    return null;
}


@safe final class PreparerForEvaluator : IAstVisitor!(void)
{
    IValidationContext vctx;
    private ValueFn currentFn;
    private uint currentExpIndex;


    this (IValidationContext validationContex) { vctx = validationContex; }


    private StmDeclr getIdentDeclaredBy (ExpIdent ident)
    {
        if (ident.declaredBy)
            return ident.declaredBy;

        auto bfn = ident.idents[0] in builtinFns;
        if (bfn && ident.idents.length == 1)
        {
            auto d = new StmDeclr(null, null);
            d.value = *bfn;
            return d;
        }

        auto d = findIdentDelr (ident, ident.parent);
        if (!d)
        {
            d = new StmDeclr(ident.parent, ident);
            d.value = new AstUnknown(ident);
        }

        return d;
    }


    private StmDeclr findIdentDelr (ExpIdent ident, Exp e)
    {
        StmDeclr d;
        auto idents = ident.idents;
        d = findIdentDelrInExpOrParent(idents[0], e);
        if (d)
            return d;
        idents = idents[1 .. $];
        e = d;
        while (e && idents.length)
        {
            d = findIdentDelrInExp(idents[0], e);
            if (d)
                return d;
            idents = idents[1 .. $];
            e = d.value;
        }
        return d;
    }


    private StmDeclr findIdentDelrInExpOrParent (dstring ident, Exp e)
    {
        StmDeclr d;
        while (e && !d)
        {
            d = findIdentDelrInExp(ident, e);
            e = e.parent;
        }
        return d;
    }


    private StmDeclr findIdentDelrInExp (dstring ident, Exp e)
    {
        Exp[] exps;
        auto s = cast(ValueStruct)e;
        if (s)
            exps = s.exps;

        auto f = cast(ValueStruct)e;
        if (f)
            exps = f.exps;

        if (exps.length)
        {
            foreach (e2; exps)
            {
                auto d = cast(StmDeclr)e2;
                if (d && d.ident.idents[0] == ident)
                    return d;
            }
            return null;
        }

        auto fn = cast(ValueFn)e;
        if (fn)
        {
            foreach (p; fn.params)
                if (p.ident.idents[0] == ident)
                    return p;

            foreach (e2; fn.exps)
            {
                if (e2 is e)
                     break;
                auto d = cast(StmDeclr)e2;
                if (d && d.ident.idents[0] == ident)
                    return d;
            }
        }

        return null;
    }


    void visit (ValueStruct s)
    {
        auto f = new ValueFn(s);
        foreach (e; s.exps)
        {
            auto id = cast(ExpIdent)e;
            auto d = cast(StmDeclr)e;
            if (!id && !d)
                assert (false, "struct can contain only declarations or identifiers");
            else
                f.params ~= d ? d : new StmDeclr(s, id);
        }
        s.exps = null;
        f.exps ~= new ValueFn (s);
        s.constructor = f;
    }


    void visit (ValueFn fn)
    {
        foreach (ix, p; fn.params)
        {
            p.paramIndex = ix;
            visit(p);
        }

        uint expIndex;
        foreach (e; fn.exps)
        {
            currentFn = fn;
            currentExpIndex = expIndex++;
            e.prepare(this);
        }
    }


    @trusted void visit (StmGoto gt)
    {
        uint expIndex;
        auto l = findLabelOrLast(currentFn.exps, gt.label, expIndex);

        if (l)
        {
            gt.labelExpIndex = expIndex;

            if (!gt.label || gt.label != l.label)
            {
                if (l.label)
                    vctx.remark(textRemark("goto will go to last label in function", l));
                else
                    vctx.remark(textRemark("goto will go to first unamed label", l));
            }
        }
        else
        {
            vctx.remark(GotoWithNoMatchingLabel(gt));
        }
    }


    static nothrow private StmLabel findLabelOrLast (Exp[] exps, dstring label, out uint expIndex)
    {
        StmLabel lbl;
        foreach (ix, e; exps)
        {
            auto l = cast(StmLabel)e;
            if (l)
            {
                lbl = l;
                expIndex = cast(uint)ix;

                if (l.label == label)
                    return l;
            }
        }
        return lbl;
    }


    void visit (ExpIf i)
    {
        i.when.prepare(this);

        foreach (t; i.then)
            t.prepare(this);

        foreach (o; i.otherwise)
            o.prepare(this);
    }


    void visit (ExpFnApply fna)
    {
        visit(fna.ident);

        foreach (a; fna.args)
            a.prepare(this);
    }


    @trusted void visit (ValueFile file)
    {
        auto start = findDeclr(file.exps, "start");

        if (!start)
        {
            vctx.remark(MissingStartFunction(null));
            auto i = new ExpIdent(file, ["start"]);
            auto d = new StmDeclr(file, i);
            auto fn = new ValueFn(file);
            fn.exps = file.exps;
            d.value = fn;
            file.exps = [d];
        }

        foreach (e; file.exps)
            e.prepare(this);
    }


    void visit (StmDeclr d)
    {
        d.ident.declaredBy = d;
        if (d.type)
            d.type.prepare(this);
        if (d.value)
            d.value.prepare(this);
    }


    void visit (ExpIdent ident) { ident.declaredBy = getIdentDeclaredBy(ident); }

    void visit (StmReturn r) { r.exp.prepare(this);}

    void visit (ExpLambda l) { visit(l.fn); }

    void visit (StmLabel) { }

    void visit (TypeType) { }

    void visit (ValueText) { }

    void visit (ValueChar) { }

    void visit (ValueNum) { }

    void visit (BuiltinFn) { }

    void visit (AstUnknown) { }

    void visit (TypeAny) { }

    void visit (TypeVoid) { }

    void visit (TypeOr) { }

    void visit (TypeFn) { }

    void visit (TypeNum) { }

    void visit (TypeText) { }

    void visit (TypeChar) { }
}