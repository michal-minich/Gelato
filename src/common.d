module common;


import std.stdio, std.array, std.range, std.algorithm, std.conv;
import settings, validation, interpreter, formatter;


Settings sett;
FormatVisitor fv;


enum newLine = "\r\n";


@trusted dstring typeName (T) (T a)
{
    auto n = typeid(a).name;
    return to!dstring(n[n.length - n.retro().countUntil('.') .. $]);
}


@trusted debug void dbg(T...) (T a)
{
    writeln(a);
}


final class ConsoleInterpreterContext : IInterpreterContext
{
    void print (dstring str) { write (str); }

    void println () { writeln (); }

    void println (dstring str) { writeln (str); }

    void remark (Remark remark)
    {
        write (remark.severity, "\t", remark.text);
        if (remark.subject)
            write ("\t", remark.subject.str(fv));
        writeln();
    }
}


struct Position
{
    uint line;
    uint column;
}


@trusted dstring toVisibleCharsText (const dstring str)
{
    return str
        .replace("\\", "\\\\")
        .replace("\n", "\\n")
        .replace("\r", "\\r")
        .replace("\t", "\\t");
}

@trusted dstring toInvisibleCharsText (const dstring str)
{
    return str
        .replace("\\n", "\n")
        .replace("\\r", "\r")
        .replace("\\t", "\t")
        .replace("\\\\", "\\");
}
/*
    switch (ptChar.capture[0])
    {
        case "\\n": t.value = '\n'; break;
        case "\\r": t.value = '\r'; break;
        case "\\t": t.value = '\t'; break;
        default: t.value = ptChar.capture[0][0];
    }*/
@safe pure dchar toInvisibleChar (const dchar escape)
{
    switch (escape)
    {
        case 'n': return '\n';
        case 'r': return '\r';
        case 't': return '\t';
        default:  return 0;
    }
}


@trusted dstring toVisibleCharsChar (dstring str)
{
    return str
        .replace("\n", "\\n")
        .replace("\r", "\\r")
        .replace("\t", "\\t");
}