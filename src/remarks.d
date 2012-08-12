module remarks;

import std.array, std.algorithm, std.conv;
import common, ast;


pure @safe:


enum GeanyBug { none }


enum RamarkSeverity
{
    observation,
    hint,
    suggestion,
    warning,
    error,
    blocker
}

const IValidationLanguage validationLang;


interface IValidationLevel
{
    RamarkSeverity severityOf (const Remark);
}


interface IValidationLanguage
{
    dstring textOf (const Remark);
}


const abstract class Remark
{
    dstring code;
    Exp subject;

    this (dstring c, Exp s)
    {
        code = c; subject = s;
    }
}


final class ParserUnderscore : Remark
{
    this (Exp subject)
    {
        super ("P-US", subject);
    }
}


final class ValidationLanguageEnUs : IValidationLanguage
{
    @trusted dstring textOf (const Remark remark)
    {
        switch (remark.code)
        {
            case "P-US": return "";
            default: assert (false, "no traslation for " ~ to!string(remark.code));
        }
    }
}