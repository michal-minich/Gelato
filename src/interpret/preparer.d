module interpret.preparer;

import std.algorithm, std.array, std.conv, std.string;
import common, parse.ast, validate.remarks, interpret.builtins, interpret.declrfinder;



@safe final class PreparerForEvaluator : IAstVisitor!(void)
{
    IValidationContext vctx;
    private ValueFn currentFn;
    private uint currentExpIndex;


    this (IValidationContext validationContex) { vctx = validationContex; }


    void visit (ValueStruct s)
    {
        Exp[] ds;

        foreach (e; s.exps)
        {
            if (cast(StmDeclr)e)
            {
                ds ~= e;
                e.prepare(this);
            }
        }

        s.exps = ds;
    }


    void visit (ValueFn fn)
    {
        foreach (p; fn.params)
            visit(p);

        foreach (ix, e; fn.exps)
        {
            currentFn = fn;
            currentExpIndex = cast(uint)ix;
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
                    vctx.remark(textRemark("goto will go to first unnamed label", l));
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

        if (i.otherwise)
            foreach (o; i.otherwise)
                o.prepare(this);
        else
            i.otherwise = [new AstUnknown(i)];
    }


    void visit (ExpFnApply fna)
    {
        fna.applicable.prepare(this);

        foreach (a; fna.args)
            a.prepare(this);
    }


    @trusted void visit (ValueFile file)
    {
        auto start = findDeclr(file.exps, "start");

        if (!start)
        {
            vctx.remark(MissingStartFunction(null));
            auto i = new ExpIdent(file, "start");
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
        auto i = cast(ExpIdent)d.slot;

        if (i)
            i.declaredBy = d;

        if (d.type)
            d.type.prepare(this);

        if (d.value)
            d.value.prepare(this);
    }


    @trusted void visit (ExpIdent ident)
    { 
        ident.declaredBy = getIdentDeclaredBy(ident);

        assert (ident.declaredBy, "undefined identifier " ~ ident.text.to!string());
    }

    void visit (ExpScope) { assert (false, "ExpScope prepare"); }

    void visit (ExpLambda l) { assert (false, "ExpLambda prepare"); }

    void visit (ExpDot dot) { dot.record.prepare(this); }

    void visit (StmReturn r) { r.exp.prepare(this);}

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

    void visit (TypeStruct) { }
}