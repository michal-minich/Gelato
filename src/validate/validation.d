module validate.validation;

import std.algorithm;
import common, parse.ast, parse.parser, validate.remarks;


@trusted final class Validator : IAstVisitor!(void)
{
    IValidationContext vctx;

    this (IValidationContext validationContex) { vctx = validationContex; }


    void visit (AstUnknown u)
    {
    }


    void visit (AstNum n)
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


    void visit (AstText t)
    {
    }


    void visit (AstChar ch)
    {
    }


    void visit (AstFn fn)
    {
        foreach (p; fn.params)
            p.validate(this);

        foreach (e; fn.exps)
            e.validate(this);
    }



    void visit (AstFnApply fna)
    {
        fna.ident.validate(this);

        foreach (a; fna.args)
            a.validate(this);
    }


    void visit (AstLambda l)
    {
        assert (false, "validate lambda");
    }



    void visit (AstIdent i)
    {
    }


    void visit (AstDeclr d)
    {
        visit(d.ident);

        if (d.type)
            d.type.validate(this);

        if (d.value)
            d.value.validate(this);
    }



    void visit (AstFile f)
    {
        foreach (e; f.exps)
            e.validate(this);
    }


    void visit (AstStruct s)
    {
        foreach (e; s.exps)
            e.validate(this);
    }


    void visit (AstLabel l)
    {
    }


    void visit (AstGoto gt)
    {
    }


    void visit (AstReturn r)
    {
        r.exp.validate(this);
    }


    void visit (AstIf i)
    {
        i.when.validate(this);

        foreach (t; i.then)
            t.validate(this);

        foreach (o; i.otherwise)
            o.validate(this);
    }
}