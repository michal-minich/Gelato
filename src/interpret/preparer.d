module interpret.preparer;

import std.algorithm, std.array, std.conv, std.string, std.file, std.utf;
import common, parse.ast, parse.parser, validate.remarks, validate.validation;


@safe nothrow private AstLabel findLabel (Exp[] exps, dstring label)
{
    foreach (e; exps)
    {
        auto l = cast(AstLabel)e;
        if (l && l.label == label)
            return l;
    }
    return null;
}


@safe AstDeclr findDeclr (Exp[] exps, dstring name)
{
    foreach (e; exps)
    {
        auto d = cast(AstDeclr)e;
        if (d && d.ident.str(fv) == name)
            return d;
    }
    return null;
}


@safe final class PreparerForEvaluator : AstVisitor!(void)
{
    IInterpreterContext context;
    private AstFn currentFn;
    private uint currentExpIndex;


    private AstDeclr getIdentDeclaredBy (AstIdent ident)
    {
        if (ident.declaredBy)
            return ident.declaredBy;

        auto d = findIdentDelr (ident, ident.parent);
        if (!d)
        {
            d = new AstDeclr(ident.parent, ident.parent, ident);
            d.value = new AstUnknown(ident, ident);
        }

        return d;
    }


    private AstDeclr findIdentDelr (AstIdent ident, Exp e)
    {
        AstDeclr d;
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


    private AstDeclr findIdentDelrInExpOrParent (dstring ident, Exp e)
    {
        AstDeclr d;
        while (e && !d)
        {
            d = findIdentDelrInExp(ident, e);
            e = e.parent;
        }
        return d;
    }


    private AstDeclr findIdentDelrInExp (dstring ident, Exp e)
    {
        Exp[] exps;
        auto s = cast(AstStruct)e;
        if (s)
            exps = s.exps;

        auto f = cast(AstFile)e;
        if (f)
            exps = f.exps;

        if (exps.length)
        {
            foreach (e2; exps)
            {
                auto d = cast(AstDeclr)e2;
                if (d && d.ident.idents[0] == ident)
                    return d;
            }
            return null;
        }

        auto fn = cast(AstFn)e;
        if (fn)
        {
            foreach (p; fn.params)
                if (p.ident.idents[0] == ident)
                    return p;

            foreach (e2; fn.exps)
            {
                if (e2 is e)
                     break;
                auto d = cast(AstDeclr)e2;
                if (d && d.ident.idents[0] == ident)
                    return d;
            }
        }

        return null;
    }


    void visit (AstStruct s)
    {
        auto f = new AstFn(s, s);
        foreach (e; s.exps)
        {
            auto id = cast(AstIdent)e;
            auto d = cast(AstDeclr)e;
            if (!id && !d)
                assert (false, "struct can contain only declarations or identifiers");
            else
                f.params ~= d ? d : new AstDeclr(s, s, id);
        }
        s.exps = null;
        f.exps ~= new AstFn (s, s);
        s.constructor = f;
    }


    void visit (AstFn fn)
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


    void visit (AstGoto gt)
    {
        auto l = findLabel(currentFn.exps, gt.label);

        if (!l)
            assert (false, "no label");

        gt.labelExpIndex = l.expIndex;
    }


    void visit (AstIf i)
    {
        i.when.prepare(this);

        foreach (t; i.then)
            t.prepare(this);

        foreach (o; i.otherwise)
            o.prepare(this);
    }


    void visit (AstFnApply fna)
    {
        visit(fna.ident);

        foreach (a; fna.args)
            a.prepare(this);
    }


    void visit (AstFile file)
    {
        foreach (e; file.exps)
            e.prepare(this);
    }


    void visit (AstDeclr d)
    {
        d.ident.declaredBy = d;
        if (d.type)
            d.type.prepare(this);
        if (d.value)
            d.value.prepare(this);
    }


    void visit (AstIdent ident)
    {
        ident.declaredBy = getIdentDeclaredBy(ident);
    }

    void visit (AstReturn r) { r.exp.prepare(this);}

    void visit (AstLabel label) { label.expIndex = currentExpIndex; }

    void visit (AstLambda l) { visit(l.fn); }

    void visit (AstText) { }

    void visit (AstChar) { }

    void visit (AstNum) { }

    void visit (AstUnknown) { }
}