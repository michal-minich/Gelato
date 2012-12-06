module interpret.declrfinder;

import std.algorithm, std.conv;
import common, syntax.ast, validate.remarks, interpret.builtins, program;


@safe:


private final class Env
{
    ExpAssign[dstring] declrs;
    Env parent;
    ExpIdent[] missing;
    size_t closureItemIndex;
    ExpAssign[] unused;

    nothrow this (Env parent) { this.parent = parent; }

    nothrow ExpAssign get (ExpIdent i)
    {
        auto d = i.text in declrs;
        if (d)
        {
            d.usedBy ~= i;
            return *d;
        }
        return parent ? parent.get(i) : null;
    }
}


final class DeclrFinder : IAstVisitor!(void)
{
    Env env;
    IValidationContext context;
    Program program;


    this (IValidationContext context, Program program) { this.context = context; this.program = program; }


    @trusted void finalize ()
    {
        if (env.parent)
            foreach (d; env.declrs)
            {
                auto name = (cast(ExpIdent)d.slot).text;
                if (!(env.parent is null && name == "start") && !d.usedBy)
                    env.parent.unused ~= d;
            }

        env = env.parent;
    }


    @trusted void visit (ValueStruct s)
    {
        env = new Env(env);

        //foreach (e; s.exps)
        //    e.findDeclr(this);

        for (auto i = 0; i < s.exps.length; i++)
            s.exps[i].findDeclr(this);

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
                context.remark(textRemark(m, "identifier " ~ m.text ~ " is not defined"));
                m.declaredBy = new ExpAssign(null, m, new ValueUnknown(m.parent, m));
            }
        }

        if (!env.parent)
            foreach (d; env.unused)
                if (!d.usedBy)
                    context.remark(textRemark(d, "declaration " ~ d.slot.str(fv) ~ " is not used"));

        finalize();
    }


    void visit (ValueFn fn)
    {
        env = new Env(env);

        foreach (p; fn.params)
            visit(p);

        foreach (e; fn.exps)
            e.findDeclr(this);

        if (env.parent)
            foreach (m; env.missing)
                env.parent.missing ~= m;

        finalize();
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
            {
                i.declaredBy = new ExpAssign(null, null, *bfn);
            }
            else
            {
                program.tryAddModule(i.text.to!string());
                env.missing ~= i;
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


    void visit (ExpDot d)
    { 
        d.record.findDeclr(this);
        
        // d.member.declaredBy is assigned in the TypeInferer
    }


    void visit (ExpAssign a)
    {
        if (a.type)
            a.type.findDeclr(this);

        if (a.value)
            a.value.findDeclr(this);

        auto i = cast(ExpIdent)a.slot;
        auto declr = i.text in env.declrs;
        if (declr)
        {
            auto declrIdent = cast(ExpIdent)declr.slot;
            i.closureItemIndex =  declrIdent.closureItemIndex;
        }
        else
        {
            env.declrs[i.text] = a;
            i.closureItemIndex =  env.closureItemIndex;
            ++env.closureItemIndex;
        }
    }


    void visit (StmReturn r) { r.exp.findDeclr(this); }

    void visit (Closure) { }

    void visit (StmLabel) { }
    void visit (StmGoto) { }

    void visit (ValueBuiltinFn) { }
    void visit (ValueUnknown) { }

    void visit (ValueInt) { }
    void visit (ValueFloat) { }
    void visit (ValueText) { }
    void visit (ValueChar) { }
    void visit (ValueArray) { }

    void visit (TypeType) { }
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

    void visit (WhiteSpace) { }
}