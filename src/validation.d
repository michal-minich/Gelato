module validation;

import std.array, std.algorithm, std.conv, std.file, std.utf;
import common, ast, remarks, parser;


interface IValidationContext
{
    void remark (Remark);
}


@safe pure nothrow interface IExpValidation
{
    void validate (Exp);
}


interface IRemarkTranslation
{
    dstring textOf (const Remark);
}


interface IRemarkLevel
{
    RemarkSeverity severityOf (const Remark);
}


enum RemarkSeverity
{
    none,
    notice,
    hint,
    suggestion,
    warning,
    error,
    blocker
}


class Remark
{
    const dstring code;
    Exp subject;

    @safe nothrow this (dstring c, Exp s) { code = c; subject = s; }

    @property RemarkSeverity severity () { return sett.remarkLevel.severityOf(this); }

    @property dstring text () { return sett.remarkTranslation.textOf(this); }
}


final class GroupRemark : Remark
{
    Remark[] children;

    @safe nothrow this (dstring c, Exp s, Remark[] ch) { super(c, s); children = ch; }
}


final class NoRemarkLevel : IRemarkLevel
{
    RemarkSeverity severityOf (const Remark remark)
    {
        return RemarkSeverity.none;
    }
}


final class RemarkLevel : IRemarkLevel
{
    dstring name;
    RemarkSeverity[dstring] values;


    RemarkSeverity severityOf (const Remark remark)
    {
        if (auto v = remark.code in values)
            return *v;

        else return RemarkSeverity.none;
    }


    static RemarkLevel load (IValidationContext vctx, const string rootPath, const string name)
    {
        immutable src = toUTF32(readText!string(rootPath ~ "/validation/" ~ name ~ ".gel"));

        auto exps = (new Parser(vctx, src)).parseAll();

        auto rl = new RemarkLevel;

        foreach (e; exps)
        {
            auto d = cast(AstDeclr)e;
            if (d.ident.idents[0] == "name")
                rl.name = d.value.str(fv);
            else
                rl.values[d.ident.idents[0]] = d.value.str(fv).to!RemarkSeverity();
        }

        return rl;
    }
}


final class NoRemarkTranslation : IRemarkTranslation
{
    dstring textOf (const Remark remark)
    {
        return remark.code;
    }
}


final class RemarkTranslation : IRemarkTranslation
{
    private dstring[dstring] values;
    private string rootPath;
    private string inherit;
    private RemarkTranslation inherited;


    dstring textOf (const Remark remark)
    {
        immutable key = remark.code;

        if (auto v = key in values)
            return *v;

        if (!inherited && inherit)
            inherited = load (sett.icontext, rootPath, inherit);

        if (inherited)
            return inherited.textOf (remark);

        return "[" ~ to!dstring(remark.code) ~ "]";
    }


    static RemarkTranslation load (
        IValidationContext vctx, const string rootPath, const string language)
    {
        immutable src = toUTF32(readText(rootPath ~ "/lang/" ~ language ~ "/settings.gel"));
        auto exps = (new Parser(vctx, src)).parseAll();

        auto rt = new RemarkTranslation;
        rt.rootPath = rootPath;

        foreach (e; exps)
        {
            auto d = cast(AstDeclr)e;
            if (d.ident.idents[0] == "inherit")
                rt.inherit = (cast(AstText)d.value).value.to!string();
        }

        rt.values = loadValues (vctx, rootPath ~ "/lang/" ~ language ~ "/remarks.gel");

        return rt;
    }


    private static dstring[dstring] loadValues (IValidationContext vctx, const string filePath)
    {
        dstring[dstring] vals;

        immutable src = toUTF32(readText(filePath));
        auto exps = (new Parser(vctx, src)).parseAll();

        foreach (e; exps)
        {
            auto d = cast(AstDeclr)e;
            vals[d.ident.idents[0]] = d.value.str(fv);
        }

        return vals;
    }
}


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