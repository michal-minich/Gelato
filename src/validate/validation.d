module validate.validation;

import std.algorithm, std.exception;
import common, ast, parse.parser, validate.remarks;


@safe nothrow:


final class Validator : IAstVisitor!(void)
{
    private IValidationContext vctx;

    this (IValidationContext validationContex) { vctx = validationContex; }


    void visit (ValueUnknown u)
    {
    }


    @trusted  void visit (ValueNum n)
    {
        // TODO "00" - should report as "can be written as "0""
        Remark[] rs;
        auto txt = n.tokens[0].text[0] == '#' ? n.tokensText[1 .. $] : n.tokensText;

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
            vctx.remark(NumberNotProperlyFormatted(n, assumeUnique(rs)));
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
        fna.applicable.validate(this);

        foreach (a; fna.args)
            a.validate(this);
    }


    void visit (RtExpLambda l)
    {
        assert (false, "validate lambda");
    }



    void visit (ExpIdent i)
    {
    }



    void visit (ExpDot dot)
    {
        dot.record.validate(this);
    }


    void visit (ExpAssign d)
    {
        d.slot.validate(this);

        if (d.type)
            d.type.validate(this);

        if (d.value)
            d.value.validate(this);
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


    void visit (RtExpScope) { }

    void visit (TypeType) { }

    void visit (TypeAny) { }

    void visit (TypeVoid) { }

    void visit (TypeOr) { }

    void visit (TypeFn) { }

    void visit (TypeNum) { }

    void visit (TypeText) { }

    void visit (TypeChar) { }

    void visit (TypeStruct) { }

    void visit (ValueBuiltinFn) { }

    void visit (WhiteSpace ws) { }
}