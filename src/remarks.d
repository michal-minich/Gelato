module remarks;

import std.array, std.conv, std.file, std.utf;
import common, ast, interpreter;



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
        if (!values.length)
            return RemarkSeverity.none;

        return values[remark.code];
    }


    static RemarkLevel load (IInterpreterContext icontext, const string rootPath, const string name)
    {
        immutable src = toUTF32(readText!string(rootPath ~ "/validation/" ~ name ~ ".gel"));

        dstring rem;
        foreach (r; RemarkSeverity.min .. RemarkSeverity.max)
            rem ~= (cast(RemarkSeverity)r).to!dstring() ~ "=" ~ (cast(int)r).to!dstring() ~ newLine;

        auto env = (new Interpreter)
            .interpret (icontext, rem ~ src);

        auto rl = new RemarkLevel;

        rl.name = (cast(AstText)env.get("name")).value;

        foreach (k, v; env.values)
            if (k != "name")
                rl.values[k.replace("_", "-")] = cast(RemarkSeverity)(cast(AstNum)v).value.to!int();

        return rl;
    }
}



abstract class Remark
{
    const dstring code;
    const Exp subject;

    @safe this (const dstring c, const Exp s) { code = c; subject = s; }

    @property RemarkSeverity severity () { return sett.remarkLevel.severityOf(this); }

    @property dstring text () { return sett.remarkTranslation.textOf(this); }
}

@safe:
enum GeanyBug2 { none }


final class ParserUnderscoreRemark : Remark
{
    this (const Exp subject) { super ("P-US", subject); }
}


final class NoStartFunctionRemark : Remark
{
    this () { super ("I-START", null); }
}