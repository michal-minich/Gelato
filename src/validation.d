module validation;

import std.array, std.algorithm, std.conv, std.file, std.utf;
import common, ast, remarks, parser, interpreter;


interface IValidationContext
{
    void remark (Remark);
}


interface IExpValidation
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


abstract class Remark
{
    const dstring code;
    Exp subject;

    @safe this (Exp s) { code = typeName(this); subject = s; }

    @property RemarkSeverity severity () { return sett.remarkLevel.severityOf(this); }

    @property dstring text () { return sett.remarkTranslation.textOf(this); }
}


abstract class GroupRemark : Remark
{
    Remark[] children;

    @safe this (Exp s, Remark[] ch) { super(s); children = ch; }
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
            auto declr = cast(AstDeclr)e;
            if (declr.ident.ident == "name")
                rl.name = declr.value.accept(fv);
            else
                rl.values[declr.ident.ident] = declr.value.accept(fv).to!RemarkSeverity();
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
        IInterpreterContext icontext, const string rootPath, const string language)
    {
        auto env = (new Interpreter)
            .interpret (icontext, rootPath ~ "/lang/" ~ language ~ "/settings.gel");

        auto rt = new RemarkTranslation;
        rt.rootPath = rootPath;

        if (auto v = "inherit"d in env.values)
            rt.inherit = (cast(AstText)*v).value.to!string();

        rt.values = loadValues (icontext, rootPath ~ "/lang/" ~ language ~ "/remarks.gel");

        return rt;
    }


    private static dstring[dstring] loadValues (IInterpreterContext icontext, const string filePath)
    {
        dstring[dstring] vals;
        auto env = (new Interpreter).interpret (icontext, filePath);
        foreach (k, v; env.values)
            vals[k] = (cast(AstText)v).value;
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
        auto txt = n.accept(fv);
        if (txt.startsWith("_"))
            vctx.remark(new NumberStartsWithUnderscore(n));
        else if (txt.endsWith("_"))
            vctx.remark(new NumberEndsWithUnderscore(n));
        else if (txt.canFind("__"))
            vctx.remark(new NumberContainsRepeatedUnderscore(n));
        if (txt.length > 1 && txt.startsWith("0"))
            vctx.remark(new NumberStartsWithZero(n));
    }
}