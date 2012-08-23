module validate.validation;

import std.algorithm;
import common, parse.ast, parse.parser, validate.remarks;


@trusted final class Validator : IAstVisitor!(void)
{
    private IValidationContext vctx;

    this (IValidationContext validationContex) { vctx = validationContex; }


    void visit (AstUnknown u)
    {
    }


    void visit (ValueNum n)
    {
        Remark[] rs;
        auto txt = n.str(fv);

        if (txt.startsWith("_"))
            rs ~= NumberStartsWithUnderscore(n);

        else if (txt.endsWith("_"))
            rs ~= NumberEndsWithUnderscore(n);

        else if (txt.canFind("__"))
            rs ~= NumberContainsRepeatedUnderscore(n);

        if (txt.length > 1 && txt.startsWith("0"))
            rs ~= NumberStartsWithZero(n);

        if (rs.length == 1)
            vctx.remark(rs[0]);
        else if (rs.length > 1)
            vctx.remark(NumberNotProperlyFormatted(n, rs));
    }


    void visit (ValueText t)
    {
    }


    void visit (ValueChar ch)
    {
    }


    void visit (ValueFn fn)
    {
        foreach (p; fn.params)
            p.validate(this);

        foreach (e; fn.exps)
            e.validate(this);
    }



    void visit (ExpFnApply fna)
    {
        fna.ident.validate(this);

        foreach (a; fna.args)
            a.validate(this);
    }


    void visit (ExpLambda l)
    {
        assert (false, "validate lambda");
    }



    void visit (ExpIdent i)
    {
    }



    void visit (ExpDot dot)
    {
    }


    void visit (StmDeclr d)
    {
        visit(d.ident);

        if (d.type)
            d.type.validate(this);

        if (d.value)
            d.value.validate(this);
    }



    void visit (ValueFile f)
    {
        foreach (e; f.exps)
            e.validate(this);
    }


    void visit (ValueStruct s)
    {
        foreach (e; s.exps)
            e.validate(this);
    }


    void visit (StmLabel l)
    {
    }


    void visit (StmGoto gt)
    {
    }


    void visit (StmReturn r)
    {
        r.exp.validate(this);
    }


    void visit (ExpIf i)
    {
        i.when.validate(this);

        foreach (t; i.then)
            t.validate(this);

        foreach (o; i.otherwise)
            o.validate(this);
    }


    void visit (TypeType) { }

    void visit (TypeAny) { }

    void visit (TypeVoid) { }

    void visit (TypeOr) { }

    void visit (TypeFn) { }

    void visit (TypeNum) { }

    void visit (TypeText) { }

    void visit (TypeChar) { }

    void visit (BuiltinFn) { }
}