module validate.remarks;

import std.conv;
import common, syntax.ast;


class Remark
{
    immutable dstring name;
    Exp subject;
    Token token;

    @safe pure nothrow this (dstring n, Exp s) { name = n; subject = s; }

    @safe pure nothrow this (dstring n, Token t) { name = n; token = t; }

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
        if (auto v = remark.name in values)
            return *v;

        else return RemarkSeverity.none;
    }


    static RemarkLevel load (IValidationContext vctx, const string rootPath, const string name)
    {
        auto f = parseFile(vctx, rootPath ~ "/validation/" ~ name ~ ".gel");
        auto rl = new RemarkLevel;

        foreach (e; f.exps)
        {
            auto d = cast(ExpAssign)e;
            auto i = cast(ExpIdent)d.slot;
            if (i.text == "name")
                rl.name = (cast(ValueText)d.value).value;
            else
                rl.values[i.text] = d.value.str(fv).to!RemarkSeverity();
        }

        return rl;
    }
}


final class NoRemarkTranslation : IRemarkTranslation
{
    dstring textOf (const Remark remark)
    {
        return remark.name;
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
        immutable key = remark.name;

        if (auto v = key in values)
            return *v;

        if (!inherited && inherit)
            inherited = load (sett.icontext, rootPath, inherit);

        if (inherited)
            return inherited.textOf (remark);

        return "[" ~ to!dstring(remark.name) ~ "]";
    }


    static RemarkTranslation load (
        IValidationContext vctx, const string rootPath, const string language)
    {
        auto f = parseFile(vctx, rootPath ~ "/lang/" ~ language ~ "/settings.gel");
        auto rt = new RemarkTranslation;
        rt.rootPath = rootPath;

        foreach (e; f.exps)
        {
            auto d = cast(ExpAssign)e;
            auto i = cast(ExpIdent)d.slot;
            if (i.text == "inherit")
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
            auto d = cast(ExpAssign)e;
            auto i = cast(ExpIdent)d.slot;
            vals[i.text] = (cast(ValueText)d.value).value;
        }

        return vals;
    }
}


@safe nothrow:


dstring remarkSeverityText (RemarkSeverity s)
{
    final switch (s)
    {
        case RemarkSeverity.none: return "None";
        case RemarkSeverity.notice: return "Notice";
        case RemarkSeverity.hint: return "Hint";
        case RemarkSeverity.suggestion: return "Suggestion";
        case RemarkSeverity.warning: return "Warning";
        case RemarkSeverity.error: return "Error";
        case RemarkSeverity.blocker: return "Blocker";
    }
}


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


Remark textRemark(Exp subject, dstring text)
{
    return new Remark (text, subject);
}


Remark textRemark(Token subject, dstring text)
{
    return new Remark (text, subject);
}


Remark textRemark(dstring text)
{
    return new Remark (text, null);
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