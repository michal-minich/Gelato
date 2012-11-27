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


    @trusted  void visit (ValueInt i)
    {
        // TODO "00" - should report as "can be written as "0""
        Remark[] rs;
        auto txt = i.tokens[0].text[0] == '#' ? i.tokensText[1 .. $] : i.tokensText;

        if (txt.startsWith("_"))
            rs ~= NumberStartsWithUnderscore(i);

        else if (txt.endsWith("_"))
            rs ~= NumberEndsWithUnderscore(i);

        else if (txt.canFind("__"))
            rs ~= NumberContainsRepeatedUnderscore(i);

        if (txt.length > 1 && txt.startsWith("0"))
            rs ~= NumberStartsWithZero(i);

        if (rs.length == 1)
            vctx.remark(rs[0]);
        else if (rs.length > 1)
            vctx.remark(NumberNotProperlyFormatted(i, assumeUnique(rs)));
    }

    
    void visit (ValueFloat f)
    {
    }


    void visit (ValueText t)
    {
        validateTextChar (t.tokens);
    }


    void visit (ValueChar ch)
    {
        validateTextChar (ch.tokens);
    }


    void validateTextChar(Token[] ts)
    {
        if (ts.length == 1)
            vctx.remark (textRemark("unclosed empty text"));
        else if (ts.length == 2)
            vctx.remark (textRemark("unclosed text"));
    }


    void visit (ValueArray arr)
    {
        foreach (i; arr.items)
            i.validate(this);
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
        if (!l.label)
            vctx.remark(LabelWithoutIdentifier(l));
    }


    void visit (StmGoto gt)
    {
        if (!gt.label)
            vctx.remark(GotoWithoutIdentifier(gt));
    }


    void visit (StmReturn r)
    {  
        if (!r.exp)
            vctx.remark(textRemark("return without expression"));

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


    void visit (Closure) { }

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

    void visit (ValueBuiltinFn) { }

    void visit (WhiteSpace ws) { }
}