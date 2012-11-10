module interpret.declrfinder;

import common, ast, validate.remarks, interpret.builtins;


@safe:


private final class Env
{
    ExpAssign[dstring] declrs;
    Env parent;
    ExpIdent[] missing;

    nothrow this (Env parent) { this.parent = parent; }

    nothrow ExpAssign get (ExpIdent i)
    {
        auto d = i.text in declrs;
        return d ? *d : parent ? parent.get(i) : null;
    }
}


final class DeclrFinder : IAstVisitor!(void)
{
    Env env;
    IValidationContext context;


    this (IValidationContext context) { this.context = context; }


    @trusted void visit (ValueStruct s)
    {
        env = new Env(env);

        foreach (e; s.exps)
            e.findDeclr(this);

        foreach (m; env.missing)
        {
            auto a = m.text in env.declrs;
            if (a)
            {
                m.declaredBy = *a;
            }
            else if (env.parent)
            {
                env.parent.missing ~= m;
            }
            else
            {
                context.remark(textRemark("identifier " ~ m.text ~ " is not defined"));
                m.declaredBy = new ExpAssign(null, m, new ValueUnknown(m));
            }
        }

        env = env.parent;
    }


    void visit (ValueFn fn)
    {
        env = new Env(env);

        foreach (p; fn.params)
            p.findDeclr(this);

        foreach (e; fn.exps)
            e.findDeclr(this);

        if (env.parent)
            foreach (m; env.missing)
                env.parent.missing ~= m;

        env = env.parent;
    }


    @trusted void visit (ExpIdent i)
    {
        if (i.declaredBy)
            return;

        i.declaredBy = env.get(i);

        if (!i.declaredBy)
        {
            auto bfn = i.text in builtinFns;
            if (bfn)
                i.declaredBy = new ExpAssign(null, null, *bfn);
            else
                env.missing ~= i;
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
        if (i.text !in env.declrs)
            env.declrs[i.text] = a;
    }


    void visit (StmReturn r) { r.exp.findDeclr(this); }


    void visit (Closure) { }

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