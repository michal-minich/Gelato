module interpret.declrfinder;

import common, parse.ast, validate.remarks, interpret.builtins;


@safe:


final class Env
{
    nothrow:

    private ExpAssign[dstring] declrs;
    private Env parent;


    this (Env parent) { this.parent = parent; }


    ExpAssign get (dstring name)
    {
        auto d = name in declrs;
        return d ? *d : parent ? parent.get(name) : null;
    }


    void opIndexAssign (ExpAssign a, dstring name) { declrs[name] = a; }
}


final class DeclrFinder : IAstVisitor!(void)
{
    Env env;
    IValidationContext context;


    this (IValidationContext context) { this.context = context; }


    void visit (ValueStruct s)
    {
        env = new Env(env);

        foreach (e; s.exps)
            e.findDeclr(this);
    }


    void visit (ValueFn fn)
    {
        env = new Env(env);

        foreach (p; fn.params)
            p.findDeclr(this);

        foreach (e; fn.exps)
            e.findDeclr(this);
    }


    @trusted void visit (ExpIdent i)
    {
        if (i.declaredBy)
            return;

        auto d = env.get(i.text);
        if (d)
        {
            i.declaredBy = d;
        }
        else
        {
            auto bfn = i.text in builtinFns;
            if (bfn)
            {
                d = new ExpAssign(null, null);
                d.value = *bfn;
                i.declaredBy = d;
            }
            else
            {
                context.remark(textRemark("identifier " ~ i.text ~ " is not defined"));
                d = new ExpAssign(null, i);
                d.value = new ValueUnknown(i);
                i.declaredBy = d;
            }
        }
    }


    void visit (ExpFnApply fna)
    {
        fna.applicable.findDeclr(this);

        foreach (a; fna.args)
            a.findDeclr(this);
    }


    void visit (ExpIf i)
    {        
        i.when.findDeclr(this);

        foreach (t; i.then)
            t.findDeclr(this);

        foreach (o; i.otherwise)
            o.findDeclr(this);
    }


    void visit (ExpDot d) { d.record.findDeclr(this); }


    void visit (ExpAssign a)
    {
        if (a.type)
            a.type.findDeclr(this);

        if (a.value)
            a.value.findDeclr(this);

        auto i = cast(ExpIdent)a.slot;
        env[i.text] = a;
    }


    void visit (ExpLambda)
    {
    }


    void visit (ExpScope)
    {
    }


    void visit (StmReturn r) { r.exp.findDeclr(this); }


    void visit (StmLabel) { }
    void visit (StmGoto) { }

    void visit (ValueBuiltinFn) { }
    void visit (ValueUnknown) { }

    void visit (ValueNum) { }
    void visit (ValueText) { }
    void visit (ValueChar) { }

    void visit (TypeType) { }
    void visit (TypeAny) { }
    void visit (TypeVoid) { }
    void visit (TypeOr) { }
    void visit (TypeFn) { }
    void visit (TypeNum) { }
    void visit (TypeText) { }
    void visit (TypeChar) { }
    void visit (TypeStruct) { }

    void visit (WhiteSpace) { }
}