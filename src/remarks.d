module remarks;

import std.array, std.algorithm, std.conv;
import common, ast, interpreter;


pure:
enum GeanyBug { none }


interface IValidationTranslation
{
    dstring textOf (const Remark);
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


interface IRemarkLevel
{
    RemarkSeverity severityOf (const Remark);
}


final class RemarkLevel : IRemarkLevel
{
    dstring name;
    RemarkSeverity[dstring] values;


    RemarkSeverity severityOf (const Remark remark)
    {
        return values[remark.code];
    }


    static RemarkLevel load (const string rootPath, const string name)
    {
        auto env = (new Interpreter!DefaultInterpreterContext)
            .interpret (rootPath ~ "/validation/" ~ name ~ ".gel");

        auto rl = new RemarkLevel;

        rl.name = (cast(AstText)env.get("name")).value;

        foreach (k, v; env.values)
            if (k != "name")
                rl.values[k.replace("_", "-")] = (cast(AstText)v).value.to!RemarkSeverity();

        return rl;
    }
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