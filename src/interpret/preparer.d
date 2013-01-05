module interpret.preparer;

import std.algorithm, std.array, std.conv, std.string;
import common, syntax.ast, validate.remarks, interpret.builtins, interpret.NameFinder;



@safe final class PreparerForEvaluator : IAstVisitor!void
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
            auto a = cast(ExpAssign)e;
            if (a)
            {
                ds ~= a;
                a.accept(this);
                if (!a.value)
                    a.value = ValueUnknown.single;
            }
            else
            {
                auto i = cast(ExpIdent)e;
                if (i)
                {
                    a = new ExpAssign(s, i, ValueUnknown.single);
                    a.accept(this);
                    ds ~= a;
                }
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
            e.accept(this);
        }
    }


    @trusted void visit (StmGoto gt)
    {
        uint expIndex;
        auto l = findLabelOrLast(currentFn.exps, gt.label, expIndex);

        if (l)
        {
            gt.labelExpIndex = expIndex;
            l.gotoBy ~= gt;

            if (!gt.label || gt.label != l.label)
            {
                if (l.label)
                    vctx.remark(textRemark(l, "goto will go to last label in function"));
                else
                    vctx.remark(textRemark(l, "goto will go to first unnamed label"));
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
        i.when.accept(this);

        foreach (t; i.then.exps)
            t.accept(this);

        foreach (o; i.otherwise.exps)
            o.accept(this);
    }


    void visit (ExpFnApply fna)
    {
        fna.applicable.accept(this);

        foreach (a; fna.args)
            a.accept(this);
    }


    void visit (ExpAssign d)
    {
        auto i = cast(ExpIdent)d.slot;

        if (i)
            i.declaredBy = d;

        if (d.type)
            d.type.accept(this);

        if (d.value)
            d.value.accept(this);
    }


    void visit (Closure) { assert (false, "Closure prepare"); }


    void visit (ExpDot dot)
    { 
        dot.record.accept(this);
        dot.member.accept(this);
    }


    void visit (ValueArray arr)
    {
        foreach (i; arr.items)
            i.accept(this);
    }


    void visit (StmReturn r)
    {
        if (r.exp)
            r.exp.accept(this);
    }


    void visit (StmImport im)
    {
        if (im.exp)
            im.exp.accept(this);
    }


    void visit (StmThrow th)
    {    
        if (th.exp)
            th.exp.accept(this);
    }


    void visit (ExpIdent) { }

    void visit (StmLabel) { }

    void visit (TypeType) { }

    void visit (ValueText) { }

    void visit (ValueChar) { }

    void visit (ValueInt) { }

    void visit (ValueFloat) { }

    void visit (ValueBuiltinFn) { }

    void visit (ValueUnknown) { }

    void visit (TypeAny) { }

    void visit (TypeVoid) { }

    void visit (TypeOr) { }

    void visit (TypeFn) { }

    void visit (TypeInt) { }

    void visit (TypeFloat) { }

    void visit (TypeText) { }

    void visit (TypeChar) { }

    void visit (TypeStruct) { }

    void visit (TypeArray) { }

    void visit (WhiteSpace ws) { }
}