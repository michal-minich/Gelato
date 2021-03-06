module validate.UnusedNamesNotifier;


import common, validate.remarks, syntax.ast;


@safe:


final class UnusedNamesNotifier : IAstVisitor!void
{
    IValidationContext context;

    this (IValidationContext context) { this.context = context; }


    void visit (ValueStruct s)
    {
        foreach (e; s.exps)
            e.accept(this);
    }


    void visit (ValueFn fn)
    {
        foreach (p; fn.params)
            p.accept(this);

        foreach (e; fn.exps)
            e.accept(this);
    }


    void visit (ValueArray arr)
    {
        foreach (e; arr.items)
            e.accept(this);
    }



    void visit (ExpFnApply fna)
    {
        fna.applicable.accept(this);

        foreach (a; fna.args)
            a.accept(this);
    }


    void visit (ExpIf i)
    {
        i.when.accept(this);

        foreach (t; i.then.exps)
            t.accept(this);

        foreach (o; i.otherwise.exps)
            o.accept(this);
    }


    void visit (ExpDot d)
    {
        d.record.accept(this);
    }


    void visit (ExpAssign a)
    {
        if (a.isDeclr)
        {
            auto i = cast(ExpIdent)a.slot;
            if (!a.writtenBy && !a.readBy)
                context.remark(textRemark(a, "Variable " ~ i.text ~ " is not used."));
            else if (!a.writtenBy)
                context.remark(textRemark(a, "Variable " ~ i.text ~ " is only written."));
            else if (!a.readBy)
                context.remark(textRemark(a, "Variable " ~ i.text ~ " is only read."));                
        }

        a.slot.accept(this);

        if (a.type)
            a.type.accept(this);
        
        if (a.value)
            a.value.accept(this);
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


    void visit (StmLabel l)
    {
        if (!l.gotoBy)
            context.remark(textRemark(l, "Label " ~ l.label ~ " is not used."));
    }


    void visit (ValueInt) { }
    void visit (ValueFloat) { }
    void visit (ValueText) { }
    void visit (ValueChar) { }
    void visit (ValueBuiltinFn) { }
    void visit (ValueUnknown) { }

    void visit (ExpIdent) { }

    void visit (Closure) { }
    void visit (StmGoto) { }

    void visit (TypeType) { }
    void visit (TypeAny) { }
    void visit (TypeVoid) { }
    void visit (TypeAnyOf) { }
    void visit (TypeFn) { }
    void visit (TypeInt) { }
    void visit (TypeFloat) { }
    void visit (TypeText) { }
    void visit (TypeChar) { }
    void visit (TypeStruct) { }
    void visit (TypeArray) { }
}