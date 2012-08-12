module remarks;

import std.array, std.algorithm, std.conv;
import common, ast;


pure:


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


interface IValidationLevel
{
    RamarkSeverity severityOf (const Remark);
}


interface IValidationTranslation
{
    dstring textOf (const Remark);
}

@safe:
enum GeanyBug2 { none }


abstract class Remark
{
    const dstring code;
    const Exp subject;

    this (const dstring c, const Exp s) { code = c; subject = s; }
}


final class ParserUnderscoreRemark : Remark
{
    this (const Exp subject) { super ("P-US", subject); }
}


final class NoStartFunctionRemark : Remark
{
    this () { super ("I-START", null); }
}