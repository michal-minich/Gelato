module validate.remarks;

import std.conv;
import common, parse.ast, validate.validation;


class Remark
{
    immutable dstring code;
    Exp subject;

    @safe pure nothrow this (dstring c, Exp s) { code = c; subject = s; }

    @property const RemarkSeverity severity () { return sett.remarkLevel.severityOf(this); }

    @property const dstring text () { return sett.remarkTranslation.textOf(this); }
}


final class GroupRemark : Remark
{
    immutable Remark[] children;

    @safe nothrow this (dstring c, Exp s, immutable Remark[] ch) { super(c, s); children = ch; }
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
        auto f = parseFile(vctx, rootPath ~ "/validation/" ~ name ~ ".gel");
        auto rl = new RemarkLevel;

        foreach (e; f.exps)
        {
            auto d = cast(StmDeclr)e;
            if (d.ident.ident == "name")
                rl.name = d.value.str(fv);
            else
                rl.values[d.ident.ident] = d.value.str(fv).to!RemarkSeverity();
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
        auto f = parseFile(vctx, rootPath ~ "/lang/" ~ language ~ "/settings.gel");
        auto rt = new RemarkTranslation;
        rt.rootPath = rootPath;

        foreach (e; f.exps)
        {
            auto d = cast(StmDeclr)e;
            if (d.ident.ident == "inherit")
                rt.inherit = (cast(ValueText)d.value).value.to!string();
        }

        rt.values = loadValues (vctx, rootPath ~ "/lang/" ~ language ~ "/remarks.gel");

        return rt;
    }


    private static dstring[dstring] loadValues (IValidationContext vctx, const string filePath)
    {
        dstring[dstring] vals;
        auto f = parseFile(vctx, filePath);

        foreach (e; f.exps)
        {
            auto d = cast(StmDeclr)e;
            vals[d.ident.ident] = d.value.str(fv);
        }

        return vals;
    }
}


@safe nothrow:


private mixin template r (string name)
{
    mixin ("Remark " ~ name ~ " (Exp subject) { return new Remark (\""
        ~ name ~ "\", subject); }");
}

private mixin template gr (string name)
{
    mixin ("Remark " ~ name ~ " (Exp subject, immutable Remark[] children) { "
        ~ "return new GroupRemark (\"" ~ name ~ "\", subject, children); }");
}


Remark textRemark(dstring text, Exp subject = null)
{
    return new Remark (text, subject);
}


mixin r!("SelfStandingUnderscore");

mixin gr!("NumberNotProperlyFormatted");
mixin r!("NumberStartsWithUnderscore");
mixin r!("NumberEndsWithUnderscore");
mixin r!("NumberContainsRepeatedUnderscore");
mixin r!("NumberStartsWithZero");

mixin r!("MissingStartFunction");

mixin r!("NoStartCurlyBraceAfterFn");
mixin r!("FnParamIsNotIdentifierOrDeclaration");
mixin r!("FnParamIsNotSeparatedByComa");

mixin r!("ReturnWithoutExpression");

mixin r!("GotoWithoutIdentifier");
mixin r!("LabelWithoutIdentifier");
mixin r!("GotoWithNoMatchingLabel");
mixin r!("LabelWithNoMatchingGoto");

mixin r!("EmtyBraces");
mixin r!("NoClosingBrace");
mixin r!("RedudantBraceClose");
mixin r!("ClosingBraceDoesNotMatchOpening");
mixin r!("EmptyUnclosedOpeningBrace");

mixin r!("NoEndTextQoute");
mixin r!("FnArgumentIsNotSeparatedByComa");

mixin r!("NoIdentifierAfterDot");