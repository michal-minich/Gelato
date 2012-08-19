module validate.validation;

import std.algorithm;
import common, parse.ast, parse.parser, validate.remarks;


final class Validator
{
    IValidationContext vctx;

    this (IValidationContext validationContex) { vctx = validationContex; }


    void validate (Exp exp)
    {
        auto n = cast(AstNum)exp;
        if (n)
            validateNum(n);
    }


    void validateNum (AstNum n)
    {
        auto txt = n.str(fv);
        if (txt.startsWith("_"))
            vctx.remark(NumberStartsWithUnderscore(n));
        else if (txt.endsWith("_"))
            vctx.remark(NumberEndsWithUnderscore(n));
        else if (txt.canFind("__"))
            vctx.remark(NumberContainsRepeatedUnderscore(n));
        if (txt.length > 1 && txt.startsWith("0"))
            vctx.remark(NumberStartsWithZero(n));
    }
}